# Kaira Properties: Backend Design

Status: **draft for review**. No server code exists yet. This is built from the app's
current models and controllers in `lib/`.

## 1. Architecture

```
Flutter app (web + mobile)  →  NestJS API (/api/v1)  →  MongoDB
                                      ↓
                                File storage
```

- The backend lives in `backend/` in this repository, so app and API changes stay together.
- The connection string lives only in `backend/.env`, which Git ignores. It is never put in
  the Flutter app or committed.
- Assumptions, to be corrected if wrong: **one company** (Kaira only) and **online only**
  (no offline entry).

**Requirement to confirm:** the design relies on MongoDB transactions, which need a replica
set. MongoDB Atlas provides this on every tier. A plain single-server install does not.

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

**locations**: `name (unique, case-insensitive)`

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

**materialBills**: `projectId, fileId, supplier, billNumber, date`

**materials**: `projectId, billId?, date, name, quantity, unit, ratePaise, amountPaise, supplier`

**expensePayments**: `projectId, kind (worker | material), targetId, amountPaise, date, method,
reference, createdBy`

**files**: `storageKey, name, contentType, size, uploadedBy`

**refreshTokens**: `userId, tokenHash, expiresAt, revokedAt`

Customers have no collection of their own in this version. As in the app today, they are worked out
by grouping bookings on mobile number.

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
| Projects: read all, assign incharge, update stages | No | Yes | No |
| Projects assigned to them: daily work, workers, materials, bills, expense payments, stages | No | Yes | Yes, own projects only |

**Please confirm the Site Manager row for workers, materials and payments.** The app lets a Site
Manager open a project's tabs today, so this carries that over, but the menu groups those
tasks under Site Incharge.

## 6. Login

- `POST /auth/login` returns a 15-minute access token (JWT) and a 30-day refresh token.
- Refresh tokens rotate on each use and are stored hashed, so a user can be signed out by revoking them.
- Passwords are hashed with Argon2. Login attempts are rate limited.
- There is no public sign-up. The first Admin comes from a one-time script; Admins create everyone else.
- Removing a user revokes their tokens immediately.
- The app keeps tokens in `flutter_secure_storage`.

## 7. Endpoints (`/api/v1`)

```
POST   /auth/login | /auth/refresh | /auth/logout      GET /auth/me
GET    /users                POST /users               PATCH | DELETE /users/:id
GET    /locations            POST /locations
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
POST   /files                GET  /files/:id/url
GET    /reports/dashboard | /reports/inventory | /reports/locations
```

Errors share one shape: `{ "code": "PLOT_TAKEN", "message": "Plot 27 is already booked." }`.
Lists are paginated.

## 8. Files

- Files go to private object storage (S3 or Cloudflare R2). MongoDB stores only their details.
- Downloads use short-lived signed links, because bills are private.
- Limit: 20 MB; PDF, JPG, PNG and WebP only, checked by the server.
- Storage sits behind one interface, so development can use a local folder until an account exists.
- Bill reading stays on the device. Only the reviewed items and the original file are sent.

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

## 11. Open questions

1. Is the database MongoDB Atlas or a replica set? Transactions require one of them.
2. Are one company and online-only correct?
3. Should a Site Manager manage workers, materials and payments, or only view them? (Section 5)
4. Should deleting a site be blocked once it has bookings? This design blocks it, which is a change: the app allows it today.
5. Which file storage account will you use: S3, R2, or something else?
