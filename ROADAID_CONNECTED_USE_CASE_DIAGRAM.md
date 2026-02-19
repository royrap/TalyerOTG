# 🎯 ROADAID SYSTEM - CONNECTED USE CASE DIAGRAM

**Date:** October 10, 2025  
**System:** RoadAid Auto Repair Assistance Platform  
**Document Type:** Integrated Use Case Diagram with Login Flow

---

## 📊 COMPLETE INTEGRATED USE CASE DIAGRAM

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          ROADAID SYSTEM USE CASES                               │
│                     (Login-Connected Flow Diagram)                              │
└─────────────────────────────────────────────────────────────────────────────────┘


          CUSTOMER                    SYSTEM                    MECHANIC
             │                          │                          │
             │                          │                          │
             ├──[Register/Login]────────┤                          │
             │                          │                          │
             │◄─(Authentication)────────┤                          │
             │                          │                          │
             │                          │◄─────[Register/Login]────┤
             │                          │                          │
             │                          ├────(Authentication)─────►│
             │                          │                          │
             │                          │                          │
      ┌──────▼──────┐            ┌─────▼─────┐           ┌────────▼────────┐
      │   Customer  │            │  System   │           │    Mechanic     │
      │  Dashboard  │            │  Gateway  │           │   Dashboard     │
      └──────┬──────┘            └─────┬─────┘           └────────┬────────┘
             │                          │                          │
             │                          │                          │
       ┌─────▼─────────────┐            │              ┌───────────▼──────────┐
       │ Customer Actions: │            │              │  Mechanic Actions:   │
       ├───────────────────┤            │              ├──────────────────────┤
       │                   │            │              │                      │
       │ 1. Add Vehicle ───┼────────────┤              │ 1. Update Status ────┼───┐
       │                   │            │              │                      │   │
       │ 2. Request ───────┼────────────┤              │ 2. View Requests ────┼───┤
       │    Service        │            │              │                      │   │
       │    ├─ Direct ─────┼────────┐   │              │ 3. Accept Request ───┼───┤
       │    ├─ Shop ───────┼────────┤   │              │                      │   │
       │    └─ Broadcast ──┼────────┤   │              │ 4. Navigate to ──────┼───┤
       │                   │        │   │              │    Customer          │   │
       │ 3. Track ─────────┼────────┤   │              │                      │   │
       │    Progress       │        │   │              │ 5. Start Service ────┼───┤
       │                   │        │   │              │                      │   │
       │ 4. Chat with ─────┼────────┤   │              │ 6. Upload Photos ────┼───┤
       │    Mechanic       │        │   │              │                      │   │
       │                   │        │   │              │ 7. Complete Job ─────┼───┤
       │ 5. Make Payment ──┼────────┤   │              │                      │   │
       │    ├─ Cash ───────┼────────┤   │              │ 8. Scan QR Code ─────┼───┤
       │    ├─ GCash ──────┼────────┤   │              │                      │   │
       │    └─ PayMaya ────┼────────┤   │              │ 9. View Earnings ────┼───┤
       │                   │        │   │              │                      │   │
       │ 6. Rate & ────────┼────────┤   │              │ 10. Request Payout ──┼───┤
       │    Review         │        │   │              │                      │   │
       │                   │        │   │              │ 11. View Job ────────┼───┤
       │ 7. View History ──┼────────┘   │              │     History          │   │
       │                   │            │              │                      │   │
       │ 8. Manage Profile ┼────────────┤              │ 12. Chat with ───────┼───┤
       │                   │            │              │     Customer         │   │
       └───────────────────┘            │              └──────────────────────┘   │
                                        │                          │               │
                                        │                          │               │
                                        │              ┌───────────▼───────────────▼──┐
                                        │              │   Mechanic Job Process      │
                                        │              │   (Connected Activities)    │
                                        │              ├─────────────────────────────┤
                                        │              │ • Receive Notification      │
                                        │              │ • Accept/Decline Request    │
                                        │              │ • Update Real-time Location │
                                        │              │ • Document Progress         │
                                        │              │ • Complete Verification     │
                                        │              │ • Receive Payment Share     │
                                        │              └─────────────────────────────┘
                                        │
                                        │
                SHOP OWNER              │
                    │                   │
                    │                   │
                    ├─[Register/Login]──┤
                    │                   │
                    │◄(Authentication)──┤
                    │                   │
             ┌──────▼──────┐            │
             │ Shop Owner  │            │
             │  Dashboard  │            │
             └──────┬──────┘            │
                    │                   │
          ┌─────────▼────────────┐      │
          │ Shop Owner Actions:  │      │
          ├──────────────────────┤      │
          │                      │      │
          │ 1. Setup Shop ───────┼──────┤
          │                      │      │
          │ 2. Upload Docs ──────┼──────┤
          │                      │      │
          │ 3. Add Services ─────┼──────┤
          │                      │      │
          │ 4. Invite ───────────┼──────┤───┐
          │    Mechanic          │      │   │
          │                      │      │   │
          │ 5. Manage ───────────┼──────┤   │
          │    Mechanics         │      │   │
          │                      │      │   │
          │ 6. Assign Jobs ──────┼──────┤   │
          │                      │      │   │
          │ 7. Monitor ──────────┼──────┤   │
          │    Operations        │      │   │
          │                      │      │   │
          │ 8. View Stats ───────┼──────┤   │
          │                      │      │   │
          │ 9. Set Shop ─────────┼──────┤   │
          │    Status            │      │   │
          │                      │      │   │
          │ 10. View Earnings ───┼──────┘   │
          │                      │          │
          └──────────────────────┘          │
                    │                       │
                    │                       │
       ┌────────────▼───────────────────────▼─────┐
       │   Shop Management Process                │
       │   (Connected to Mechanics)               │
       ├──────────────────────────────────────────┤
       │ • Send Mechanic Invitations              │
       │ • Receive Shop-Based Requests            │
       │ • Assign Available Mechanics             │
       │ • Monitor Mechanic Performance           │
       │ • Distribute Shop Earnings               │
       │ • Manage Business Hours                  │
       └──────────────────────────────────────────┘


                         ADMIN
                           │
                           │
                           ├─[Login]───────────────┐
                           │                       │
                           │◄(Admin Auth)──────────┤
                           │                       │
                    ┌──────▼──────┐                │
                    │    Admin    │                │
                    │  Dashboard  │                │
                    └──────┬──────┘                │
                           │                       │
                  ┌────────▼─────────┐             │
                  │  Admin Actions:  │             │
                  ├──────────────────┤             │
                  │                  │             │
                  │ 1. Verify ───────┼─────────────┤
                  │    Documents     │             │
                  │                  │             │
                  │ 2. Verify ───────┼─────────────┤
                  │    Permits       │             │
                  │                  │             │
                  │ 3. Verify ───────┼─────────────┤
                  │    Cash          │             │
                  │    Payments      │             │
                  │                  │             │
                  │ 4. Resolve ──────┼─────────────┤
                  │    Disputes      │             │
                  │                  │             │
                  │ 5. Monitor ──────┼─────────────┤
                  │    Platform      │             │
                  │                  │             │
                  │ 6. Manage ───────┼─────────────┤
                  │    Settings      │             │
                  │                  │             │
                  └──────────────────┘             │
                           │                       │
              ┌────────────▼───────────────────────▼─────┐
              │   Admin Control Process                  │
              ├──────────────────────────────────────────┤
              │ • Review All User Activities             │
              │ • Approve/Reject Verifications           │
              │ • Investigate Reports                    │
              │ • Configure System Parameters            │
              │ • Generate Platform Reports              │
              └──────────────────────────────────────────┘
```

---

## 🔐 DETAILED LOGIN-CONNECTED USE CASE FLOW

### **1. CUSTOMER LOGIN → ACTIONS FLOW**

```
┌─────────────────────────────────────────────────────────────────┐
│                    CUSTOMER JOURNEY                             │
└─────────────────────────────────────────────────────────────────┘

[START]
   │
   ├─→ UC-C01: Customer Login/Register
   │   ├─ Email/Password
   │   ├─ Google Sign-In
   │   └─ Phone Number (OTP)
   │
   ├─→ Authentication Success
   │   └─ Redirect to Customer Dashboard
   │
   ├─→ UC-C02: Add Vehicle (First Time)
   │   └─ Database: INSERT INTO vehicles
   │
   ├─→ UC-C03: Create Service Request
   │   │
   │   ├──[Option A: Direct Mechanic]─────────────┐
   │   │   └─ UC-C03: Direct Mechanic Request     │
   │   │       ├─ Browse mechanics                 │
   │   │       ├─ Select specific mechanic         │
   │   │       ├─ Fill request form                │
   │   │       └─ Send direct notification         │
   │   │           │                                │
   │   │           └──────────────────────────┐    │
   │   │                                      │    │
   │   ├──[Option B: Shop-Based]──────────────│────┤
   │   │   └─ UC-C03b: Shop-Based Request     │    │
   │   │       ├─ Browse nearby shops          │    │
   │   │       ├─ Select shop                  │    │
   │   │       ├─ Fill request form            │    │
   │   │       └─ Send to shop owner           │    │
   │   │           │                            │    │
   │   │           └────────────────────────┐  │    │
   │   │                                    │  │    │
   │   └──[Option C: Broadcast]─────────────│──│────┤
   │       └─ UC-C04: Broadcast Request      │  │    │
   │           ├─ Fill request form          │  │    │
   │           ├─ Set broadcast radius       │  │    │
   │           └─ Send to all nearby         │  │    │
   │               │                         │  │    │
   │               └──────────────────────┐  │  │    │
   │                                      ▼  ▼  ▼    │
   ├─→ UC-C05: Track Progress             [SYSTEM]  │
   │   ├─ View mechanic location          Processes │
   │   ├─ See real-time updates           Request   │
   │   ├─ View progress photos                      │
   │   └─ Check ETA                                 │
   │                                                 │
   ├─→ UC-C06: Chat with Mechanic                   │
   │   └─ Real-time messaging                       │
   │                                                 │
   ├─→ Service Completed                            │
   │   └─ Scan QR Code Verification                 │
   │                                                 │
   ├─→ UC-C07: Make Payment                         │
   │   │                                            │
   │   ├──[Payment Method: Cash]────────────────┐   │
   │   │   ├─ Pay mechanic directly             │   │
   │   │   ├─ Take photo proof                  │   │
   │   │   └─ Upload verification               │   │
   │   │                                        │   │
   │   ├──[Payment Method: GCash]───────────────┤   │
   │   │   ├─ Redirect to PayMongo              │   │
   │   │   ├─ Complete GCash payment            │   │
   │   │   └─ Webhook confirmation              │   │
   │   │                                        │   │
   │   └──[Payment Method: PayMaya]─────────────┤   │
   │       ├─ Redirect to PayMongo              │   │
   │       ├─ Complete PayMaya payment          │   │
   │       └─ Webhook confirmation              │   │
   │                                            ▼   │
   ├─→ UC-C08: Rate & Review                [PAYMENT]
   │   ├─ Rate 1-5 stars                    COMPLETED
   │   ├─ Write review                           │
   │   ├─ Upload photos                          │
   │   └─ Submit feedback                        │
   │                                             │
   ├─→ UC-C09: View Service History              │
   │   ├─ Browse past services                   │
   │   ├─ View receipts                          │
   │   └─ Download invoices                      │
   │                                             │
   └─→ [Repeat for next service need]           │
                                                 │
[END] ───────────────────────────────────────────┘
```

---

### **2. MECHANIC LOGIN → ACTIONS FLOW**

```
┌─────────────────────────────────────────────────────────────────┐
│                    MECHANIC JOURNEY                             │
└─────────────────────────────────────────────────────────────────┘

[START]
   │
   ├─→ UC-M01: Mechanic Login/Register
   │   │
   │   ├──[Path A: Independent Registration]──────┐
   │   │   ├─ Email/Password signup               │
   │   │   ├─ Complete profile                    │
   │   │   ├─ Upload documents                    │
   │   │   └─ Wait for admin verification         │
   │   │                                           │
   │   └──[Path B: Shop Invitation]───────────────┤
   │       ├─ Receive invitation email            │
   │       ├─ Click invitation link               │
   │       ├─ Auto-create account                 │
   │       └─ Assigned to shop                    │
   │                                               │
   ├─→ Authentication Success                     │
   │   └─ Redirect to Mechanic Dashboard          │
   │                                               │
   ├─→ UC-M02: Set Availability Status            │
   │   ├─ Available (Green) ─┐                    │
   │   ├─ Busy (Yellow) ──────┤                   │
   │   └─ Offline (Gray) ─────┴──► Update Status  │
   │                                               │
   ├─→ UC-M03: Receive Service Requests           │
   │   │                                           │
   │   ├──[Type 1: Broadcast Request]─────────────┐
   │   │   ├─ Push notification received          │
   │   │   ├─ View request details                │
   │   │   ├─ Check distance & earnings           │
   │   │   └─ Decision:                           │
   │   │       ├─ Accept (First come, first served)
   │   │       └─ Decline (Back to available)     │
   │   │                                           │
   │   ├──[Type 2: Direct Request]────────────────┤
   │   │   ├─ Direct notification from customer   │
   │   │   ├─ View customer profile               │
   │   │   └─ Decision:                           │
   │   │       ├─ Accept (Job assigned)           │
   │   │       └─ Decline (Customer notified)     │
   │   │                                           │
   │   └──[Type 3: Shop Assignment]───────────────┤
   │       ├─ Shop owner assigns job              │
   │       ├─ Notification received               │
   │       └─ Accept assigned job                 │
   │                                               │
   ├─→ UC-M04: Navigate to Customer               │
   │   ├─ View customer location                  │
   │   ├─ Start navigation                        │
   │   ├─ Share real-time location                │
   │   └─ Click "Arrived"                         │
   │                                               │
   ├─→ UC-M05: Perform Service                    │
   │   ├─ Click "Start Service"                   │
   │   ├─ Take inspection photos                  │
   │   ├─ Upload progress photos:                 │
   │   │   ├─ Arrival                             │
   │   │   ├─ Inspection                          │
   │   │   ├─ Diagnosis                           │
   │   │   ├─ Work in Progress                    │
   │   │   └─ Completion                          │
   │   └─ Customer views real-time updates        │
   │                                               │
   ├─→ UC-M06: Complete Service                   │
   │   ├─ Click "Mark as Complete"                │
   │   ├─ Enter final cost (if changed)           │
   │   ├─ Add completion notes                    │
   │   └─ Generate completion QR code             │
   │                                               │
   ├─→ UC-M07: QR Code Verification               │
   │   ├─ Open QR scanner                         │
   │   ├─ Scan customer's QR code                 │
   │   ├─ System validates                        │
   │   └─ Job verified & invoice generated        │
   │                                               │
   ├─→ Payment Process (Automatic)                │
   │   ├─ Customer completes payment              │
   │   ├─ System distributes earnings:            │
   │   │   ├─ Platform fee (7%)                   │
   │   │   ├─ Shop share (if applicable)          │
   │   │   └─ Mechanic share (70-93%)             │
   │   └─ Earnings added to account               │
   │                                               │
   ├─→ UC-M08: View Earnings                      │
   │   ├─ Total earnings                          │
   │   ├─ This month                              │
   │   ├─ Pending/Released                        │
   │   └─ Earnings breakdown per job              │
   │                                               │
   ├─→ UC-M09: Request Payout                     │
   │   ├─ Check available balance                 │
   │   ├─ Enter amount (min ₱500)                 │
   │   ├─ Provide bank/GCash details              │
   │   └─ Submit payout request                   │
   │                                               │
   ├─→ UC-M10: View Job History                   │
   │   ├─ All completed jobs                      │
   │   ├─ Customer ratings                        │
   │   ├─ Earnings per job                        │
   │   └─ Download receipts                       │
   │                                               │
   ├─→ UC-M11: Chat with Customer                 │
   │   └─ Real-time messaging during service      │
   │                                               │
   └─→ [Return to Available & Wait for Next Job]  │
                                                   │
[END] ─────────────────────────────────────────────┘
```

---

### **3. SHOP OWNER (TALYER OWNER) LOGIN → ACTIONS FLOW**

```
┌─────────────────────────────────────────────────────────────────┐
│                 SHOP OWNER JOURNEY                              │
└─────────────────────────────────────────────────────────────────┘

[START]
   │
   ├─→ UC-S01: Shop Owner Login/Register
   │   ├─ Email/Password signup
   │   └─ Account type: Talyer Owner
   │
   ├─→ Authentication Success
   │   └─ Redirect to Shop Owner Dashboard
   │
   ├─→ UC-S02: Setup Shop Profile
   │   ├─ Enter shop details:
   │   │   ├─ Shop name
   │   │   ├─ Address & GPS location
   │   │   ├─ Contact information
   │   │   └─ Shop description
   │   ├─ Upload shop photos
   │   └─ Set business hours (JSON)
   │
   ├─→ UC-S03: Upload Business Documents
   │   ├─ Business permit
   │   ├─ Mayor's permit
   │   ├─ DTI registration
   │   ├─ Owner's valid ID
   │   └─ Send for admin verification
   │       └─ Wait for approval ──→ [Admin verifies]
   │
   ├─→ Shop Verified! ✓
   │
   ├─→ UC-S04: Add Shop Services
   │   ├─ Select from service categories:
   │   │   ├─ Tire Repair
   │   │   ├─ Oil Change
   │   │   ├─ Brake Service
   │   │   └─ Engine Diagnostics
   │   ├─ Set custom pricing
   │   ├─ Set estimated duration
   │   └─ Enable/disable services
   │
   ├─→ UC-S05: Mechanic Management
   │   │
   │   ├──[Action 1: Invite New Mechanic]────────┐
   │   │   ├─ Enter mechanic details             │
   │   │   ├─ Generate invitation                │
   │   │   ├─ Send email invitation              │
   │   │   └─ Mechanic accepts ──→ Auto-assigned │
   │   │                           to shop        │
   │   ├──[Action 2: Manage Mechanics]───────────┤
   │   │   ├─ View all mechanics                 │
   │   │   ├─ See performance stats              │
   │   │   ├─ Set hourly rates                   │
   │   │   ├─ Activate/Deactivate                │
   │   │   └─ Assign roles                       │
   │   │                                          │
   │   └──[Action 3: View Performance]───────────┤
   │       ├─ Jobs completed per mechanic        │
   │       ├─ Customer ratings                   │
   │       ├─ Earnings generated                 │
   │       └─ Attendance/punctuality             │
   │                                              │
   ├─→ UC-S06: Receive Service Requests          │
   │   ├─ Shop-based requests arrive             │
   │   ├─ Notification sent to owner             │
   │   └─ Request details displayed:             │
   │       ├─ Customer info                      │
   │       ├─ Service type                       │
   │       ├─ Location                           │
   │       └─ Urgency level                      │
   │                                              │
   ├─→ UC-S07: Assign Mechanic to Request        │
   │   ├─ View available mechanics               │
   │   ├─ Check mechanic specializations         │
   │   ├─ Check mechanic distance                │
   │   ├─ Select best fit mechanic               │
   │   ├─ Add assignment notes                   │
   │   └─ Send to mechanic                       │
   │       │                                      │
   │       └──[Mechanic receives notification]   │
   │           ├─ Mechanic accepts               │
   │           └─ Job proceeds ──→ [Mechanic Flow]
   │                                              │
   ├─→ UC-S08: Monitor Shop Operations           │
   │   ├─ Real-time dashboard:                   │
   │   │   ├─ Active jobs count                  │
   │   │   ├─ Mechanics status                   │
   │   │   ├─ Today's revenue                    │
   │   │   └─ Pending requests                   │
   │   ├─ View active jobs on map                │
   │   └─ Track mechanic locations               │
   │                                              │
   ├─→ UC-S09: Set Shop Status                   │
   │   ├─ Open (accepting requests)              │
   │   ├─ Closed (not accepting)                 │
   │   ├─ Busy (all mechanics occupied)          │
   │   └─ Auto-toggle based on business hours    │
   │       ├─ Auto-open at 8:00 AM               │
   │       └─ Auto-close at 6:00 PM              │
   │                                              │
   ├─→ UC-S10: View Shop Statistics              │
   │   ├─ Daily/Weekly/Monthly reports:          │
   │   │   ├─ Total jobs                         │
   │   │   ├─ Completed vs Cancelled             │
   │   │   ├─ Revenue generated                  │
   │   │   ├─ Average rating                     │
   │   │   └─ Customer satisfaction              │
   │   ├─ Mechanic performance comparison        │
   │   ├─ Service breakdown chart                │
   │   └─ Peak hours analysis                    │
   │                                              │
   ├─→ UC-S11: View Shop Earnings                │
   │   ├─ Total shop earnings                    │
   │   ├─ Earnings breakdown:                    │
   │   │   ├─ From each job (23-33%)             │
   │   │   ├─ Platform fee deducted (7%)         │
   │   │   └─ Mechanic share paid (60-70%)       │
   │   ├─ Pending payouts                        │
   │   └─ Released earnings                      │
   │                                              │
   ├─→ UC-S12: Respond to Reviews                │
   │   ├─ View shop reviews                      │
   │   ├─ Read customer feedback                 │
   │   ├─ Write response (optional)              │
   │   └─ Address negative reviews               │
   │                                              │
   └─→ [Continue monitoring & managing]          │
                                                  │
[END] ────────────────────────────────────────────┘
```

---

### **4. ADMIN LOGIN → ACTIONS FLOW**

```
┌─────────────────────────────────────────────────────────────────┐
│                     ADMIN JOURNEY                               │
└─────────────────────────────────────────────────────────────────┘

[START]
   │
   ├─→ UC-A01: Admin Login
   │   ├─ Email/Password (Admin credentials)
   │   └─ Two-factor authentication
   │
   ├─→ Authentication Success
   │   └─ Redirect to Admin Dashboard
   │
   ├─→ UC-A02: Verify Mechanic Documents
   │   ├─ View pending mechanic applications
   │   ├─ Review uploaded documents:
   │   │   ├─ Driver's license
   │   │   ├─ Mechanic license
   │   │   └─ Valid ID
   │   ├─ Verify authenticity
   │   └─ Decision:
   │       ├─ Approve → Mechanic activated
   │       └─ Reject → Send reason to applicant
   │
   ├─→ UC-A03: Verify Shop Business Permits
   │   ├─ View pending shop applications
   │   ├─ Review business documents:
   │   │   ├─ Business permit
   │   │   ├─ Mayor's permit
   │   │   ├─ DTI registration
   │   │   └─ Owner's ID
   │   ├─ Cross-check with LGU records
   │   └─ Decision:
   │       ├─ Approve → Shop activated
   │       └─ Reject → Send reason to owner
   │
   ├─→ UC-A04: Verify Cash Payments
   │   ├─ View pending cash payment verifications
   │   ├─ Review photo proofs
   │   ├─ Check amounts match invoice
   │   ├─ Verify both parties confirmed
   │   └─ Decision:
   │       ├─ Approve → Release earnings
   │       ├─ Reject → Request new proof
   │       └─ Flag suspicious → Investigate
   │
   ├─→ UC-A05: Resolve Disputes
   │   ├─ View reported disputes
   │   ├─ Review evidence:
   │   │   ├─ Request timeline
   │   │   ├─ Chat messages
   │   │   ├─ Photos uploaded
   │   │   └─ Payment records
   │   ├─ Contact involved parties
   │   ├─ Investigate claims
   │   └─ Make resolution:
   │       ├─ Full refund to customer
   │       ├─ Partial refund
   │       ├─ No refund (favor mechanic)
   │       ├─ Issue warning
   │       ├─ Suspend account
   │       └─ Ban user
   │
   ├─→ UC-A06: Monitor Platform Statistics
   │   ├─ View real-time metrics:
   │   │   ├─ Total users (15,432)
   │   │   ├─ Active requests (145)
   │   │   ├─ Today's revenue (₱45,670)
   │   │   ├─ Completed jobs (7,234)
   │   │   └─ Platform earnings (7%)
   │   ├─ Generate reports:
   │   │   ├─ Daily/Weekly/Monthly
   │   │   ├─ User growth trends
   │   │   ├─ Revenue analysis
   │   │   └─ Service breakdown
   │   └─ Export data (CSV/PDF)
   │
   ├─→ UC-A07: Manage System Settings
   │   ├─ Financial settings:
   │   │   ├─ Platform fee % (7%)
   │   │   ├─ Minimum service fee (₱200)
   │   │   ├─ Emergency multiplier (1.5x)
   │   │   └─ Minimum payout (₱500)
   │   ├─ Service settings:
   │   │   ├─ Broadcast radius (15km)
   │   │   ├─ Request timeout (15 min)
   │   │   └─ QR code expiry (24 hrs)
   │   └─ Quality settings:
   │       ├─ Min mechanic rating (3.0)
   │       └─ Auto-suspend threshold (2.5)
   │
   ├─→ UC-A08: Process Payout Requests
   │   ├─ View pending payout requests
   │   ├─ Verify mechanic eligibility
   │   ├─ Check available balance
   │   ├─ Process bank transfer/GCash
   │   └─ Mark as released
   │
   ├─→ UC-A09: View Audit Logs
   │   ├─ All system activities
   │   ├─ User actions logged
   │   ├─ Admin actions logged
   │   ├─ Payment transactions
   │   └─ Security events
   │
   └─→ [Continue platform management]
                                                  │
[END] ────────────────────────────────────────────┘
```

---

## 🔄 INTERCONNECTED SYSTEM FLOW

```
┌──────────────────────────────────────────────────────────────────────────┐
│              COMPLETE SYSTEM INTERACTION FLOW                            │
└──────────────────────────────────────────────────────────────────────────┘


    CUSTOMER                  SYSTEM                   MECHANIC
       │                        │                         │
       ├──[1. Login]────────────┤                         │
       │                        │                         │
       ├──[2. Create Request]───┤                         │
       │                        │                         │
       │                        ├─[3. Broadcast]──────────┤
       │                        │                         │
       │                        │                         ├─[4. Receive]
       │                        │                         │
       │                        │                         ├─[5. Accept]
       │                        │                         │
       │                        ├─[6. Assign]─────────────┤
       │                        │                         │
       │◄─[7. Notification]─────┤                         │
       │                        │                         │
       │                        │                         ├─[8. Navigate]
       │                        │                         │
       ├──[9. Track Location]───┼─────────────────────────┤
       │                        │                         │
       │                        │                         ├─[10. Arrive]
       │                        │                         │
       │◄─[11. Update]──────────┤                         │
       │                        │                         │
       │                        │                         ├─[12. Service]
       │                        │                         │
       │                        │                         ├─[13. Upload Photos]
       │                        │                         │
       │◄─[14. Progress]────────┼─────────────────────────┤
       │                        │                         │
       ├──[15. Chat]────────────┼─────────────────────────┤
       │                        │                         │
       │                        │                         ├─[16. Complete]
       │                        │                         │
       │◄─[17. Generate QR]─────┤                         │
       │                        │                         │
       ├──[18. Show QR]─────────┼─────────────────────────┤
       │                        │                         │
       │                        │                         ├─[19. Scan QR]
       │                        │                         │
       │                        ├─[20. Verify]────────────┤
       │                        │                         │
       │◄─[21. Generate Invoice]┤                         │
       │                        │                         │
       ├──[22. Select Payment]──┤                         │
       │    Method              │                         │
       │                        │                         │
       ├──[23. Pay]─────────────┤                         │
       │                        │                         │
       │                        ├─[24. Process]───────────┤
       │                        │    Payment              │
       │                        │                         │
       │                        ├─[25. Distribute]────────┤
       │                        │    Earnings             │
       │                        │                         │
       │                        │                         ├─[26. Receive]
       │                        │                         │   Payment
       │                        │                         │
       │◄─[27. Request Review]──┤                         │
       │                        │                         │
       ├──[28. Submit Rating]───┤                         │
       │                        │                         │
       │                        ├─[29. Update Rating]─────┤
       │                        │                         │
       │                        │                         ├─[30. Job Complete]
       │                        │                         │
       └──[TRANSACTION END]─────┴─────────────────────────┘


    SHOP OWNER                                         ADMIN
       │                                                 │
       ├──[1. Login]────────────┐                       │
       │                        │                       │
       ├──[2. Invite Mechanic]──┤                       │
       │                        │                       │
       │                        ├──[Send Email]─────────┤
       │                        │                       │
       │                        │            ┌──────────┤
       │                        │            │          │
       │◄─[3. Mechanic Joined]──┤            │          │
       │                        │            │          │
       ├──[4. Receive Request]──┤            │          │
       │                        │            │          │
       ├──[5. View Mechanics]───┤            │          │
       │                        │            │          │
       ├──[6. Assign Job]───────┼────[To Mechanic]      │
       │                        │            │          │
       ├──[7. Monitor Progress]─┤            │          │
       │                        │            │          │
       ├──[8. View Earnings]────┤            │          │
       │                        │            │          │
       │                        │            │          ├─[Verify Docs]
       │                        │            │          │
       │◄─[9. Shop Verified]────┤◄───────────┼──────────┤
       │                        │            │          │
       ├──[10. Manage Services]─┤            │          │
       │                        │            │          │
       ├──[11. Set Shop Status]─┤            │          ├─[Monitor Platform]
       │                        │            │          │
       └──[Continue Operations]─┴────────────┴──────────┘
```

---

## 📝 USE CASE SUMMARY TABLE

| User Type | Login Use Case | Total Connected Actions |
|-----------|----------------|-------------------------|
| **Customer** | UC-C01: Login/Register | 11 actions |
| **Mechanic** | UC-M01: Login/Register | 12 actions |
| **Shop Owner** | UC-S01: Login/Register | 13 actions |
| **Admin** | UC-A01: Admin Login | 9 actions |

---

## ✅ KEY INTEGRATION POINTS

### **Customer ↔ Mechanic**
- Request creation → Broadcast notification
- Real-time location tracking
- Chat messaging
- QR code verification
- Rating & review

### **Shop Owner ↔ Mechanic**
- Invitation system
- Job assignment
- Performance monitoring
- Earnings distribution

### **Admin ↔ All Users**
- Document verification
- Payment verification
- Dispute resolution
- Platform monitoring

### **System ↔ All Users**
- Authentication & authorization
- Notification delivery
- Payment processing
- Data synchronization

---

**Document Complete!** ✅  
**Last Updated:** October 10, 2025
