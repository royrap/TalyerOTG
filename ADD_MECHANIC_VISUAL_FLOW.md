# Add Mechanic System - Visual Flow Diagram

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                         ADD MECHANIC SYSTEM FLOW                              ║
╚═══════════════════════════════════════════════════════════════════════════════╝

┌─────────────────────────────────────────────────────────────────────────────┐
│                         TALYER OWNER SIDE                                   │
└─────────────────────────────────────────────────────────────────────────────┘

    [Mechanics Performance Screen]
              │
              ▼
    [Click "Add Mechanic" FAB] 🟠
              │
              ▼
    ┌─────────────────────────┐
    │  Add Mechanic Dialog    │
    │  ┌───────────────────┐  │
    │  │  Profile Picture  │◄─┼─── Required Field (Image Picker)
    │  │    📷 Camera      │  │
    │  └───────────────────┘  │
    │                         │
    │  📧 Email Address       │◄─── Unique validation
    │  👤 First Name          │
    │  👤 Last Name           │
    │  📱 Phone Number        │
    │  🔧 Specialization     │
    │  📅 Years Experience    │
    │                         │
    │  ℹ️  Email notification │
    │     with credentials   │
    │                         │
    │  [Add Mechanic] 🟠     │
    └─────────┬───────────────┘
              │
              ▼
    ┌─────────────────────────────┐
    │  API: addMechanic()         │
    │  • Upload profile image     │
    │  • Generate temp password   │
    │  • Create user account      │
    │  • Insert into 7 tables     │
    │  • Send email              │
    └─────────┬───────────────────┘
              │
              ▼
    ┌─────────────────────────────┐
    │  Database Operations        │
    │  ✓ user_profiles           │
    │  ✓ service_providers       │
    │  ✓ shop_mechanics          │
    │  ✓ temporary_passwords     │
    │  ✓ email_verification_tkns │
    │  ✓ email_notifications     │
    │  ✓ admin_activity_logs     │
    └─────────┬───────────────────┘
              │
              ▼
    ✅ Success! Mechanic Added
              │
              ├─────────────────────────┐
              │                         │
              ▼                         ▼
    [List Refreshes]        [Email Sent] 📧


┌─────────────────────────────────────────────────────────────────────────────┐
│                            MECHANIC SIDE                                    │
└─────────────────────────────────────────────────────────────────────────────┘

    📧 [Receive Welcome Email]
              │
              ├─── Email contains:
              │    • Welcome message
              │    • Shop information
              │    • Login credentials
              │      - Email
              │      - Temporary Password
              │    • Instructions
              │    • Expiry (7 days)
              │
              ▼
    🔗 [Click Email Verification Link]
              │
              ▼
    ✅ Email Verified
       • can_login = TRUE
       • requires_email_verification = FALSE
              │
              ▼
    📱 [Download RoadAid App]
              │
              ▼
    🔐 [Login Screen]
       • Enter Email
       • Enter Temporary Password
       • Click "Sign In"
              │
              ▼
    ┌─────────────────────────────┐
    │  Login Validation           │
    │  ✓ Check email verified     │
    │  ✓ Check first login        │
    │  ✓ Check password required  │
    └─────────┬───────────────────┘
              │
    ┌─────────┴─────────┐
    │                   │
    ▼                   ▼
[Email NOT          [Email Verified
 Verified?]          AND First Login?]
    │                   │
    ▼                   ▼
❌ Error         🔄 AUTOMATIC REDIRECT
"Verify email        │
 first"              ▼
                ┌────────────────────────────────┐
                │ First Login Password Change     │
                │ Screen                          │
                │ ⚠️ MANDATORY - Cannot Skip      │
                │                                 │
                │ 🔒 Current (Temp) Password     │
                │ 🔒 New Password                │
                │    ✓ Min 8 chars               │
                │    ✓ 1 uppercase               │
                │    ✓ 1 lowercase               │
                │    ✓ 1 number                  │
                │ 🔒 Confirm Password            │
                │                                 │
                │ ℹ️  Password Requirements      │
                │                                 │
                │ [Change Password & Continue]    │
                └────────┬───────────────────────┘
                         │
                         ▼
                ┌────────────────────────────────┐
                │ Update Operations              │
                │ • Update auth password         │
                │ • Set password_change_required │
                │   = FALSE                      │
                │ • Set first_login_completed    │
                │   = TRUE                       │
                │ • Mark temp password as used   │
                │ • Log security event           │
                └────────┬───────────────────────┘
                         │
                         ▼
                ✅ Password Changed Successfully!
                         │
                         ▼
                🎉 [Redirect to Mechanic Dashboard]


┌─────────────────────────────────────────────────────────────────────────────┐
│                         SECURITY CHECKPOINTS                                │
└─────────────────────────────────────────────────────────────────────────────┘

    Checkpoint 1: Profile Picture Required
                 ↓
    Checkpoint 2: Email Uniqueness
                 ↓
    Checkpoint 3: Secure Password Generation
                 ↓
    Checkpoint 4: Email Verification
                 ↓
    Checkpoint 5: First Login Detection
                 ↓
    Checkpoint 6: Mandatory Password Change
                 ↓
    Checkpoint 7: Strong Password Validation
                 ↓
    Checkpoint 8: Audit Logging
                 ↓
    ✅ SECURE ACCESS GRANTED


┌─────────────────────────────────────────────────────────────────────────────┐
│                         DATABASE RELATIONSHIPS                              │
└─────────────────────────────────────────────────────────────────────────────┘

    ┌──────────────────┐
    │  user_profiles   │◄──── Main user record
    │  • id (PK)       │
    │  • email         │
    │  • user_type     │
    │  • shop_id       │
    └────┬─────────────┘
         │
         ├─────────────────────┐
         │                     │
         ▼                     ▼
┌─────────────────┐   ┌──────────────────┐
│service_providers│   │  shop_mechanics  │
│• user_id (FK)   │   │  • mechanic_id   │
│• shop_id (FK)   │   │  • shop_id (FK)  │
│• talyer_owner_id│   │  • role          │
└─────────────────┘   └──────────────────┘
         │
         ▼
┌──────────────────────┐
│ temporary_passwords  │
│ • user_id (FK)       │
│ • temp_password      │
│ • expires_at         │
│ • is_active          │
└──────────────────────┘
         │
         ▼
┌─────────────────────────┐
│ email_verification_tkns │
│ • user_id (FK)          │
│ • token                 │
│ • is_active             │
└─────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────────┐
│                         FILE STRUCTURE                                      │
└─────────────────────────────────────────────────────────────────────────────┘

lib/
├── talyer_owner/
│   ├── mechanics_performance_screen.dart
│   │   ├── [Modified] Added FAB button
│   │   └── [Added] AddMechanicDialog widget
│   │
│   └── talyer_owner_api_service.dart
│       └── [Added] addMechanic() method
│
└── mechanic/
    ├── mechanic_login_screen.dart
    │   └── [Modified] Added first login checks
    │
    └── first_login_password_change_screen.dart
        └── [NEW] Complete password change screen


┌─────────────────────────────────────────────────────────────────────────────┐
│                         TIMELINE                                            │
└─────────────────────────────────────────────────────────────────────────────┘

T+0min    : Talyer Owner clicks "Add Mechanic"
T+1min    : Form filled and submitted
T+1min    : Database records created
T+2min    : Email sent to mechanic
T+5min    : Mechanic receives email
T+10min   : Mechanic verifies email
T+15min   : Mechanic downloads app and logs in
T+15min   : Auto-redirected to password change
T+17min   : Password changed successfully
T+17min   : Mechanic accesses dashboard
            ✅ MECHANIC FULLY ONBOARDED


┌─────────────────────────────────────────────────────────────────────────────┐
│                         ERROR HANDLING FLOW                                 │
└─────────────────────────────────────────────────────────────────────────────┘

    Try: Add Mechanic
         │
         ├─► Email exists?
         │   └─► ❌ "Email already exists"
         │
         ├─► Image upload fails?
         │   └─► ❌ "Image upload failed"
         │
         ├─► User creation fails?
         │   └─► ❌ Rollback & cleanup
         │
         ├─► Email send fails?
         │   └─► ⚠️  Log warning, continue
         │
         └─► Success
             └─► ✅ "Mechanic added!"


Legend:
═══  Section divider
───  Connection line
│    Vertical flow
▼    Flow direction
◄─   Input/Reference
🟠   Orange button/action
📧   Email related
🔐   Security/Login
✅   Success state
❌   Error state
⚠️   Warning
ℹ️   Information
🔧   Mechanic related
👤   User data
📱   Mobile/App
🎉   Completion
```
