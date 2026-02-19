-- SIMPLE TABLE DATA VIEWER - ONE TABLE AT A TIME
-- Run each section separately to see actual data
-- Copy and paste each section individually

-- === 1. USER_PROFILES - SHOW ALL USERS ===
SELECT * FROM user_profiles ORDER BY created_at DESC;

-- === 2. SERVICE_REQUESTS - SHOW ALL SERVICE REQUESTS ===
SELECT * FROM service_requests ORDER BY created_at DESC;

-- === 3. SHOPS - SHOW ALL SHOPS ===
SELECT * FROM shops ORDER BY created_at DESC;

-- === 4. INVOICES - SHOW ALL INVOICES ===
SELECT * FROM invoices ORDER BY generated_at DESC;

-- === 5. PAYMENTS - SHOW ALL PAYMENTS ===
SELECT * FROM payments ORDER BY created_at DESC;

-- === 6. JOB_COMPLETION_CODES - SHOW ALL QR CODES ===
SELECT * FROM job_completion_codes ORDER BY created_at DESC;

-- === 7. MECHANICS - SHOW ALL MECHANICS ===
SELECT * FROM mechanics ORDER BY created_at DESC;

-- === 8. SHOP_SERVICES - SHOW ALL SERVICES ===
SELECT * FROM shop_services ORDER BY created_at DESC;

-- === 9. BUSINESS_PERMITS - SHOW ALL PERMITS ===
SELECT * FROM business_permits ORDER BY created_at DESC;

-- === 10. NOTIFICATIONS - SHOW ALL NOTIFICATIONS ===
SELECT * FROM notifications ORDER BY created_at DESC;

-- === 11. MESSAGES - SHOW ALL MESSAGES ===
SELECT * FROM messages ORDER BY sent_at DESC;

-- === 12. SERVICE_CATEGORIES - SHOW ALL CATEGORIES ===
SELECT * FROM service_categories ORDER BY name;

-- === 13. VEHICLES - SHOW ALL VEHICLES ===
SELECT * FROM vehicles ORDER BY created_at DESC;

-- === 14. DOCUMENT_VERIFICATIONS - SHOW ALL VERIFICATIONS ===
SELECT * FROM document_verifications ORDER BY created_at DESC;

-- === 15. REVIEWS - SHOW ALL REVIEWS ===
SELECT * FROM reviews ORDER BY created_at DESC;