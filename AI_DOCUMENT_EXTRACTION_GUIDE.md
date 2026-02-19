# AI Document Extraction and Auto-Approval System

## Overview

This system provides AI-powered document extraction and automatic approval for talyer owners during signup. It processes ID images and business permit images, extracts relevant data, validates the information, and automatically approves users when criteria are met.

## Key Features

1. **AI Document Extraction**: Extracts data from ID and business permit images
2. **Automatic Validation**: Compares extracted data to determine approval eligibility
3. **Auto-Approval**: Automatically approves users when criteria are met
4. **Shop Creation**: Creates shop records for approved users
5. **Manual Review**: Handles cases requiring manual admin review
6. **Audit Trail**: Logs all activities for security and compliance

## Core Functions

### 1. Main Processing Function

```sql
SELECT process_talyer_owner_documents_ai(
    user_id := 'uuid-here',
    id_image_url := 'https://storage.url/id-image.jpg',
    business_permit_url := 'https://storage.url/permit.jpg',
    business_name := 'Optional Business Name',
    business_address := 'Optional Address',
    contact_person := 'Optional Contact',
    phone_number := 'Optional Phone',
    email := 'Optional Email'
);
```

**Parameters:**
- `user_id` (required): UUID of the user
- `id_image_url` (required): URL to the uploaded ID image
- `business_permit_url` (required): URL to the uploaded business permit image
- `business_name` (optional): Business name override
- `business_address` (optional): Business address override
- `contact_person` (optional): Contact person override
- `phone_number` (optional): Phone number override
- `email` (optional): Email override

**Returns:** JSONB object with processing results

### 2. Check Verification Status

```sql
SELECT get_verification_status('user-uuid-here');
```

### 3. Manual Admin Approval

```sql
SELECT manually_approve_talyer_owner(
    verification_id := 'verification-uuid',
    admin_id := 'admin-user-uuid',
    admin_notes := 'Approved after additional verification'
);
```

## Auto-Approval Criteria

A user is automatically approved when ALL of the following conditions are met:

1. **Name Match**: The name on the ID matches the name on the business permit
2. **ID Not Expired**: The ID expiry date is in the future
3. **High Confidence**: AI extraction confidence score ≥ 80%
4. **Validation Score**: Overall validation score ≥ 70 points

### Validation Scoring System

- **Exact Name Match**: +40 points
- **Fuzzy Name Match**: +30 points
- **ID Not Expired**: +30 points
- **Permit Not Expired**: +20 points
- **High Confidence**: +10 points

## Usage Examples

### Example 1: Basic Document Processing

```sql
-- Process documents for a new talyer owner signup
SELECT process_talyer_owner_documents_ai(
    user_id := '123e4567-e89b-12d3-a456-426614174000',
    id_image_url := 'https://storage.supabase.co/bucket/ids/user123_id.jpg',
    business_permit_url := 'https://storage.supabase.co/bucket/permits/user123_permit.jpg'
);
```

**Sample Response (Auto-Approved):**
```json
{
  "success": true,
  "user_id": "123e4567-e89b-12d3-a456-426614174000",
  "verification_record_id": "987fcdeb-51a2-43d1-9f12-123456789abc",
  "auto_approved": true,
  "shop_id": "456e7890-e12c-34d5-b678-901234567def",
  "validation_result": {
    "names_match": true,
    "id_not_expired": true,
    "permit_not_expired": true,
    "auto_approve": true,
    "validation_score": 90,
    "id_name": "JUAN DELA CRUZ",
    "permit_owner_name": "JUAN DELA CRUZ"
  },
  "next_steps": "User approved automatically. Shop created. User can now login and manage their business."
}
```

**Sample Response (Pending Review):**
```json
{
  "success": true,
  "user_id": "123e4567-e89b-12d3-a456-426614174000",
  "verification_record_id": "987fcdeb-51a2-43d1-9f12-123456789abc",
  "auto_approved": false,
  "shop_id": null,
  "validation_result": {
    "names_match": false,
    "id_not_expired": true,
    "permit_not_expired": true,
    "auto_approve": false,
    "validation_score": 50,
    "id_name": "JUAN DELA CRUZ",
    "permit_owner_name": "MARIA SANTOS"
  },
  "next_steps": "Documents uploaded successfully. Manual review required before approval."
}
```

### Example 2: Check Verification Status

```sql
SELECT get_verification_status('123e4567-e89b-12d3-a456-426614174000');
```

**Sample Response:**
```json
{
  "user_id": "123e4567-e89b-12d3-a456-426614174000",
  "has_verification_record": true,
  "verification_status": "approved",
  "account_verification_status": "verified",
  "document_verification_status": "verified",
  "can_login": true,
  "has_shop": true,
  "shop_id": "456e7890-e12c-34d5-b678-901234567def",
  "shop_name": "Juan's Auto Repair",
  "verification_details": {
    "business_name": "Juan's Auto Repair",
    "verification_score": 90,
    "admin_notes": "Auto-approved by AI: Names match and ID not expired",
    "reviewed_at": "2025-09-01T10:30:00Z",
    "created_at": "2025-09-01T10:30:00Z"
  }
}
```

### Example 3: Manual Admin Approval

```sql
SELECT manually_approve_talyer_owner(
    verification_id := '987fcdeb-51a2-43d1-9f12-123456789abc',
    admin_id := 'admin-uuid-here',
    admin_notes := 'Verified identity through additional documentation'
);
```

## Database Tables Updated

The system interacts with the following tables:

1. **`talyer_owner_verifications`**: Main verification record
2. **`user_profiles`**: User account status and verification flags
3. **`shops`**: Auto-created shop records
4. **`service_providers`**: Links users to their shops
5. **`shop_services`**: Default services for new shops
6. **`business_permits`**: Extracted business permit data
7. **`document_verifications`**: Document processing logs
8. **`account_security_logs`**: Security and activity logs
9. **`admin_activity_logs`**: Admin action tracking

## Shop Creation Process

When a user is auto-approved, the system automatically:

1. **Creates Shop Record**: With extracted business information
2. **Links User Profile**: Updates `shop_id` in user profile
3. **Creates Service Provider**: Links user to their shop
4. **Adds Default Services**: Based on active service categories
5. **Sets Operating Hours**: Default 8AM-5PM weekdays

## AI Integration Notes

**Current Implementation**: The functions contain mock AI extraction logic that should be replaced with actual AI service calls.

**Recommended AI Services**:
- Google Cloud Vision API
- AWS Textract
- Azure Cognitive Services
- Custom OCR solutions

**Integration Points**:
- `extract_id_data_ai()`: Replace mock logic with actual ID extraction
- `extract_business_permit_data_ai()`: Replace mock logic with permit extraction

## Security Features

1. **RLS Policies**: Functions respect existing Row Level Security
2. **Audit Logging**: All actions logged in security and admin activity logs
3. **Validation Scoring**: Prevents low-confidence auto-approvals
4. **Manual Override**: Admins can approve/reject regardless of AI decision

## Error Handling

The system handles various error scenarios:

- **Invalid User ID**: Returns error with user not found
- **Missing Documents**: Gracefully handles partial data
- **Date Parsing Errors**: Continues processing with null dates
- **Extraction Failures**: Logs errors and requires manual review

## Monitoring and Reporting

Query pending verifications:
```sql
SELECT 
    v.*,
    u.email,
    u.first_name,
    u.last_name
FROM talyer_owner_verifications v
JOIN user_profiles u ON v.user_id = u.id
WHERE v.status = 'pending'
ORDER BY v.created_at DESC;
```

Query auto-approval rates:
```sql
SELECT 
    DATE(created_at) as date,
    COUNT(*) as total_submissions,
    COUNT(*) FILTER (WHERE status = 'approved' AND reviewed_by = user_id) as auto_approved,
    COUNT(*) FILTER (WHERE status = 'pending') as pending_review
FROM talyer_owner_verifications
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;
```

## Performance Considerations

1. **Indexes**: Created on frequently queried columns
2. **Batch Processing**: Functions can be called in bulk for migrations
3. **Async Processing**: Consider queue-based processing for high volume
4. **Caching**: Cache AI results to avoid re-processing

## Next Steps

1. **Integrate Real AI Services**: Replace mock extraction with actual AI APIs
2. **Add Image Validation**: Verify image quality and document types
3. **Enhance Fuzzy Matching**: Improve name comparison algorithms
4. **Add Webhook Support**: Notify external systems of approvals
5. **Create Admin Dashboard**: UI for managing pending verifications
