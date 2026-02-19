# Manual Verification System Documentation

## Overview
The Manual Verification System provides a robust fallback mechanism when AI verification fails. It allows admins to manually extract and save permit/ID data to the `talyer_owner_verifications` table.

## System Architecture

### 1. Database Schema
```sql
CREATE TABLE public.talyer_owner_verifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  business_name character varying NOT NULL,
  business_permit_url text NOT NULL,
  valid_id_url text NOT NULL,
  id_type character varying NOT NULL,
  permit_expiry_date date NULL,
  id_expiry_date date NULL,
  status character varying NULL DEFAULT 'pending',
  admin_notes text NULL,
  reviewed_by uuid NULL,
  reviewed_at timestamp with time zone NULL,
  created_at timestamp with time zone NULL DEFAULT now(),
  updated_at timestamp with time zone NULL DEFAULT now(),
  business_address text NULL,
  contact_person character varying NULL,
  phone_number character varying NULL,
  email character varying NULL,
  is_permit_expired boolean NULL DEFAULT false,
  is_id_expired boolean NULL DEFAULT false,
  tamper_flags jsonb NULL DEFAULT '[]'::jsonb,
  verification_score integer NULL DEFAULT 0,
  -- Constraints and indexes...
);
```

### 2. Core Components

#### A. ManualVerificationService (`lib/services/manual_verification_service.dart`)
**Purpose:** Core service for handling manual verification operations

**Key Methods:**
- `saveManualVerification()` - Save complete verification data
- `extractPermitDataManually()` - Extract business permit data manually
- `extractIdDataManually()` - Extract valid ID data manually
- `completeManualVerification()` - Complete the full manual verification process
- `updateVerificationStatus()` - Update verification status (pending/approved/rejected)
- `addTamperFlags()` - Add tamper detection flags
- `getPendingVerifications()` - Get all pending verifications for admin review

#### B. ManualVerificationScreen (`lib/screens/manual_verification_screen.dart`)
**Purpose:** Interactive UI for admins to manually extract and verify document data

**Features:**
- Document preview (side-by-side permit and ID display)
- Manual data entry forms for:
  - Business permit data (name, number, address, expiry date)
  - Valid ID data (name, number, type, expiry date, birth date)
  - Contact information (address, phone, email)
- Verification controls (status, admin notes, tamper flags)
- Save and approve/reject actions

#### C. AdminManualVerificationDashboard (`lib/screens/admin_manual_verification_dashboard.dart`)
**Purpose:** Admin dashboard to view and manage all pending manual verifications

**Features:**
- List of all pending verifications
- Filtering by status (pending, under_review, approved, rejected)
- Quick approve/reject actions
- Detailed verification cards showing:
  - Business name and contact person
  - Verification score and creation date
  - Tamper flags and admin notes
  - Status indicators with color coding

### 3. Integration with Signup Process

#### A. AI Verification Fallback
When AI verification fails in `signup_screen.dart`, the system automatically:
1. Saves document URLs and user information for manual review
2. Creates a pending verification record with tamper flag `'ai_failed'`
3. Displays user-friendly message about manual review process
4. Allows user to continue with registration

#### B. Error Handling Enhanced
```dart
} catch (e) {
  // Save documents for manual verification when AI fails
  await _saveForManualVerification(permitUrl, idUrl, e.toString());
  
  setState(() {
    _verificationStatus = '''❌ AI VERIFICATION FAILED
    
🤖 AI verification encountered an error: ${e.toString()}

✅ Your documents have been saved and will be manually reviewed by our admin team.
📧 You will receive an email notification once the review is complete.
    
Please continue with your registration - manual verification is in progress.''';
  });
}
```

## Workflow Process

### 1. User Registration with Document Upload
1. User uploads business permit and valid ID
2. System attempts AI verification
3. **If AI fails:** Documents automatically saved for manual verification
4. User sees confirmation that manual review is queued
5. User can continue registration process

### 2. Admin Manual Verification Process
1. Admin opens `AdminManualVerificationDashboard`
2. Views list of pending verifications
3. Selects verification to review
4. Opens `ManualVerificationScreen`
5. Manually extracts data from document images:
   - Business permit details
   - Valid ID information
   - Contact details
6. Sets verification status and adds notes
7. Saves verification (auto-calculates score)
8. User receives notification of decision

### 3. Verification Scoring System
Manual verifications are scored based on:
- **Base Score:** 30 points for manual verification
- **Completeness:** +15 points for business name, +15 for full name
- **Documentation:** +10 points each for permit/ID numbers
- **Expiry Dates:** +10 points each for valid expiry dates
- **Name Matching:** +15 points for business name match, +10 for person name match
- **Address Info:** +5 points for business address

**Score Range:** 0-100 points
- **70-100:** High confidence, typically approved
- **40-69:** Medium confidence, requires review
- **0-39:** Low confidence, likely rejected

### 4. Tamper Detection Flags
Available tamper flags for manual verification:
- `ai_failed` - AI verification failed (auto-added)
- `poor_quality` - Document quality issues
- `possible_tampering` - Suspected document tampering
- `name_mismatch` - Names don't match between documents
- `expired` - Documents are expired

## Usage Instructions

### For Developers

#### 1. Enable Manual Verification
```dart
// Import the service
import '../services/manual_verification_service.dart';

// Save for manual verification when AI fails
await ManualVerificationService.saveManualVerification(
  userId: userId,
  businessName: businessName,
  businessPermitUrl: permitUrl,
  validIdUrl: idUrl,
  idType: 'auto_detect',
  contactPerson: contactPerson,
  status: 'pending',
);
```

#### 2. Open Admin Dashboard
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const AdminManualVerificationDashboard(),
  ),
);
```

#### 3. Open Manual Verification Screen
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ManualVerificationScreen(
      userId: verification['user_id'],
      businessPermitUrl: verification['business_permit_url'],
      validIdUrl: verification['valid_id_url'],
      businessName: verification['business_name'],
      contactPerson: verification['contact_person'],
    ),
  ),
);
```

### For Admins

#### 1. Access Admin Dashboard
- Navigate to Admin → Manual Verifications
- View all pending verification requests
- Filter by status if needed

#### 2. Review Verification Request
- Click on verification card to open detailed review
- Examine document images side-by-side
- Extract data manually into provided forms

#### 3. Complete Verification
- Fill in all available information from documents
- Set appropriate verification status
- Add admin notes explaining decision
- Flag any tamper detection issues
- Save verification (score calculated automatically)

#### 4. Quick Actions
- Use "Quick Approve" for obviously valid documents
- Use "Quick Reject" with reason for clearly invalid documents
- Use full review process for complex cases

## Error Handling

### 1. AI Verification Failures
- Documents automatically saved for manual review
- User informed of manual review process
- Temporary verification ID generated for tracking

### 2. Manual Verification Errors
- Form validation prevents incomplete submissions
- Error messages guide admin to fix issues
- Failed saves don't lose entered data

### 3. Database Constraints
- UUID validation ensures proper format
- Status enum validation prevents invalid statuses
- Required fields enforced at form level

## Security Considerations

### 1. Access Control
- Admin dashboard should be protected by authentication
- Only authorized admins should access verification screens
- User data should be handled securely

### 2. Data Privacy
- Document URLs should use secure storage
- Personal information should be encrypted
- Admin notes should not contain sensitive data

### 3. Audit Trail
- All verification actions logged with timestamps
- Admin actions tracked for accountability
- Status changes recorded for compliance

## Benefits

### 1. Reliability
- 100% fallback coverage when AI fails
- No user registrations lost due to AI errors
- Consistent verification process

### 2. Flexibility
- Admins can handle edge cases AI cannot
- Manual scoring adapts to document quality
- Custom tamper flags for specific issues

### 3. User Experience
- Seamless transition from AI to manual verification
- Clear communication about review process
- No need to re-upload documents

### 4. Admin Efficiency
- Streamlined interface for batch processing
- Quick actions for obvious cases
- Detailed tools for complex verification

## Future Enhancements

### 1. Notification System
- Email notifications for status changes
- SMS alerts for urgent verifications
- In-app notifications for users

### 2. Batch Operations
- Bulk approve/reject functionality
- Batch status updates
- Export verification reports

### 3. Machine Learning Integration
- Learn from manual verification patterns
- Improve AI accuracy over time
- Automated pre-scoring for manual reviews

### 4. Integration APIs
- Webhook notifications for status changes
- API endpoints for external integrations
- Real-time verification updates

## Testing

### 1. Unit Tests
- Test all ManualVerificationService methods
- Validate scoring algorithm accuracy
- Test error handling scenarios

### 2. Integration Tests
- Test full workflow from AI failure to manual completion
- Verify database constraints and triggers
- Test admin dashboard functionality

### 3. User Acceptance Tests
- Admin workflow testing
- User experience validation
- Performance testing with large verification queues

This manual verification system ensures that no user registration is lost due to AI verification failures while providing admins with powerful tools to efficiently process verification requests.
