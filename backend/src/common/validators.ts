import { applyDecorators } from '@nestjs/common';
import { IsDateString, Matches } from 'class-validator';

/** A calendar date as "YYYY-MM-DD". A timestamp could shift the day against IST. */
export const IsDay = () =>
  applyDecorators(
    Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'Dates must look like 2026-10-24.' }),
    IsDateString({ strict: true }, { message: 'That date does not exist.' }),
  );

export const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

/** Today in India, where the business runs, whatever the server's time zone. */
export const todayInIndia = () =>
  new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata' }).format(new Date());
