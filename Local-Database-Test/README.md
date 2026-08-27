# Local Database Test — MySQL via Docker Compose

A throwaway local MySQL instance with the `hotel_bookings` /
`booking_events` schema, seed data, and Adminer for browsing — no cloud
resources involved.

## Start it

```bash
docker compose up -d
```

First boot takes a few seconds while MySQL initializes and runs the
scripts in `init/` (schema, then seed data). Check readiness with:

```bash
docker compose ps          # STATUS should show "healthy"
docker compose logs -f mysql
```

## Connect

```bash
# From the host, using the mysql CLI:
mysql -h 127.0.0.1 -P 3306 -u app_user -p hotel_bookings_db
# password: app_password (from .env)

# Or via Adminer in a browser:
open http://localhost:8080
# System: MySQL, Server: mysql, Username: app_user, Password: app_password, Database: hotel_bookings_db
```

Credentials and ports are all in `.env` — change them there, not in
`docker-compose.yml`.

## What's in `init/`

Scripts run once, in filename order, only the *first* time the
`mysql_data` volume is created (i.e. a genuinely fresh container).
Re-running `docker compose up` on an existing volume does **not**
re-apply them — see "Resetting" below.

- **`01-schema.sql`** — creates both tables and grants the app user
  DML rights.
- **`02-seed.sql`** — inserts 5 sample bookings and 8 related events.

### Schema notes — adapted from Postgres types to MySQL

The suggested schema uses Postgres-specific types; MySQL doesn't have
direct equivalents for some of them, so:

| Suggested (Postgres) | Used here (MySQL) | Why |
|---|---|---|
| `UUID` | `CHAR(36)` | MySQL has no native UUID type; stored as text. Generate UUIDs in application code (e.g. `uuid4()`) before insert — MySQL's own `UUID()` function works too but produces a different string layout than most client libraries expect. |
| `NUMERIC(12,2)` | `DECIMAL(12,2)` | Identical fixed-point semantics; `DECIMAL` is MySQL's name for the same type. |
| `JSONB` | `JSON` | MySQL's native `JSON` type validates on insert and stores a binary internal representation, similar in spirit to `JSONB`, though without Postgres's GIN-indexable containment queries. |
| `BIGSERIAL` | `BIGINT UNSIGNED AUTO_INCREMENT` | MySQL's auto-increment equivalent. |

Beyond the direct type mapping, a few things were added because this
is meant to be a realistic test DB, not just a literal transcription:

- **Indexes** on `org_id`, `hotel_id`, `status`, and `checkin_date` on
  `hotel_bookings`, and on `booking_id`/`event_type` on
  `booking_events` — these are the columns you'd actually filter/join
  on.
- **Foreign key** from `booking_events.booking_id` →
  `hotel_bookings.id`, `ON DELETE CASCADE` — deleting a booking cleans
  up its event history automatically. Verified locally: deleting a
  booking with 2 associated events left 0 orphaned rows.
- **CHECK constraints** — `checkout_date > checkin_date` and
  `amount >= 0`. Verified locally: an insert with checkout before
  checkin is rejected with `Check constraint 'chk_hotel_bookings_dates'
  is violated`.
- `utf8mb4` charset on both tables, so city names, event payloads, etc.
  can hold full Unicode (including emoji) without silent truncation.

## Resetting to a clean state

```bash
docker compose down -v   # -v removes the named volume too
docker compose up -d     # re-runs init/ scripts from scratch
```

`docker compose down` alone (no `-v`) keeps your data across restarts.

## Verified locally before delivery

Since Docker wasn't available in the sandbox that produced this, the
exact contents of `init/01-schema.sql` and `init/02-seed.sql` were run
against a real MySQL 8.0 server to confirm they apply cleanly:

- Both scripts execute without error.
- All 5 seed bookings and 8 seed events are queryable, including a
  join across both tables.
- The `CHECK` constraint correctly rejects invalid date ranges.
- `ON DELETE CASCADE` correctly removes child events when a parent
  booking is deleted.
- The `app_user` credentials work with exactly the granted privileges
  (no more, no less).

The Docker Compose file itself (image, healthcheck, volumes, env wiring)
follows the standard `mysql:8.0` image conventions but wasn't run
through `docker compose up` directly in this sandbox — worth a quick
`docker compose up -d && docker compose ps` sanity check on your end
once you have Docker available.
