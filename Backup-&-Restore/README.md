# Backup and Restore

```
scripts/
  backup.sh    # timestamped, compressed dump of the running dev database
  restore.sh   # restores a dump into a brand-new, isolated container
backups/       # created on first backup - dump files + metadata live here
```

## `scripts/backup.sh`

```bash
./scripts/backup.sh
```

Dumps the database out of the running `hotel-bookings-mysql` container
(from `docker compose up -d`) using `mysqldump --single-transaction
--routines --triggers --databases <db>`, compresses it, and writes:

- `backups/hotel_bookings_db_<UTC timestamp>.sql.gz` — the dump itself
- `backups/hotel_bookings_db_<UTC timestamp>.meta` — row counts recorded
  *at backup time*, so a later restore can automatically check itself
  against a known-good baseline rather than just "some rows exist"
- `backups/LATEST` — a plain-text pointer to the most recent dump's
  filename, so `restore.sh` has a sane default

Refuses to run if the container isn't up or isn't reporting healthy,
rather than silently producing an empty/broken dump.

## `scripts/restore.sh`

```bash
./scripts/restore.sh                              # restores backups/LATEST
./scripts/restore.sh backups/some_specific.sql.gz  # restores a named file
./scripts/restore.sh --cleanup                     # tear down afterward instead of leaving it up
```

**"Fresh local database" means a brand-new container, not your dev
container.** This is deliberate — the whole point of a restore drill is
to prove the backup file alone is enough to rebuild the database from
nothing, the same way you'd actually need to during a real incident.
Restoring into the existing dev container (which already has data and
already ran the `init/` scripts) wouldn't prove anything.

So the script:

1. Removes any previous restore-verification container/volume, so
   every run starts from a guaranteed-empty state.
2. Starts a brand-new `mysql:8.0` container (`hotel-bookings-mysql-restore-verify`)
   on **port 3307**, not 3306 — it never touches or competes with your
   regular dev container.
3. Waits for it to report ready.
4. Pipes the (gunzipped) dump straight into it via `mysql`.
5. Reads back row counts and compares them against the `.meta` file
   recorded at backup time.
6. Prints a clear `RESTORE VERIFICATION: PASSED` or `FAILED`, and exits
   non-zero on failure (safe to use in CI as a backup-integrity check).
7. Leaves the restored container running for manual inspection, unless
   you pass `--cleanup`.

## How to verify a restore actually worked

This is the part worth understanding rather than just trusting the
script's PASS/FAIL line — here's what "successfully restored" actually
means and how to check it yourself, in increasing order of rigor:

1. **The restore command didn't error.** `restore.sh` will already stop
   and report failure if `mysql` returns a non-zero exit code while
   loading the dump. This alone is necessary but not sufficient — a
   dump could load "successfully" but be missing rows if it was taken
   badly.

2. **Row counts match what was backed up, not just "some number."**
   `SELECT COUNT(*) FROM hotel_bookings;` returning a number isn't
   proof of anything by itself — it needs to match a *known* value.
   That's why `backup.sh` records counts into a `.meta` file at backup
   time, and `restore.sh` automatically diffs against it. If you're
   checking manually instead:
   ```bash
   mysql -h 127.0.0.1 -P 3307 -u root -p<password> hotel_bookings_db \
     -e "SELECT COUNT(*) FROM hotel_bookings; SELECT COUNT(*) FROM booking_events;"
   ```
   and compare against the `.meta` file next to the dump you restored.

3. **Structure came back too, not just rows.** A dump that lost its
   indexes/constraints along the way would still pass a row-count check
   while leaving you with a functionally broken schema. Confirm the
   index used by the optimized query is present:
   ```bash
   mysql -h 127.0.0.1 -P 3307 -u root -p<password> hotel_bookings_db \
     -e "SHOW INDEX FROM hotel_bookings;"
   ```
   You should see `idx_hotel_bookings_city_created_covering` in the
   output, alongside the primary key and the other indexes.

4. **Constraints still behave, not just exist.** The strongest check:
   actually try to violate one and confirm the database rejects it —
   confirms the constraint round-tripped functionally, not just as
   metadata:
   ```bash
   mysql -h 127.0.0.1 -P 3307 -u root -p<password> hotel_bookings_db -e "
     INSERT INTO hotel_bookings
       (id, org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at)
     VALUES
       ('test', 'org', 'HTL-X', 'Nowhere', '2026-09-10', '2026-09-09', 100.00, 'CONFIRMED', NOW());
   "
   ```
   This should fail with `Check constraint 'chk_hotel_bookings_dates' is
   violated` — if it succeeds instead, something about the restored
   schema is wrong even though the data "looks" fine.

5. **Spot-check an actual query, not just counts.** Run the
   org/status/city aggregate query from the indexing project against
   the restored instance and compare a couple of rows against what you
   remember (or against a `mysqldump --no-data` schema-only comparison
   if you want to be thorough) from before the backup was taken.

`restore.sh` automates checks 1–2 for you on every run. 3–5 are worth
doing by hand at least once so you trust the mechanism, and worth
scripting further (e.g. as an assertion in `restore.sh`) if this ever
becomes a real production backup strategy rather than a local test
setup.

## Verified before delivery

Docker isn't available in the sandbox that produced this, so the exact
`mysqldump`/restore commands used by both scripts (not just similar
ones) were run against a real local MySQL 8.0 server as a substitute
for the container layer:

- `mysqldump --single-transaction --routines --triggers --databases
  hotel_bookings_db` produced a valid, non-empty, gzip-compressed dump.
- The target database was fully dropped (zero tables, zero data) and
  rebuilt **purely from that dump file**.
- Row counts matched exactly: 130 `hotel_bookings`, 212 `booking_events`.
- The covering index (`idx_hotel_bookings_city_created_covering`) was
  present after restore.
- The foreign key's `ON DELETE CASCADE` still worked post-restore
  (deleting a booking with 3 events correctly cascaded to 0).
- The `CHECK` constraint still rejected an invalid checkout-before-checkin
  insert post-restore.

What wasn't exercised directly: the Docker orchestration itself
(`docker run`, `docker exec`, container health-check waiting, the
`--cleanup` flag) and the `.env`-sourcing/error-handling paths in the
scripts, since those require Docker. Both scripts pass `shellcheck`
with zero warnings; a real `docker compose up -d && ./scripts/backup.sh
&& ./scripts/restore.sh` run on your end is still worth doing once to
confirm the container-level wiring before relying on this.
