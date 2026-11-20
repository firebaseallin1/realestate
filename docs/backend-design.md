# Kaira Properties: Backend Design

Status: **in use**. Built and connected to the app: login, users, locations, sites, plots, bookings,
payments, construction and files (build order steps 1 to 6). Differences from the original plan:

- A site stores its location's name, with `locations` keeping the list. The app shows no rename.
- Reports and dashboard totals are worked out in the app from the data it loads, and customers by
  grouping bookings, so there are no separate endpoints for them.
- Lists load in full rather than by page, which suits today's volumes. Add paging if they grow.
- A project is addressed by its booking's ID, and every change answers with the whole project.
- Files download through `GET /files/:id/content` for signed-in staff, not signed links.
- Local-folder storage is in use until an S3 or R2 account exists.

## 1. Architecture

```
Flutter app (web + mobile)  →  NestJS API (/api/v1)  →  MongoDB
                                      ↓
                                File storage
```

- The backend lives in `backend/` in this repository, so app and API changes stay together.
- The connection string lives only in `backend/.env`, which Git ignores. It is never put in
  the Flutter app or committed.
- Decided: **one company** (Kaira only) and **online only** (no offline entry).

**Requirement:** the design relies on MongoDB transactions, which need a replica set. MongoDB
Atlas provides this on every tier; a plain single-server install does not. The server checks at
startup and `GET /health` reports it as `transactions`.

## 2. Conventions

| Topic | Rule | Why |
|---|---|---|
| Money | Whole paise as integers (`₹1,371.35` → `137135`) | Decimals drift when totalled |
| Calendar dates | `"YYYY-MM-DD"` strings for received-on, paid-on and similar | A UTC timestamp can move the date by a day against IST |
| Moments in time | UTC `createdAt`, `updatedAt` on every record | Audit trail |
| IDs | MongoDB ObjectIds, created by the server | Replaces the app's `newId()` |
| Who did it | `createdBy` user ID, plus a copy of the name where it is displayed | Names stay correct on old records after a user is removed |
| Enums | The Dart enum names (`withConstruction`, `bankTransfer`) | Direct mapping to the app |
| Areas, quantities | Plain numbers | Not money; a quantity can be `2.125` tons |

## 3. Collections

**users**: `name, username (unique, lowercase), passwordHash, role, phone, active`
The app's plain `password` field goes away. Removing a user sets `active: false`, because
bookings and work updates still refer to them.

**locations**: `name (unique, case-insensitive), latitude?, longitude?` (map point, both or neither)

**sites**: `name, locationId, type, status, totalUnits, soldUnits, bookedUnits, ownerName,
totalArea, salesArea, roadArea, gardenArea, otherArea, siteMapFileId, brochureFileId`

**plots**: `siteId, number, widthFt, lengthFt, facing, status, pricePaise, rect {x, y, w, h}`
These are separate from the site, unlike the app's model. A booking changing one plot's status
then cannot overwrite an admin saving the layout at the same moment. Unique on `siteId + number`.

**bookings**: `siteId, siteName, plotId?, plotNumber, plotKey, plotSize?, facing?, customer {name,
mobile, email, address}, type, plans [{part, valuePaise, mode, loan {bankName, amountPaise,
reference, status}}], status, live, bookedOn, bookedById, bookedByName, totalPaidPaise`

**payments**: `bookingId, part, amountPaise, date, method, reference, createdBy`
These are separate from the booking so that each is an auditable record and Recent Payments can
query them directly. `totalPaidPaise` on the booking is kept in step inside a transaction.

**projects**: `bookingId (unique), inchargeId?, stages [{name, status, progress, note}]`
Opened automatically when a With Construction booking is approved.

**workers**: `projectId, name, trade, dailyWagePaise, phone`

**dailyWork**: `projectId, date, stageId, description, workerIds[], updatedById, updatedByName`

**materialBills**: `projectId, fileId, fileSha256, supplier, billNumber, date`
The same file, or the same bill number from the same supplier, is refused as `DUPLICATE_BILL`
unless `allowDuplicate` is sent.

**materials**: `projectId, billId?, date, name, quantity, unit, ratePaise, amountPaise, supplier,
history [{date, quantity, ratePaise, supplier, billId?, billNumber, addedAt}]`
The same material (name and unit, ignoring case and spaces) received again adds to `quantity`,
takes the new rate, and adds a `history` entry.

**expensePayments**: `projectId, kind (worker | material), targetId, amountPaise, date, method,
reference, createdBy`

**files**: `storageKey, name, contentType, size, uploadedBy, sha256`

**leads**: `name, mobile, mobileKey (last 10 digits), email, area, source, siteId?, siteName,
interest?, budgetPaise?, notes, status, nextFollowUp?, ownerId, ownerName, followUps [{date, mode,
note, status, nextDate?, byId, byName, addedAt}]`
One lead per mobile number (`DUPLICATE_LEAD`). A follow-up sets the lead's status and next date;
Won and Lost clear the next date. Sales Executives see their own leads; Admins see all.
`customerId?, convertedAt?` are set when the lead is converted.

**customers**: `name, mobile, mobileKey (unique), alternateMobile, email, address, occupation, notes,
leadId?, source?, ownerId, ownerName`
Made by converting a lead (`POST /leads/:id/convert`), in one transaction with marking the lead Won.
One customer per mobile number (`DUPLICATE_CUSTOMER`); a lead converts once (`ALREADY_CONVERTED`).
The app matches customers with bookings on the mobile number.

**refreshTokens**: `userId, tokenHash, expiresAt, revokedAt`

Customers who have only bookings (never a lead) are still worked out by grouping bookings on mobile
number.

## 4. Business rules the server must enforce

Today these rules live in Flutter controllers and forms. The server becomes the source of truth.

| Rule | How |
|---|---|
| **A plot cannot be double-booked** | Partial unique index on `siteId + plotKey` where `live: true`. `plotKey` is the trimmed, lowercase plot number. `live` is false once rejected. Two simultaneous requests cannot both succeed. |
| Booking raised | Transaction: create the booking and move the unit from available to booked |
| Booking rejected | Transaction: release the unit, and set `live: false` |
| Booking approved | Transaction: if fully paid, move the unit to sold; if With Construction, open the project with the 9 standard stages |
| Payment added | Rejected bookings take none. Cannot exceed the balance of that part. If approved and now fully paid, move the unit to sold. |
| Unit move | A drawn plot changes its `status`. A site without a layout changes `bookedUnits` / `soldUnits` instead. |
| Drawn layout | Site unit counts are recounted from its plots |
| Stage update | Completed forces 100%, not started forces 0%, in progress stays 1–99. A work update on a not-started stage moves it to in progress at 5%. |
| Wages | Days present × daily wage. A worker or material payment cannot exceed what is due. |
| Material edit | The amount cannot go below what is already paid on it |
| Material amount | `quantity × ratePaise`, rounded to the paisa, calculated by the server |
| Site areas | Sales + road + garden + other cannot exceed the total |

## 5. Roles

Taken from `DashboardSection` and `dashboard_screen.dart`. Hiding a menu is not security, so the
server checks every request. Admin can do everything.

| Area | Sales Executive | Site Manager | Site Incharge |
|---|---|---|---|
| Sites, plots, locations | Read (needed to book) | Read | Read |
| Add / edit sites, locations, layouts | No | No | No |
| Users | No | Read Site Incharges (to assign) | No |
| Bookings: raise, read, record payments | Yes | No | No |
| Bookings: approve / reject | No | No | No |
| Leads and follow-ups | Own leads | No | No |
| Projects: read all, assign incharge, update stages | No | Yes | No |
| Projects assigned to them: daily work, workers, materials, bills, expense payments, stages | No | Yes | Yes, own projects only |

Decided: a Site Manager keeps full access to workers, materials and payments, as the app allows
today.

## 6. Login

- `POST /auth/login` returns a 15-minute access token (JWT) and a 30-day refresh token.
- Refresh tokens rotate on each use and are stored hashed, so a user can be signed out by revoking them.
- Passwords are at least 8 characters and hashed with Argon2. Login attempts are limited to 10 a
  minute per address.
- Replaying a used refresh token ends that whole sign-in, as it may have been stolen.
- There is no public sign-up. The first Admin comes from a one-time script; Admins create everyone else.
- Removing a user revokes their tokens immediately.
- The app keeps tokens in `flutter_secure_storage`.

## 7. Endpoints (`/api/v1`)

```
POST   /auth/login | /auth/refresh | /auth/logout      GET /auth/me
GET    /users                POST /users               PATCH | DELETE /users/:id
       (DELETE refuses Admins and yourself; PATCH cannot change your own role; username never changes)
GET    /locations            POST /locations           PATCH /locations/:id (map point)
GET    /sites                POST /sites               GET | PATCH | DELETE /sites/:id
GET    /sites/:id/plots      PUT  /sites/:id/plots     PATCH /plots/:id
GET    /bookings?status&type POST /bookings            GET /bookings/:id
POST   /bookings/:id/approve POST /bookings/:id/reject
POST   /bookings/:id/payments                          GET /payments/recent
GET    /customers
GET    /projects             GET  /projects/:id        PATCH /projects/:id/incharge
PATCH  /projects/:id/stages/:stageId
GET|POST /projects/:id/workers | /daily-work | /materials | /expense-payments
PATCH  /projects/:id/materials/:materialId
POST   /projects/:id/material-bills
GET|PUT /settings/file-storage   POST /settings/file-storage/move   (Admin)
GET /settings/theme (anyone, even signed out)   PUT /settings/theme (Admin): any of theme (sage|ocean|indigo|terracotta|graphite|plum), font (josefin|poppins|serif|system), textSize (small|normal|large|extraLarge)
POST   /bills/read  (reads an uploaded bill with Claude; saves nothing)
GET    /leads                POST /leads               PATCH /leads/:id
POST   /leads/:id/follow-ups  POST /leads/:id/convert
POST   /files                GET  /files/:id/url
GET    /reports/dashboard | /reports/inventory | /reports/locations
```

Errors share one shape: `{ "code": "PLOT_TAKEN", "message": "Plot 27 is already booked." }`.
Lists are paginated.

## 8. Files

- Admins choose in Settings > File Storage where new uploads go: the database (default) or the
  server folder (`UPLOAD_DIR`, which then needs a persistent disk). Each file is read from where it was
  saved; "Move files" copies files into the chosen storage and deletes the old copies.
- File bytes are stored in MongoDB with GridFS (bucket `fileBytes`), as binary chunks, not base64.
  The server needs no disk of its own and database backups include the files. Files uploaded before
  this are still read from the old `UPLOAD_DIR` folder. Object storage (S3, R2) can replace GridFS
  later behind the same `StorageService`.
- Downloads use short-lived signed links, because bills are private.
- Limit: 20 MB; PDF, JPG, PNG and WebP only, checked by the server.
- Storage sits behind one interface, so development can use a local folder until an account exists.
- Bills are read by Claude (`claude-opus-5-5`) on the server when `ANTHROPIC_API_KEY` is set: scanned
  and handwritten PDFs and photos, returned as items to review. The file goes to Anthropic for reading.
  Without the key, bills are read on the device (text PDFs, and printed photos on phones).

## 9. Changes in the Flutter app

- A repository layer sits between controllers and the API. Tests keep working with fake repositories.
- Screens gain loading, error and retry states, because data is no longer instant.
- Controllers stop making IDs and enforcing rules; they show the server's result and its errors.
- The API address comes from `--dart-define=API_BASE_URL=...`.
- The server must allow the web app's address (CORS).
- Sample data moves out of the controllers into a development-only seed script. Sample logins never reach production.

## 10. Build order

1. Backend skeleton: config, database connection, error format, health check
2. Login and users, then connect the app's login
3. Locations, sites and plots, then connect those screens (proves the pattern)
4. Bookings and payments, with the double-booking and transaction tests
5. Construction: projects, stages, workers, daily work, materials, expenses
6. File uploads and bills
7. Reports and dashboard totals
8. Deployment, backups and monitoring

**Not in this version:** pages that are still "coming soon" in the app (Leads, Property Units,
Customer Handover, Construction Planning, Inspection, Photos, Site Reports).

## 11. Decisions

- Deleting a site is blocked once it has bookings. This changes today's app, which allows it, and
  is enforced when sites are connected (step 3).

## 12. Open questions

1. Does the database support transactions? `GET /health` answers this once it is connected.
2. Which file storage account will you use: S3, R2, or something else? Needed by step 6.
