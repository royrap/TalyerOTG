-- QR & COMPLETION SYSTEM DATA
-- Run each query separately in Supabase

-- === JOB COMPLETION CODES ===
SELECT 'JOB_COMPLETION_CODES:' as info, COUNT(*) as total_records FROM job_completion_codes;
SELECT * FROM job_completion_codes LIMIT 50;

-- === SERVICE COMPLETIONS ===
SELECT 'SERVICE_COMPLETIONS:' as info, COUNT(*) as total_records FROM service_completions;
SELECT * FROM service_completions LIMIT 50;

-- === BUSINESS PERMITS ===
SELECT 'BUSINESS_PERMITS:' as info, COUNT(*) as total_records FROM business_permits;
SELECT * FROM business_permits LIMIT 50;

-- === DOCUMENT VERIFICATIONS ===
SELECT 'DOCUMENT_VERIFICATIONS:' as info, COUNT(*) as total_records FROM document_verifications;
SELECT * FROM document_verifications LIMIT 50;

-- === TALYER OWNER VERIFICATIONS ===
SELECT 'TALYER_OWNER_VERIFICATIONS:' as info, COUNT(*) as total_records FROM talyer_owner_verifications;
SELECT * FROM talyer_owner_verifications LIMIT 50;

-- === CASH PAYMENT VERIFICATIONS ===
SELECT 'CASH_PAYMENT_VERIFICATIONS:' as info, COUNT(*) as total_records FROM cash_payment_verifications;
SELECT * FROM cash_payment_verifications LIMIT 50;