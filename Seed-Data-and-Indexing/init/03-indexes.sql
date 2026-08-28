-- ---------------------------------------------------------------------
-- Optimizes:
--
--   SELECT org_id, status, COUNT(*), SUM(amount)
--   FROM hotel_bookings
--   WHERE city = 'delhi'
--     AND created_at >= NOW() - INTERVAL 30 DAY
--   GROUP BY org_id, status;
--
-- See README.md for the full before/after EXPLAIN output and the
-- reasoning behind the column order chosen here.
-- ---------------------------------------------------------------------

CREATE INDEX idx_hotel_bookings_city_created_covering
  ON hotel_bookings (city, created_at, org_id, status, amount);
