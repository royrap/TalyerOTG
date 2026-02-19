-- Reset job for QR testing
-- Reset the service request status back to invoice_paid so we can test QR scanning
UPDATE service_requests 
SET 
  status = 'invoice_paid',
  completed_at = NULL,
  updated_at = NOW()
WHERE id = 'fd837d84-43c6-432b-bf88-6abaf816e184';

-- Generate a new QR completion code for testing
INSERT INTO job_completion_codes (
  request_id,
  customer_id,
  completion_code,
  is_used,
  created_at,
  expires_at,
  verification_status
) VALUES (
  'fd837d84-43c6-432b-bf88-6abaf816e184',
  (SELECT customer_id FROM service_requests WHERE id = 'fd837d84-43c6-432b-bf88-6abaf816e184'),
  'TEST-QR-' || substr(md5(random()::text), 1, 8),
  false,
  NOW(),
  NOW() + INTERVAL '24 hours',
  'pending'
);

-- Show the generated QR code
SELECT 
  'Generated QR Code for Testing' as info,
  jcc.completion_code,
  'requestId=' || jcc.request_id || '&code=' || jcc.completion_code as qr_data,
  jcc.expires_at
FROM job_completion_codes jcc
WHERE jcc.request_id = 'fd837d84-43c6-432b-bf88-6abaf816e184'
AND jcc.is_used = false
ORDER BY jcc.created_at DESC
LIMIT 1;