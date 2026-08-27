-- ---------------------------------------------------------------------
-- Sample rows for local testing. UUIDs below are fixed/hardcoded (not
-- generated at insert time) so foreign keys between the two tables line
-- up predictably across re-runs of a fresh container.
-- ---------------------------------------------------------------------

INSERT INTO hotel_bookings
  (id, org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at)
VALUES
  ('b1a7e8b2-1111-4a11-9a11-000000000001', 'a0a7e8b2-org1-4a11-9a11-0000000000a1', 'HTL-DEL-001', 'Delhi',     '2026-09-10', '2026-09-13', 14500.00, 'CONFIRMED', '2026-08-20 10:15:00'),
  ('b1a7e8b2-2222-4a11-9a11-000000000002', 'a0a7e8b2-org1-4a11-9a11-0000000000a1', 'HTL-BOM-014', 'Mumbai',   '2026-09-05', '2026-09-07', 9800.50,  'CONFIRMED', '2026-08-18 09:02:00'),
  ('b1a7e8b2-3333-4a11-9a11-000000000003', 'a0a7e8b2-org2-4a11-9a11-0000000000a2', 'HTL-BLR-007', 'Bengaluru','2026-10-01', '2026-10-04', 21000.00, 'PENDING',   '2026-08-25 14:47:00'),
  ('b1a7e8b2-4444-4a11-9a11-000000000004', 'a0a7e8b2-org2-4a11-9a11-0000000000a2', 'HTL-GOA-002', 'Goa',      '2026-12-24', '2026-12-28', 48250.00, 'CONFIRMED', '2026-08-26 11:30:00'),
  ('b1a7e8b2-5555-4a11-9a11-000000000005', 'a0a7e8b2-org1-4a11-9a11-0000000000a1', 'HTL-DEL-001', 'Delhi',    '2026-09-15', '2026-09-16', 5200.00,  'CANCELLED', '2026-08-19 08:00:00');

INSERT INTO booking_events
  (booking_id, event_type, payload, created_at)
VALUES
  ('b1a7e8b2-1111-4a11-9a11-000000000001', 'BOOKING_CREATED', JSON_OBJECT('source', 'web', 'channel', 'direct'), '2026-08-20 10:15:00'),
  ('b1a7e8b2-1111-4a11-9a11-000000000001', 'PAYMENT_CAPTURED', JSON_OBJECT('method', 'card', 'last4', '4242'), '2026-08-20 10:16:30'),
  ('b1a7e8b2-2222-4a11-9a11-000000000002', 'BOOKING_CREATED', JSON_OBJECT('source', 'mobile_app', 'channel', 'direct'), '2026-08-18 09:02:00'),
  ('b1a7e8b2-3333-4a11-9a11-000000000003', 'BOOKING_CREATED', JSON_OBJECT('source', 'web', 'channel', 'partner', 'partner_id', 'EXPEDIA'), '2026-08-25 14:47:00'),
  ('b1a7e8b2-4444-4a11-9a11-000000000004', 'BOOKING_CREATED', JSON_OBJECT('source', 'web', 'channel', 'direct'), '2026-08-26 11:30:00'),
  ('b1a7e8b2-4444-4a11-9a11-000000000004', 'PAYMENT_CAPTURED', JSON_OBJECT('method', 'upi'), '2026-08-26 11:32:00'),
  ('b1a7e8b2-5555-4a11-9a11-000000000005', 'BOOKING_CREATED', JSON_OBJECT('source', 'web', 'channel', 'direct'), '2026-08-19 08:00:00'),
  ('b1a7e8b2-5555-4a11-9a11-000000000005', 'BOOKING_CANCELLED', JSON_OBJECT('reason', 'customer_request'), '2026-08-19 12:00:00');
