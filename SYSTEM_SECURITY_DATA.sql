-- SYSTEM MANAGEMENT & SECURITY DATA
-- Run each query separately in Supabase

-- === SHOP MECHANICS ===
SELECT 'SHOP_MECHANICS:' as info, COUNT(*) as total_records FROM shop_mechanics;
SELECT * FROM shop_mechanics LIMIT 50;

-- === PAYMENT METHODS ===
SELECT 'PAYMENT_METHODS:' as info, COUNT(*) as total_records FROM payment_methods;
SELECT * FROM payment_methods LIMIT 50;

-- === PAYMENT RELEASES ===
SELECT 'PAYMENT_RELEASES:' as info, COUNT(*) as total_records FROM payment_releases;
SELECT * FROM payment_releases LIMIT 50;

-- === PAYMONGO WEBHOOK EVENTS ===
SELECT 'PAYMONGO_WEBHOOK_EVENTS:' as info, COUNT(*) as total_records FROM paymongo_webhook_events;
SELECT * FROM paymongo_webhook_events LIMIT 50;

-- === ACCOUNT SECURITY LOGS ===
SELECT 'ACCOUNT_SECURITY_LOGS:' as info, COUNT(*) as total_records FROM account_security_logs;
SELECT * FROM account_security_logs LIMIT 50;

-- === PASSWORD RESET TOKENS ===
SELECT 'PASSWORD_RESET_TOKENS:' as info, COUNT(*) as total_records FROM password_reset_tokens;
SELECT * FROM password_reset_tokens LIMIT 50;

-- === EMAIL VERIFICATION TOKENS ===
SELECT 'EMAIL_VERIFICATION_TOKENS:' as info, COUNT(*) as total_records FROM email_verification_tokens;
SELECT * FROM email_verification_tokens LIMIT 50;

-- === TEMPORARY PASSWORDS ===
SELECT 'TEMPORARY_PASSWORDS:' as info, COUNT(*) as total_records FROM temporary_passwords;
SELECT * FROM temporary_passwords LIMIT 50;

-- === MECHANIC INVITATIONS ===
SELECT 'MECHANIC_INVITATIONS:' as info, COUNT(*) as total_records FROM mechanic_invitations;
SELECT * FROM mechanic_invitations LIMIT 50;

-- === APP DOWNLOADS ===
SELECT 'APP_DOWNLOADS:' as info, COUNT(*) as total_records FROM app_downloads;
SELECT * FROM app_downloads LIMIT 50;