-- Debug QR completion codes and history
-- Check for any QR completion codes for the service request
SELECT 
  'QR Completion Codes' as table_name,
  jcc.id,
  jcc.request_id,
  jcc.completion_code,
  jcc.is_used,
  jcc.created_at,
  jcc.expires_at,
  sr.status as service_request_status
FROM job_completion_codes jcc
LEFT JOIN service_requests sr ON jcc.request_id = sr.id
WHERE jcc.request_id = 'fd837d84-43c6-432b-bf88-6abaf816e184'
ORDER BY jcc.created_at DESC;

-- Check mechanic job history
SELECT 
  'Mechanic Job History' as table_name,
  mjh.id,
  mjh.service_request_id,
  mjh.mechanic_id,
  mjh.action_type,
  mjh.status_from,
  mjh.status_to,
  mjh.completed_at,
  mjh.created_at
FROM mechanic_job_history mjh
WHERE mjh.service_request_id = 'fd837d84-43c6-432b-bf88-6abaf816e184'
ORDER BY mjh.created_at DESC;

-- Check customer job history  
SELECT 
  'Customer Job History' as table_name,
  cjh.id,
  cjh.service_request_id,
  cjh.customer_id,
  cjh.action_type,
  cjh.status_from,
  cjh.status_to,
  cjh.completed_at,
  cjh.created_at
FROM customer_job_history cjh
WHERE cjh.service_request_id = 'fd837d84-43c6-432b-bf88-6abaf816e184'
ORDER BY cjh.created_at DESC;

-- Check current service request status
SELECT 
  'Current Service Request' as table_name,
  sr.id,
  sr.status,
  sr.assigned_mechanic_id,
  sr.completed_at,
  sr.created_at,
  sr.updated_at
FROM service_requests sr
WHERE sr.id = 'fd837d84-43c6-432b-bf88-6abaf816e184';