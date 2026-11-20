import { HttpStatus, Injectable, Logger } from '@nestjs/common';
import Anthropic from '@anthropic-ai/sdk';
import { AppError } from '../common/app-error.js';
import { FilesService } from '../files/files.service.js';

/** The units the app's material form offers. */
export const BILL_UNITS = ['bags', 'kg', 'tons', 'nos', 'loads', 'cft', 'sqft', 'litres'];

const MODEL = 'claude-opus-5-5';

/**
 * Instructions for reading any bill: printed or handwritten, invoices,
 * delivery challans and order forms. Fixed text, so it can be cached.
 */
const INSTRUCTIONS = `You read bills for a real estate company in India that builds houses. Staff upload a scan or photo of a bill: a printed invoice, a handwritten bill, a delivery challan or an order form. Read it and list what was bought, so staff can check it and save it.

How to read it:
- The supplier is the business that issued the bill (usually the letterhead), not the buyer or "Party M/s".
- Dates are written day first (03/09/26 is 3 September 2026). Give the date as YYYY-MM-DD, or "" if there is none.
- Amounts are in rupees and may use Indian grouping (1,56,250.00). Give plain numbers.
- List one item per line of goods. When a line is a grid of variants (for example colours x sizes x full/half sleeve, each with its own quantity), list one item per variant that has a quantity, named like "Karna Set - Full Sleeve - Size 36", and keep the colour numbers in the name when they belong to that variant.
- Skip subtotal, tax (CGST/SGST/IGST), round-off and grand total lines: they are not items. Give the grand total separately.
- unit must be one of: ${BILL_UNITS.join(', ')}. Use "nos" for pieces, numbers, sets and anything else counted.
- rate is the price per unit before tax. If the bill gives only a line amount, rate = amount / quantity. If there is no price, rate = 0.
- Copy what is written. Never guess a number you cannot read: set unclear = true for that item instead, and also when the handwriting is hard to read, a number is crossed out or overwritten, or the rate is missing.
- Use notes for anything staff should know that does not fit an item, in one or two short sentences, or "".`;

/** What the model returns: strict, so every field is always present. */
const BILL_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['supplier', 'billNumber', 'date', 'total', 'items', 'notes'],
  properties: {
    supplier: { type: 'string' },
    billNumber: { type: 'string' },
    date: { type: 'string', description: 'YYYY-MM-DD, or "" when the bill has no date' },
    total: { type: 'number', description: 'Grand total in rupees, 0 when not shown' },
    notes: { type: 'string' },
    items: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['name', 'quantity', 'unit', 'rate', 'unclear'],
        properties: {
          name: { type: 'string' },
          quantity: { type: 'number' },
          unit: { type: 'string', enum: BILL_UNITS },
          rate: { type: 'number', description: 'Rupees per unit before tax, 0 when not shown' },
          unclear: { type: 'boolean' },
        },
      },
    },
  },
} as const;

interface ReadItem {
  name: string;
  quantity: number;
  unit: string;
  rate: number;
  unclear: boolean;
}

interface ReadBill {
  supplier: string;
  billNumber: string;
  date: string;
  total: number;
  notes: string;
  items: ReadItem[];
}

const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'] as const;
type ImageType = (typeof IMAGE_TYPES)[number];

const unavailable = (code: string, message: string) => new AppError(code, message, HttpStatus.SERVICE_UNAVAILABLE);

/**
 * BillReaderService reads a bill that was uploaded (a PDF or a photo,
 * printed or handwritten) with Claude, and returns its items for staff to
 * review. Nothing is saved here: the reviewed items are saved as a bill.
 */
@Injectable()
export class BillReaderService {
  private readonly logger = new Logger(BillReaderService.name);
  private client?: Anthropic;

  /** Replaces the Claude client in tests. */
  clientOverride?: Pick<Anthropic, 'beta'>;

  constructor(private readonly files: FilesService) {}

  private claude(): Pick<Anthropic, 'beta'> {
    if (this.clientOverride) return this.clientOverride;
    if (!process.env.ANTHROPIC_API_KEY?.trim()) {
      throw unavailable('AI_READING_OFF', 'Reading bills with AI is not set up on the server.');
    }
    // Reads ANTHROPIC_API_KEY from the environment.
    return (this.client ??= new Anthropic());
  }

  async read(fileId: string) {
    const client = this.claude();
    const { file, bytes } = await this.files.read(fileId);
    const data = bytes.toString('base64');

    let bill: Anthropic.Beta.Messages.BetaContentBlockParam;
    if (file.contentType === 'application/pdf') {
      bill = { type: 'document', source: { type: 'base64', media_type: 'application/pdf', data } };
    } else if ((IMAGE_TYPES as readonly string[]).includes(file.contentType)) {
      bill = { type: 'image', source: { type: 'base64', media_type: file.contentType as ImageType, data } };
    } else {
      throw new AppError('UNSUPPORTED_FILE', 'Only PDF and photo bills can be read.', HttpStatus.BAD_REQUEST);
    }

    let response: Anthropic.Beta.Messages.BetaMessage;
    try {
      response = await client.beta.messages.create({
        model: MODEL,
        max_tokens: 16000,
        // A declined request is re-run on Anthropic's recommended fallback model.
        betas: ['server-side-fallback-2026-07-01'],
        fallbacks: 'default',
        output_config: { effort: 'medium', format: { type: 'json_schema', schema: BILL_SCHEMA } },
        system: [{ type: 'text', text: INSTRUCTIONS, cache_control: { type: 'ephemeral' } }],
        messages: [{ role: 'user', content: [bill, { type: 'text', text: 'Read this bill.' }] }],
      });
    } catch (error) {
      if (error instanceof Anthropic.AuthenticationError || error instanceof Anthropic.PermissionDeniedError) {
        this.logger.error(`Claude refused the API key: ${error.status}`);
        throw unavailable('AI_READING_OFF', 'Reading bills with AI is not set up correctly on the server.');
      }
      if (error instanceof Anthropic.RateLimitError || error instanceof Anthropic.InternalServerError) {
        throw unavailable('BILL_READER_BUSY', 'Bill reading is busy. Please try again in a minute.');
      }
      if (error instanceof Anthropic.BadRequestError) {
        this.logger.warn(`Claude could not take this bill: ${error.message}`);
        throw new AppError('BILL_NOT_READ', 'This bill could not be read. Add the items by hand.', HttpStatus.UNPROCESSABLE_ENTITY);
      }
      if (error instanceof Anthropic.APIError) {
        this.logger.error(`Claude error ${error.status}: ${error.message}`);
      } else {
        this.logger.error(`Could not reach Claude: ${String(error)}`);
      }
      throw unavailable('BILL_READER_FAILED', 'Bill reading failed. Please try again, or add the items by hand.');
    }

    if (response.stop_reason === 'refusal') {
      throw new AppError('BILL_NOT_READ', 'This bill could not be read. Add the items by hand.', HttpStatus.UNPROCESSABLE_ENTITY);
    }
    if (response.stop_reason === 'max_tokens') {
      throw new AppError(
        'BILL_TOO_LONG',
        'This bill has too many items to read at once. Upload it a page at a time.',
        HttpStatus.UNPROCESSABLE_ENTITY,
      );
    }
    const text = response.content.flatMap((block) => (block.type === 'text' ? [block.text] : [])).join('');
    return this.toResult(this.parse(text));
  }

  private parse(text: string): ReadBill {
    try {
      const value = JSON.parse(text) as ReadBill;
      if (Array.isArray(value?.items)) return value;
    } catch {
      // Falls through to the error below.
    }
    this.logger.error('Claude returned a bill that was not valid JSON.');
    throw unavailable('BILL_READER_FAILED', 'Bill reading failed. Please try again, or add the items by hand.');
  }

  /** In the app's terms: paise, a real date or null, a unit it offers. */
  private toResult(read: ReadBill) {
    const paise = (rupees: number) => (Number.isFinite(rupees) && rupees > 0 ? Math.round(rupees * 100) : 0);
    const date = /^\d{4}-\d{2}-\d{2}$/.test(read.date) && !Number.isNaN(Date.parse(read.date)) ? read.date : null;
    return {
      supplier: (read.supplier ?? '').trim(),
      billNumber: (read.billNumber ?? '').trim(),
      date,
      totalPaise: paise(read.total) || null,
      notes: (read.notes ?? '').trim(),
      lines: read.items
        .filter((item) => item.name?.trim())
        .map((item) => {
          const quantity = Number.isFinite(item.quantity) && item.quantity > 0 ? item.quantity : 0;
          const ratePaise = paise(item.rate);
          return {
            name: item.name.trim(),
            quantity,
            unit: BILL_UNITS.includes(item.unit) ? item.unit : 'nos',
            ratePaise,
            // Anything missing is flagged for staff to fill in.
            needsCheck: item.unclear || quantity === 0 || ratePaise === 0,
          };
        }),
    };
  }
}
