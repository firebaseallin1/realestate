# Kaira Properties API

NestJS and MongoDB backend for the Flutter app. The design is in
[docs/backend-design.md](../docs/backend-design.md).

## Setup

```bash
cd backend
npm install
cp .env.example .env     # then fill in MONGODB_URI and JWT_SECRET
npm run build
```

`MONGODB_URI` must name the database, for example `.../kaira_dev?retryWrites=true`. Use a
separate database for development. `.env` is ignored by Git, so never commit or share it.

## Create the first users

There is no public sign-up. Choose one:

```bash
npm run create-admin     # asks for a name, username and password
npm run seed:dev         # development only: admin, sales, manager, incharge (password kaira123), plus sample data
```

`seed:dev` refuses to run when `NODE_ENV=production`. It adds sample sites, bookings and
construction only if the database has no sites yet, and never changes existing accounts.

## Uploaded files

Bills, site maps and brochures are stored in the `uploads` folder (set `UPLOAD_DIR` to change it).
Only `src/files/storage.service.ts` knows this, so S3 or R2 can replace it. A server whose disk is
wiped on each deploy needs that change before going live, or uploads will be lost.

## Run

```bash
npm run start:dev        # restarts on changes
npm run start:prod       # after npm run build
```

Check it at <http://localhost:1001/api/v1/health>. `"transactions": true` means the database is
ready for bookings and payments. If it says `false`, use MongoDB Atlas or a replica set.

## Run the app against it

```bash
flutter run -d chrome                                                  # uses localhost:1001
flutter run                                                            # Android emulator: uses 10.0.2.2:1001
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:1001/api/v1 # real phone: your computer's address
```

## Tests

```bash
npm run test:e2e         # downloads a temporary MongoDB (about 800 MB) the first time; never touches your database
```
