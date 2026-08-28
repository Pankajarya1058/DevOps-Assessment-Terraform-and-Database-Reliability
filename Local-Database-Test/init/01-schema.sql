-- ---------------------------------------------------------------------
-- Schema for hotel_bookings / booking_events, adapted from the suggested
-- Postgres-flavored types to their MySQL equivalents:
--   UUID       -> CHAR(36)      (stored as text; app generates the UUID,
--                                 e.g. via uuid_generate() in code - MySQL
--                                 has no native UUID column type)
--   NUMERIC    -> DECIMAL       (identical semantics in MySQL)
--   JSONB      -> JSON          (MySQL's JSON type; validated + binary
--                                 storage internally, no GIN indexing
--                                 like Postgres JSONB but fine for a
--                                 local test DB)
--   BIGSERIAL  -> BIGINT AUTO_INCREMENT
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS hotel_bookings (
  id             CHAR(36)       NOT NULL,
  org_id         CHAR(36)       NOT NULL,
  hotel_id       VARCHAR(100)   NOT NULL,
  city           VARCHAR(100)   NOT NULL,
  checkin_date   DATE           NOT NULL,
  checkout_date  DATE           NOT NULL,
  amount         DECIMAL(12,2)  NOT NULL,
  status         VARCHAR(50)    NOT NULL,
  created_at     TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_hotel_bookings_org_id (org_id),
  KEY idx_hotel_bookings_hotel_id (hotel_id),
  KEY idx_hotel_bookings_status (status),
  KEY idx_hotel_bookings_checkin_date (checkin_date),
  CONSTRAINT chk_hotel_bookings_dates CHECK (checkout_date > checkin_date),
  CONSTRAINT chk_hotel_bookings_amount CHECK (amount >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS booking_events (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  booking_id   CHAR(36)        NOT NULL,
  event_type   VARCHAR(100)    NOT NULL,
  payload      JSON            NULL,
  created_at   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_booking_events_booking_id (booking_id),
  KEY idx_booking_events_event_type (event_type),
  CONSTRAINT fk_booking_events_booking
    FOREIGN KEY (booking_id) REFERENCES hotel_bookings (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Grant the app user full DML on this database (init scripts run as
-- root, so this only needs to run once).
GRANT SELECT, INSERT, UPDATE, DELETE ON hotel_bookings_db.* TO 'app_user'@'%';
FLUSH PRIVILEGES;
