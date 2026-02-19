-- COMMUNICATION & TRACKING DATA
-- Run each query separately in Supabase

-- === NOTIFICATIONS ===
SELECT 'NOTIFICATIONS:' as info, COUNT(*) as total_records FROM notifications;
SELECT * FROM notifications LIMIT 50;

-- === MESSAGES ===
SELECT 'MESSAGES:' as info, COUNT(*) as total_records FROM messages;
SELECT * FROM messages LIMIT 50;

-- === EMAIL NOTIFICATIONS ===
SELECT 'EMAIL_NOTIFICATIONS:' as info, COUNT(*) as total_records FROM email_notifications;
SELECT * FROM email_notifications LIMIT 50;

-- === REQUEST BROADCASTS ===
SELECT 'REQUEST_BROADCASTS:' as info, COUNT(*) as total_records FROM request_broadcasts;
SELECT * FROM request_broadcasts LIMIT 50;

-- === MECHANIC AVAILABILITY STATUS ===
SELECT 'MECHANIC_AVAILABILITY_STATUS:' as info, COUNT(*) as total_records FROM mechanic_availability_status;
SELECT * FROM mechanic_availability_status LIMIT 50;

-- === CUSTOMER JOB HISTORY ===
SELECT 'CUSTOMER_JOB_HISTORY:' as info, COUNT(*) as total_records FROM customer_job_history;
SELECT * FROM customer_job_history LIMIT 50;

-- === MECHANIC JOB HISTORY ===
SELECT 'MECHANIC_JOB_HISTORY:' as info, COUNT(*) as total_records FROM mechanic_job_history;
SELECT * FROM mechanic_job_history LIMIT 50;

-- === REQUEST STATUS HISTORY ===
SELECT 'REQUEST_STATUS_HISTORY:' as info, COUNT(*) as total_records FROM request_status_history;
SELECT * FROM request_status_history LIMIT 50;

-- === AUDIT LOGS ===
SELECT 'AUDIT_LOGS:' as info, COUNT(*) as total_records FROM audit_logs;
SELECT * FROM audit_logs LIMIT 50;