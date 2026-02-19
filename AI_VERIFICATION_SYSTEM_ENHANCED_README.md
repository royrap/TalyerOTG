# Enhanced AI Verification System with Expiry Checking

## Overview
This enhanced AI verification system automatically validates Talyer Owner documents and credentials with comprehensive expiry date checking and automatic rejection of expired documents.

## Key Features

### 🤖 Automatic Document Verification
- **Real-time Processing**: Documents are verified immediately upon upload
- **Expiry Date Checking**: Automatic validation of permit and ID expiry dates
- **Auto-Rejection**: Expired documents are automatically rejected
- **Name Matching**: Advanced algorithm to match business names with contact persons
- **Confidence Scoring**: Each verification receives a confidence score (0-100%)

### 📋 Database Schema
The system uses the `talyer_owner_verifications` table with the following key fields:

```sql
CREATE TABLE talyer_owner_verifications (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    business_name VARCHAR NOT NULL,
    business_permit_url TEXT NOT NULL,
    valid_id_url TEXT NOT NULL,
    id_type VARCHAR CHECK (id_type IN ('drivers_license', 'umid', 'national_id', 'passport', 'philsys_id')),
    permit_expiry_date DATE,
    id_expiry_date DATE,
    is_permit_expired BOOLEAN DEFAULT FALSE,
    is_id_expired BOOLEAN DEFAULT FALSE,
    status VARCHAR DEFAULT 'pending' CHECK (status IN ('pending', 'under_review', 'approved', 'rejected')),
    verification_score INTEGER DEFAULT 0,
    admin_notes TEXT,
    tamper_flags JSONB DEFAULT '[]',
    -- ... other fields
);
```

### 🔍 Verification Process

#### 1. Document Upload
- User uploads business permit and valid ID
- System validates file formats and URLs
- Expiry dates are extracted/entered

#### 2. Expiry Validation
```dart
// Check for expired documents
final expiryCheck = _checkDocumentExpiry(permitExpiryDate, idExpiryDate);
if (!expiryCheck['valid']) {
    // Auto-reject expired documents
    return {
        'should_approve': false,
        'confidence_score': 0,
        'rejection_reason': expiryCheck['reason'],
    };
}
```

#### 3. Enhanced Verification
- **Business Name Validation**: Checks length and format
- **Contact Person Validation**: Ensures proper name format
- **Name Matching Algorithm**: Advanced matching between business and person names
- **Document Authenticity**: Simulated AI authenticity scoring
- **URL Validation**: Ensures proper image URLs

#### 4. Database Functions
The system includes several PostgreSQL functions:

##### `check_document_expiry()` Trigger
```sql
-- Automatically sets expiry flags and rejects expired documents
CREATE OR REPLACE FUNCTION check_document_expiry()
RETURNS TRIGGER AS $$
BEGIN
    -- Check and set expiry flags
    NEW.is_permit_expired = (NEW.permit_expiry_date < CURRENT_DATE);
    NEW.is_id_expired = (NEW.id_expiry_date < CURRENT_DATE);
    
    -- Auto-reject if expired
    IF NEW.is_permit_expired OR NEW.is_id_expired THEN
        NEW.status = 'rejected';
        NEW.admin_notes = 'AUTO-REJECTED: Expired documents';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

##### `auto_verify_talyer_documents()` Function
```sql
-- Main verification logic with expiry checking
CREATE OR REPLACE FUNCTION auto_verify_talyer_documents(
    p_user_id UUID,
    p_business_name VARCHAR,
    p_contact_person VARCHAR,
    p_permit_expiry DATE,
    p_id_expiry DATE
) RETURNS verification_result;
```

##### `process_verification_queue()` Function
```sql
-- Batch process pending verifications
CREATE OR REPLACE FUNCTION process_verification_queue()
RETURNS processing_summary;
```

### 📊 Verification Logic

#### Confidence Scoring System
```dart
int confidenceScore = 100;

// Deductions:
// - Invalid business name: -30 points
// - Invalid contact person: -30 points
// - Invalid URLs: -20 points each
// - Name mismatch: -15 points
// - Documents expire soon: -10 points each
// - Invalid ID type: -15 points

// Approval threshold: >= 70% confidence
bool shouldApprove = confidenceScore >= 70 && concerns.length <= 2;
```

#### Name Matching Algorithm
```dart
Map<String, dynamic> _enhancedNameMatching(String businessName, String contactPerson) {
    int score = 0;
    
    // Scoring criteria:
    // - First name in business: +30 points
    // - Last name in business: +25 points
    // - Automotive business patterns: +10 points
    // - Initials matching: +20 points
    // - Similar words found: +15 points
    
    return {'score': score, 'details': details};
}
```

### 🚨 Automatic Rejection Criteria

Documents are automatically rejected if:
1. **Business permit is expired** (permit_expiry_date < current_date)
2. **Valid ID is expired** (id_expiry_date < current_date)
3. **Confidence score below 70%**
4. **Invalid document URLs**
5. **Missing required information**

### ⚠️ Warning Conditions

System flags warnings for:
1. **Documents expiring within 30 days**
2. **Low name similarity scores**
3. **Unusual business patterns**
4. **Low document authenticity scores**

### 📈 Statistics and Monitoring

#### Verification Statistics View
```sql
CREATE VIEW verification_stats AS
SELECT 
    COUNT(*) as total_verifications,
    COUNT(*) FILTER (WHERE status = 'approved') as approved_count,
    COUNT(*) FILTER (WHERE status = 'rejected') as rejected_count,
    COUNT(*) FILTER (WHERE is_permit_expired = true) as expired_permits,
    COUNT(*) FILTER (WHERE is_id_expired = true) as expired_ids,
    ROUND(AVG(verification_score), 2) as avg_verification_score;
```

#### User Verification Details
```sql
-- Get detailed verification info for a user
SELECT * FROM get_verification_details('user-uuid');
```

### 🔧 Usage Examples

#### Basic Verification
```dart
final result = await SimpleAIVerificationService.instance.verifyTalyerOwnerDocuments(
    userId: 'user-123',
    businessPermitUrl: 'https://example.com/permit.jpg',
    validIdUrl: 'https://example.com/id.jpg',
    businessName: 'Cruz Auto Repair',
    contactPerson: 'Juan Cruz',
    permitExpiryDate: DateTime(2025, 12, 31),
    idExpiryDate: DateTime(2027, 6, 15),
    idType: 'drivers_license',
);

if (result['should_approve']) {
    await service.approveVerification(userId, result);
} else {
    await service.rejectVerification(userId, result);
}
```

#### Database Verification
```dart
final dbResult = await service.runDatabaseVerification(
    userId: 'user-123',
    businessName: 'Cruz Auto Repair',
    contactPerson: 'Juan Cruz',
    permitExpiryDate: DateTime(2025, 12, 31),
    idExpiryDate: DateTime(2027, 6, 15),
);
```

#### Process Verification Queue
```dart
final queueResult = await service.processVerificationQueue();
print('Processed: ${queueResult['processed_count']}');
print('Approved: ${queueResult['approved_count']}');
print('Rejected: ${queueResult['rejected_count']}');
```

### 🔐 Security Features

1. **Automatic Expiry Checking**: No manual oversight needed for expired documents
2. **Tamper Detection**: Flags suspicious patterns in verification attempts
3. **Confidence Scoring**: Multi-factor assessment prevents false approvals
4. **Audit Trail**: Complete logging of all verification decisions
5. **Role-Based Access**: Only authorized personnel can override automatic decisions

### 📱 Testing the System

Use the `VerificationTestScreen` to test different scenarios:
1. **Valid Documents**: Should be approved with high confidence
2. **Expired Documents**: Should be auto-rejected with zero confidence
3. **Expiring Soon**: Should pass with warnings
4. **Queue Processing**: Batch verification testing

### 🚀 Production Deployment

1. Run `enhanced_ai_verification_system.sql` to set up database functions
2. Ensure proper database permissions are granted
3. Test with sample data using `test_verification_system.sql`
4. Monitor verification statistics regularly
5. Set up automated queue processing if needed

### 📋 Maintenance

#### Regular Tasks
- Monitor verification success rates
- Review rejected verifications for patterns
- Update name matching algorithms as needed
- Clean up old verification records
- Update expiry warning thresholds

#### Performance Optimization
- Index verification status and dates
- Batch process verifications during low-traffic periods
- Archive old verification records
- Monitor database function performance

## Conclusion

This enhanced AI verification system provides:
- ✅ **Automatic expiry checking** with instant rejection of expired documents
- ✅ **Sophisticated name matching** algorithms
- ✅ **Comprehensive confidence scoring**
- ✅ **Real-time verification processing**
- ✅ **Complete audit trails**
- ✅ **Scalable batch processing**
- ✅ **Security and tamper detection**

The system ensures that only valid, non-expired documents are approved for Talyer Owner verification, maintaining the integrity and security of the RoadAid platform.
