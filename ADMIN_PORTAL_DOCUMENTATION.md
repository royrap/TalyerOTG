# RoadAid Admin Portal System

## Overview

The RoadAid Admin Portal is a comprehensive administrative interface designed for managing the RoadAid multi-role platform. It provides separate access for system administrators to manage document verification, payment releases, dispute resolution, and system monitoring without interfering with the customer-facing application.

## Architecture

### Admin Access Separation
- **Main App (`lib/main.dart`)**: Admin users are redirected to customer dashboard (access restricted)
- **Admin Portal (`lib/main_admin.dart`)**: Dedicated entry point for admin access
- **Separate Authentication**: Admin users must use the dedicated admin login portal

### Key Features

#### 1. Document Verification System
- **File**: `lib/admin/admin_document_verification_screen.dart`
- **Features**:
  - Review business registration documents
  - AI-powered document analysis and tamper detection
  - Verification scoring system (75% minimum for approval)
  - Admin notes and rejection reasons
  - Audit trail for all verification decisions

#### 2. Payment Management
- **File**: `lib/admin/admin_payments_screen.dart`
- **Features**:
  - Monitor payment releases and escrow system
  - Release payments upon service completion
  - Hold payments for investigation
  - Platform fee tracking
  - Payment dispute handling

#### 3. Dispute Resolution
- **File**: `lib/admin/admin_dispute_resolution_screen.dart`
- **Features**:
  - Comprehensive dispute management system
  - Customer vs Provider dispute resolution
  - Evidence review and attachment handling
  - Multiple resolution types (favor customer, favor provider, partial refund, etc.)
  - Resolution tracking and audit trail

#### 4. System Monitoring
- **File**: `lib/admin/admin_system_monitoring_screen.dart`
- **Features**:
  - Real-time system health monitoring
  - Activity logs and audit trails
  - User statistics and analytics
  - Error tracking and reporting
  - System performance metrics

#### 5. Comprehensive Dashboard
- **File**: `lib/admin/admin_dashboard_screen.dart`
- **Features**:
  - Overview of all system metrics
  - Quick access to pending tasks
  - Real-time statistics updates
  - Admin activity logging
  - Secure admin authentication verification

## Database Schema

### Admin Tables
```sql
-- Admin activity logging
admin_activity_logs (
  id, admin_id, action_type, target_type, target_id, 
  action_details, created_at
)

-- Document verifications
talyer_owner_verifications (
  id, user_id, status, verification_score, tamper_flags,
  admin_notes, reviewed_by, reviewed_at
)

-- Payment management
payment_releases (
  id, request_id, customer_id, provider_id, total_amount,
  platform_fee, provider_amount, release_status
)

-- Dispute resolution
disputes (
  id, customer_id, provider_id, type, category, priority,
  description, status, resolution, ruling, resolved_by
)
```

### Database Functions
- **`get_admin_dashboard_stats()`**: Returns comprehensive dashboard statistics
- **Location**: `admin_dashboard_stats_function.sql`

## Security Features

### 1. Authentication & Authorization
- Separate admin login portal with enhanced security
- Admin privilege verification before access
- Session management and activity logging
- Role-based access control

### 2. Audit Trails
- All admin actions are logged with timestamps
- Complete audit trail for compliance
- Admin identification in all activities
- Target tracking for actions

### 3. Data Protection
- Secure document handling
- Payment information encryption
- Privacy-compliant data access
- RLS (Row Level Security) policies

## How to Run

### Customer App (Default)
```bash
flutter run
```

### Admin Portal
```bash
flutter run -t lib/main_admin.dart
```

### Development Setup
1. Initialize Supabase connection
2. Deploy database schema (see `.sql` files)
3. Create admin user accounts
4. Run admin portal application

## Admin User Requirements

### Document Verification Admin
- Access to review business documents
- Authority to approve/reject verifications
- Ability to add admin notes
- Document analysis capabilities

### Payment Admin
- Authority to release escrowed payments
- Ability to hold payments for investigation
- Platform fee monitoring access
- Payment dispute resolution

### Dispute Resolution Admin
- Full dispute case management
- Evidence review capabilities
- Resolution authority
- Communication with parties

### System Admin
- Full system monitoring access
- Error tracking and resolution
- User management capabilities
- Analytics and reporting access

## Admin Dashboard Features

### Real-Time Statistics
- Pending verifications count
- Active service requests
- Payment releases awaiting approval
- System health indicators
- Revenue tracking

### Quick Actions
- Jump to pending verification reviews
- Access payment release queue
- View active disputes
- System monitoring dashboard

### Activity Monitoring
- Real-time admin activity feed
- System error alerts
- User registration monitoring
- Performance metrics

## Production Deployment

### Database Setup
1. Deploy all `.sql` schema files
2. Create admin user accounts with proper roles
3. Set up RLS policies for admin access
4. Configure audit logging

### Application Deployment
1. Build admin portal: `flutter build web --target=lib/main_admin.dart`
2. Deploy to secure admin subdomain
3. Configure authentication restrictions
4. Set up monitoring and alerts

### Security Considerations
- Admin portal should be on separate subdomain
- Implement additional authentication (2FA recommended)
- Regular security audits of admin activities
- Backup and recovery procedures for admin actions

## API Integration

### Admin Service Classes
- `AdminPaymentService`: Payment management operations
- `AdminVerificationService`: Document verification operations
- `AdminDisputeService`: Dispute resolution operations
- `AdminMonitoringService`: System monitoring operations

### Supabase Integration
- Real-time subscriptions for live updates
- Secure RPC calls for admin operations
- Row-level security for data protection
- Audit logging integration

## Future Enhancements

### Advanced Analytics
- Detailed performance metrics
- User behavior analytics
- Financial reporting dashboard
- Predictive analytics for system health

### Enhanced Security
- Multi-factor authentication
- Advanced audit logging
- Intrusion detection
- Automated threat response

### Automation Features
- Automated document verification (AI)
- Smart dispute resolution suggestions
- Automated payment release triggers
- System health auto-recovery

## Support and Maintenance

### Admin Training Required
- Document verification procedures
- Payment release protocols
- Dispute resolution guidelines
- System monitoring best practices

### Regular Maintenance
- Review and update verification criteria
- Monitor payment processing performance
- Analyze dispute resolution effectiveness
- System health and security audits

---

**Note**: This admin portal is designed for production use with comprehensive security, audit trails, and administrative capabilities. All admin actions are logged and monitored for compliance and security purposes.
