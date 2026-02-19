# 🚗 ROADAID SYSTEM FLOW ANALYSIS

**Date:** October 10, 2025  
**System:** RoadAid Auto Repair Assistance Platform  
**Analysis Type:** Complete End-to-End System Flow

---

## 📋 TABLE OF CONTENTS

1. [System Overview](#system-overview)
2. [User Types & Roles](#user-types--roles)
3. [Main System Flows](#main-system-flows)
4. [Detailed Flow Breakdown](#detailed-flow-breakdown)
5. [Database Flow](#database-flow)
6. [Payment Flow](#payment-flow)
7. [Notification Flow](#notification-flow)

---

## 🎯 SYSTEM OVERVIEW

Ang RoadAid ay isang **on-demand auto repair assistance platform** na nag-connect ng:
- **Customers** (mga motorista na kailangan ng tulong)
- **Mechanics** (mga mekaniko na nag-aalok ng serbisyo)
- **Shop Owners (Talyer Owners)** (mga may-ari ng auto repair shops)

---

## 👥 USER TYPES & ROLES

### 1. **CUSTOMER (Motorista)**
- Nag-request ng service
- Nag-track ng mechanic location
- Nag-bayad ng service
- Nag-rate at nag-review

### 2. **MECHANIC (Mekaniko)**
- Tumatanggap ng service requests
- Nag-provide ng service
- Nag-upload ng progress photos
- Tumatanggap ng payment

### 3. **SHOP OWNER (Talyer Owner)**
- Nag-manage ng shop
- Nag-hire ng mechanics
- Nag-set ng services offered
- Nag-monitor ng earnings

### 4. **ADMIN (Super Admin)**
- Nag-verify ng documents
- Nag-manage ng platform
- Nag-monitor ng transactions
- Nag-handle ng disputes

---

## 🔄 MAIN SYSTEM FLOWS

### **FLOW 1: CUSTOMER REQUEST FLOW** 🚨

```
┌─────────────────────────────────────────────────────────────┐
│                    CUSTOMER SIDE                             │
└─────────────────────────────────────────────────────────────┘

1. Customer Login/Register
   ↓
2. Customer nakaranas ng car problem
   ↓
3. Customer opens RoadAid app
   ↓
4. Customer pumipili ng service type:
   ├─→ Direct Mechanic (pumipili ng specific mechanic)
   ├─→ Shop-Based (pumipili ng specific shop)
   └─→ Broadcast Request (padala sa lahat ng nearby)
   ↓
5. Customer fills up request form:
   - Service type (Tire Repair, Battery, Oil Change, etc.)
   - Vehicle details (from saved vehicles)
   - Location (auto-detected o manual input)
   - Problem description
   - Photos (optional)
   - Priority level
   ↓
6. System calculates service fee based on distance
   ↓
7. Customer confirms request
   ↓
8. Request saved sa database (service_requests table)
   ↓
9. System routes request based on type:

   ┌──────────────────────────────────────────────────┐
   │  A. DIRECT MECHANIC REQUEST                      │
   └──────────────────────────────────────────────────┘
   - Notification sent DIRECTLY sa piniling mechanic
   - Mechanic may 15 minutes to accept/decline
   - If accepted → Go to Step 10
   - If declined/timeout → Customer notified, choose again
   
   ┌──────────────────────────────────────────────────┐
   │  B. SHOP-BASED REQUEST                           │
   └──────────────────────────────────────────────────┘
   - Notification sent sa shop owner
   - Shop owner assigns available mechanic
   - Assigned mechanic gets notification
   - If accepted → Go to Step 10
   - If declined → Shop owner assigns another
   
   ┌──────────────────────────────────────────────────┐
   │  C. BROADCAST REQUEST                            │
   └──────────────────────────────────────────────────┘
   - System finds all mechanics within radius (15km default)
   - Query: get_nearby_mechanics() function
   - Push notification sent sa lahat ng qualified mechanics
   - Record saved sa request_broadcasts table
   - FIRST mechanic to accept wins the job
   - If no response after 15 mins → expand radius o notify customer

   ↓
10. Mechanic ACCEPTS the request
    - service_requests.status → 'accepted'
    - service_requests.mechanic_id → assigned
    - service_requests.accepted_at → timestamp
    - Status log entry created
    ↓
11. Customer receives notification:
    - "Your request has been accepted by [Mechanic Name]"
    - Mechanic details shown (name, rating, photo)
    - Real-time location tracking enabled
    ↓
12. Customer can message mechanic (messages table)
    ↓
13. Mechanic starts traveling to location
    - mechanic_availability_status.current_status → 'busy'
    - Real-time location updates
    ↓
14. Mechanic arrives at location
    - Mechanic clicks "Arrived" button
    - Progress photo uploaded (arrival phase)
    - progress_photos table entry created
    - Customer notified
    ↓
15. Service begins
    - service_requests.status → 'in_progress'
    - service_requests.started_at → timestamp
    - service_phase_tracking table updated
    ↓
16. During service:
    - Mechanic uploads progress photos:
      * Inspection phase
      * Diagnosis phase
      * Work in progress
      * Before/After photos
    - Each photo saved sa progress_photos table
    - Customer can view real-time updates
    ↓
17. Service completed
    - Mechanic marks as complete
    - service_requests.status → 'completed'
    - service_requests.completed_at → timestamp
    ↓
18. QR CODE VERIFICATION SYSTEM
    - System generates unique completion code
    - Saved sa job_completion_codes table
    - QR code displayed to customer
    - Mechanic scans QR code to verify completion
    - job_completion_codes.is_scanned → true
    - job_completion_codes.scanned_at → timestamp
    ↓
19. INVOICE GENERATION (automatic)
    - System creates invoice (invoices table)
    - Invoice number: INV-YYYYMMDD-XXXX
    - Calculates:
      * Subtotal (actual service cost)
      * Platform fee (7% default)
      * Service fee (distance-based)
      * Total amount
      * Mechanic share
      * Shop share (if applicable)
    - Invoice status → 'generated'
    ↓
20. PAYMENT PROCESS
    - Customer chooses payment method:
      ├─→ Cash (requires photo verification)
      ├─→ GCash (PayMongo integration)
      ├─→ PayMaya (PayMongo integration)
      └─→ Card (PayMongo integration)
    
    ┌──────────────────────────────────────────────────┐
    │  CASH PAYMENT FLOW                               │
    └──────────────────────────────────────────────────┘
    a. Customer pays cash to mechanic
    b. Mechanic/Customer takes photo of cash
    c. Photo uploaded to cash_payment_verifications
    d. Status: 'pending'
    e. Admin verifies photo
    f. Status: 'verified'
    g. Payment marked as completed
    
    ┌──────────────────────────────────────────────────┐
    │  DIGITAL PAYMENT FLOW (GCash/PayMaya/Card)      │
    └──────────────────────────────────────────────────┘
    a. Customer clicks pay
    b. System creates PayMongo payment intent
    c. Customer redirected to payment gateway
    d. Customer completes payment
    e. PayMongo sends webhook
    f. System updates payment status
    g. Payment marked as completed
    
    ↓
21. Payment completed
    - payments.payment_status → 'completed'
    - invoices.paid_at → timestamp
    - service_requests.payment_status → 'paid'
    ↓
22. EARNINGS DISTRIBUTION
    - Entry created sa earnings table
    - Mechanic earnings calculated
    - Shop earnings calculated (if applicable)
    - Platform fee deducted
    - earnings.status → 'approved'
    ↓
23. JOB HISTORY RECORDS
    - mechanic_job_history entry created
    - customer_job_history entry created
    - Both tables updated with:
      * Job details
      * Earnings/Payment
      * Completion timestamp
    ↓
24. REVIEW & RATING
    - Customer receives prompt to rate
    - Customer rates 1-5 stars
    - Customer writes review (optional)
    - Ratings for:
      * Overall rating
      * Service quality
      * Professionalism
      * Timeliness
      * Value for money
    - Review saved sa reviews table
    ↓
25. RATING AGGREGATION
    - Mechanic's total_reviews + 1
    - Average rating recalculated
    - mechanics.rating updated
    - mechanics.total_jobs + 1
    - If shop-based, shop.rating also updated
    ↓
26. Request complete! ✅
```

---

### **FLOW 2: MECHANIC REGISTRATION & VERIFICATION FLOW** 👨‍🔧

```
┌─────────────────────────────────────────────────────────────┐
│              MECHANIC ONBOARDING PROCESS                     │
└─────────────────────────────────────────────────────────────┘

1. Mechanic downloads app
   ↓
2. Two registration paths:
   
   ┌──────────────────────────────────────────────────┐
   │  PATH A: INDEPENDENT MECHANIC                    │
   └──────────────────────────────────────────────────┘
   a. Mechanic registers account
   b. User created sa auth.users
   c. Profile created sa user_profiles
      - user_type: 'mechanic'
   d. Mechanic profile created sa mechanics table
      - is_independent: true
      - shop_id: NULL
   
   ┌──────────────────────────────────────────────────┐
   │  PATH B: SHOP-BASED MECHANIC (via invitation)   │
   └──────────────────────────────────────────────────┘
   a. Shop owner sends invitation
   b. Invitation saved sa mechanic_invitations
   c. Email sent with invitation link & temp password
   d. Mechanic clicks link
   e. Account auto-created
   f. Profile created with shop_id assigned
   g. Entry sa shop_mechanics table
   
   ↓
3. Document upload (both paths)
   - Driver's license
   - Mechanic license (if applicable)
   - Valid ID
   - Documents saved sa document_verifications table
   - verification_status: 'pending'
   ↓
4. Profile completion
   - Specializations (array):
     * Tire specialist
     * Engine expert
     * Electrical
     * Transmission
     * etc.
   - Years of experience
   - Service radius (default 15km)
   - Profile photo
   ↓
5. Admin verification
   - Admin reviews documents
   - Admin checks credentials
   - Decision:
     ├─→ APPROVED: is_verified: true
     └─→ REJECTED: rejection_reason provided
   ↓
6. If approved:
   - mechanics.is_verified → true
   - Mechanic can now receive requests
   - mechanic_availability_status created
   - Status: 'available'
   ↓
7. Mechanic ready to work! ✅
```

---

### **FLOW 3: SHOP OWNER (TALYER OWNER) FLOW** 🏪

```
┌─────────────────────────────────────────────────────────────┐
│                  SHOP OWNER OPERATIONS                       │
└─────────────────────────────────────────────────────────────┘

1. Shop owner registers
   ↓
2. Account creation
   - auth.users entry
   - user_profiles entry (user_type: 'talyer_owner')
   ↓
3. Shop registration
   - Shop details:
     * Shop name
     * Address
     * Coordinates (lat/lng)
     * Contact info
     * Business hours (JSONB):
       {
         "monday": {"open": "08:00", "close": "18:00"},
         "tuesday": {"open": "08:00", "close": "18:00"},
         ...
       }
   - Entry sa shops table
   - is_verified: false (pending)
   ↓
4. Document upload
   - Business permit
   - Mayor's permit
   - DTI registration
   - Valid IDs
   - Saved sa business_permits table
   ↓
5. Admin verification
   - Admin reviews business documents
   - Verifies legitimacy
   - Decision:
     ├─→ APPROVED: shops.is_verified → true
     └─→ REJECTED: rejection_reason provided
   ↓
6. Shop setup
   - Add services offered (shop_services table):
     * Link to service_categories
     * Set custom pricing
     * Set availability
   - Configure business hours
   - Upload shop photos
   ↓
7. Mechanic management - Two options:
   
   ┌──────────────────────────────────────────────────┐
   │  OPTION A: INVITE MECHANICS                      │
   └──────────────────────────────────────────────────┘
   a. Shop owner clicks "Invite Mechanic"
   b. Enters mechanic details:
      - Email
      - First name
      - Last name
   c. System generates:
      - Temporary password
      - Unique invitation token
   d. Entry sa mechanic_invitations table
   e. Email sent to mechanic
   f. Mechanic accepts invitation
   g. Account created automatically
   h. Entry sa shop_mechanics table
   i. Mechanic assigned to shop
   
   ┌──────────────────────────────────────────────────┐
   │  OPTION B: EXISTING MECHANIC JOINS               │
   └──────────────────────────────────────────────────┘
   a. Shop owner sends request
   b. Existing mechanic accepts
   c. shop_mechanics entry created
   d. Mechanic can work for multiple shops
   
   ↓
8. Daily operations
   
   ┌──────────────────────────────────────────────────┐
   │  RECEIVING REQUESTS                              │
   └──────────────────────────────────────────────────┘
   - Shop receives shop-based requests
   - Notification sa shop_notifications table
   - Shop owner views available mechanics
   - Assigns mechanic to request
   - Mechanic notified
   
   ┌──────────────────────────────────────────────────┐
   │  SHOP STATUS MANAGEMENT                          │
   └──────────────────────────────────────────────────┘
   - Shop owner sets status:
     * 'open' - accepting requests
     * 'closed' - not accepting
     * 'busy' - all mechanics occupied
   - shops.current_status updated
   - If closed, hidden from customer searches
   - Business hours auto-toggle status
   
   ┌──────────────────────────────────────────────────┐
   │  MONITORING & ANALYTICS                          │
   └──────────────────────────────────────────────────┘
   - View v_shop_statistics view:
     * Total mechanics
     * Completed jobs
     * Active jobs
     * Total earnings
     * Average rating
   - Monitor mechanic performance
   - Track shop earnings
   
   ↓
9. Earnings & payouts
   - Shop receives % from completed jobs
   - Breakdown:
     * 100% service cost
     * - Platform fee (7%)
     * - Mechanic share (60-80%)
     * = Shop share (13-33%)
   - Tracked sa earnings table
   - invoices.talyer_net_amount
   ↓
10. Shop operating successfully! ✅
```

---

### **FLOW 4: BROADCAST REQUEST SYSTEM** 📡

```
┌─────────────────────────────────────────────────────────────┐
│             BROADCAST REQUEST MECHANISM                      │
└─────────────────────────────────────────────────────────────┘

1. Customer creates broadcast request
   - request_type: 'broadcast'
   - is_broadcast_request: true
   - broadcast_radius_km: 15 (default)
   ↓
2. System searches nearby providers
   
   ┌──────────────────────────────────────────────────┐
   │  SEARCH ALGORITHM                                │
   └──────────────────────────────────────────────────┘
   Query: get_nearby_mechanics(lat, lng, radius)
   
   Filters:
   ✓ mechanics.is_available = true
   ✓ mechanics.is_verified = true
   ✓ mechanic_availability_status.current_status = 'available'
   ✓ Distance ≤ broadcast_radius_km
   ✓ Mechanic specialization matches service type
   
   Also searches shops:
   Query: get_nearby_shops(lat, lng, radius)
   
   Filters:
   ✓ shops.is_active = true
   ✓ shops.is_verified = true
   ✓ shops.current_status = 'open'
   ✓ Distance ≤ broadcast_radius_km
   ✓ Shop offers requested service
   
   ↓
3. For each qualified provider:
   - Create entry sa request_broadcasts table:
     * service_request_id
     * provider_id (mechanic or shop)
     * provider_type ('mechanic' or 'shop')
     * distance_km (calculated)
     * response_status: 'pending'
     * notification_sent_at: NOW()
   ↓
4. Send push notifications
   - Use FCM (Firebase Cloud Messaging)
   - Get fcm_token from user_profiles
   - Notification payload:
     {
       "title": "New Service Request Nearby",
       "body": "Tire Repair - 2.5km away",
       "data": {
         "request_id": "uuid",
         "distance": "2.5",
         "service_type": "Tire Repair",
         "customer_location": "lat,lng"
       }
     }
   - Update request_broadcasts.mechanics_notified
   ↓
5. Mechanics receive notification
   - Notification appears in app
   - Shows:
     * Service type
     * Distance
     * Customer rating
     * Estimated payment
     * Map preview
   ↓
6. Mechanic can:
   - View details
   - Accept request
   - Decline request
   ↓
7. FIRST COME, FIRST SERVED
   
   ┌──────────────────────────────────────────────────┐
   │  IF MECHANIC ACCEPTS                             │
   └──────────────────────────────────────────────────┘
   a. System checks if request still available
   b. If yes:
      - service_requests.mechanic_id → assigned
      - service_requests.status → 'accepted'
      - request_broadcasts.accepted_by → mechanic_id
      - request_broadcasts.status → 'accepted'
      - Other broadcasts cancelled
   c. If no (already accepted by another):
      - Show "Request already accepted"
      - request_broadcasts.status → 'expired'
   
   ┌──────────────────────────────────────────────────┐
   │  IF MECHANIC DECLINES                            │
   └──────────────────────────────────────────────────┘
   a. request_broadcasts.response_status → 'declined'
   b. request_broadcasts.responded_at → NOW()
   c. Update mechanics_responded counter
   d. Mechanic removed from broadcast list
   
   ↓
8. Timeout handling (15 minutes)
   - If no response after 15 mins:
     * request_broadcasts.status → 'expired'
     * System can:
       - Expand radius by 5km
       - Rebroadcast to new providers
       - Notify customer of delay
   ↓
9. Broadcast complete when:
   - Someone accepts, OR
   - Request cancelled by customer, OR
   - Max timeout reached
```

---

## 💾 DATABASE FLOW

### **Key Tables & Their Relationships**

```
┌─────────────────────────────────────────────────────────────┐
│                    DATA FLOW DIAGRAM                         │
└─────────────────────────────────────────────────────────────┘

auth.users (Supabase Auth)
    ↓
user_profiles (Central user table)
    ├─→ user_type: 'customer'
    │   ├─→ vehicles (1:many)
    │   ├─→ service_requests as customer (1:many)
    │   └─→ customer_job_history (1:many)
    │
    ├─→ user_type: 'mechanic'
    │   ├─→ mechanics (1:1)
    │   │   ├─→ shop_mechanics (many:many with shops)
    │   │   ├─→ mechanic_availability_status (1:1)
    │   │   ├─→ service_requests as mechanic (1:many)
    │   │   ├─→ mechanic_job_history (1:many)
    │   │   └─→ earnings (1:many)
    │   └─→ reviews as mechanic (1:many)
    │
    └─→ user_type: 'talyer_owner'
        └─→ shops (1:1 as owner)
            ├─→ shop_services (1:many)
            ├─→ shop_mechanics (1:many)
            ├─→ service_requests (1:many)
            ├─→ business_permits (1:many)
            └─→ reviews as shop (1:many)

service_requests (Main transaction table)
    ├─→ service_request_status_log (1:many)
    ├─→ request_broadcasts (1:many)
    ├─→ progress_photos (1:many)
    ├─→ service_phase_tracking (1:1)
    ├─→ messages (1:many)
    ├─→ invoices (1:1)
    │   └─→ payments (1:many)
    │       ├─→ cash_payment_verifications (1:1)
    │       └─→ earnings (1:1)
    ├─→ reviews (1:1)
    ├─→ job_completion_codes (1:1)
    ├─→ mechanic_job_history (1:1)
    └─→ customer_job_history (1:1)
```

### **Critical Database Operations**

1. **Creating a Service Request:**
```sql
-- Step 1: Insert request
INSERT INTO service_requests (
    customer_id, vehicle_id, service_type, 
    latitude, longitude, address,
    status, is_broadcast_request
) VALUES (...);

-- Step 2: If broadcast, find nearby mechanics
SELECT * FROM get_nearby_mechanics(lat, lng, 15);

-- Step 3: Create broadcast entries
INSERT INTO request_broadcasts (...);

-- Step 4: Log initial status
INSERT INTO service_request_status_log (...);
```

2. **Accepting a Request:**
```sql
-- Step 1: Update request
UPDATE service_requests 
SET mechanic_id = ?, 
    status = 'accepted',
    accepted_at = NOW()
WHERE id = ? AND status = 'pending';

-- Step 2: Update mechanic status
UPDATE mechanic_availability_status
SET current_status = 'busy',
    current_request_id = ?
WHERE mechanic_id = ?;

-- Step 3: Cancel other broadcasts
UPDATE request_broadcasts
SET status = 'expired'
WHERE service_request_id = ? AND id != ?;

-- Step 4: Log status change (automatic via trigger)
```

3. **Completing a Job:**
```sql
-- Step 1: Update request
UPDATE service_requests
SET status = 'completed',
    completed_at = NOW()
WHERE id = ?;

-- Step 2: Generate invoice
INSERT INTO invoices (
    invoice_number,
    service_request_id,
    total_amount,
    ...
) VALUES (generate_invoice_number(), ...);

-- Step 3: Create job history
INSERT INTO mechanic_job_history (...);
INSERT INTO customer_job_history (...);

-- Step 4: Generate completion code
INSERT INTO job_completion_codes (
    completion_code,
    ...
) VALUES (uuid_generate_v4(), ...);
```

---

## 💳 PAYMENT FLOW

### **Complete Payment Processing**

```
┌─────────────────────────────────────────────────────────────┐
│                 PAYMENT FLOW DETAILS                         │
└─────────────────────────────────────────────────────────────┘

1. Job completed → Invoice generated
   ↓
2. Invoice calculation:
   
   Base cost:                 ₱1,000.00
   Service fee (distance):    +  ₱150.00
   Subtotal:                  ₱1,150.00
   Platform fee (7%):         +   ₱80.50
   ─────────────────────────────────────
   TOTAL:                     ₱1,230.50
   
   Distribution:
   - Mechanic gets:           ₱800.00 (70%)
   - Shop gets (if any):      ₱269.50 (23%)
   - Platform keeps:          ₱80.50 (7%)
   ↓
3. Customer selects payment method
   ↓
4. Payment processing:
   
   ┌──────────────────────────────────────────────────┐
   │  CASH PAYMENT                                    │
   └──────────────────────────────────────────────────┘
   1. Customer pays cash directly
   2. Mechanic/Customer takes photo
   3. Upload to Supabase Storage
   4. Create cash_payment_verifications entry:
      - proof_image_url
      - cash_amount
      - verification_status: 'pending'
   5. Admin reviews photo
   6. Admin verifies amount matches
   7. verification_status → 'verified'
   8. Payment marked completed
   9. Earnings released to mechanic
   
   ┌──────────────────────────────────────────────────┐
   │  DIGITAL PAYMENT (GCash/PayMaya/Card)           │
   └──────────────────────────────────────────────────┘
   1. Customer clicks "Pay Now"
   2. App calls backend API
   3. Backend creates PayMongo Source/PaymentIntent:
      ```
      POST https://api.paymongo.com/v1/sources
      {
        "amount": 123050, // in centavos
        "currency": "PHP",
        "type": "gcash",
        "redirect": {
          "success": "app://payment-success",
          "failed": "app://payment-failed"
        }
      }
      ```
   4. Backend saves payment record:
      - payment_method: 'gcash'
      - payment_status: 'pending'
      - paymongo_payment_id
      - paymongo_checkout_url
   5. Customer redirected to PayMongo
   6. Customer completes payment on GCash app
   7. PayMongo sends webhook to backend
   8. Backend verifies webhook signature
   9. Backend updates payment:
      - payment_status → 'completed'
      - paid_at → NOW()
      - transaction_id
   10. Invoice updated:
      - payment_status → 'paid'
      - paid_at → NOW()
   11. Earnings automatically distributed
   
   ↓
5. After payment confirmed:
   - Create earnings entry for mechanic
   - If shop-based, create shop earnings
   - Update mechanic statistics
   - Release mechanic (status: 'available')
   - Trigger review prompt for customer
   ↓
6. Payment complete! ✅
```

---

## 🔔 NOTIFICATION FLOW

### **Push Notification System**

```
┌─────────────────────────────────────────────────────────────┐
│              NOTIFICATION ARCHITECTURE                       │
└─────────────────────────────────────────────────────────────┘

1. Event triggers in system
   ↓
2. System determines notification type
   ↓
3. Fetch template from notification_templates
   ↓
4. Populate template with dynamic data
   Example:
   Template: "Your request has been accepted by {mechanic_name}"
   Populated: "Your request has been accepted by Juan Cruz"
   ↓
5. Identify recipient(s)
   ↓
6. Get FCM token from user_profiles.fcm_token
   ↓
7. Create notification entry:
   INSERT INTO notifications (
       user_id,
       title,
       message,
       notification_type,
       data
   ) VALUES (...);
   ↓
8. Send via Firebase Cloud Messaging:
   ```
   {
     "to": "<fcm_token>",
     "notification": {
       "title": "Request Accepted",
       "body": "Juan Cruz accepted your request",
       "sound": "default",
       "badge": "1"
     },
     "data": {
       "type": "request_accepted",
       "request_id": "uuid",
       "mechanic_id": "uuid"
     }
   }
   ```
   ↓
9. User receives notification
   ↓
10. User taps notification
    ↓
11. App opens to relevant screen
    - Request accepted → Request details
    - Message received → Chat screen
    - Payment complete → Receipt screen
    ↓
12. Mark notification as read:
    UPDATE notifications
    SET is_read = true,
        read_at = NOW()
    WHERE id = ?;
```

### **Key Notification Triggers**

| Event | Recipient | Type |
|-------|-----------|------|
| Request created | Mechanics (broadcast) | `new_request` |
| Request accepted | Customer | `request_accepted` |
| Mechanic arriving | Customer | `mechanic_arriving` |
| Service started | Customer | `service_started` |
| Progress photo uploaded | Customer | `progress_update` |
| Service completed | Customer | `service_completed` |
| Payment received | Mechanic | `payment_received` |
| Review submitted | Mechanic | `review_received` |
| New mechanic assigned | Shop owner | `mechanic_assigned` |
| Document verified | User | `document_verified` |
| Broadcast timeout | Customer | `request_timeout` |

---

## 🔐 SECURITY FLOW

### **Authentication & Authorization**

```
┌─────────────────────────────────────────────────────────────┐
│                  SECURITY MECHANISMS                         │
└─────────────────────────────────────────────────────────────┘

1. USER AUTHENTICATION (Supabase Auth)
   - Email/Password
   - OAuth providers (Google, Facebook)
   - Phone number (OTP)
   - Magic links
   ↓
2. Session management
   - JWT tokens
   - Refresh tokens
   - Auto-refresh on expiry
   ↓
3. ROW LEVEL SECURITY (RLS)
   Examples:
   
   user_profiles:
   ✓ Users can view own profile
   ✓ Users can update own profile
   
   service_requests:
   ✓ Customers can view own requests
   ✓ Mechanics can view assigned requests
   ✓ Shop owners can view shop requests
   
   payments:
   ✓ Users can only view own payments
   ✓ Admins can view all payments
   ↓
4. Document verification
   - All uploads verified by admin
   - document_verifications table
   - Status workflow: pending → verified/rejected
   ↓
5. Payment security
   - No card details stored
   - PayMongo handles PCI compliance
   - Webhook signature verification
   - Idempotency keys for duplicate prevention
   ↓
6. Audit logging
   - All actions logged sa audit_logs
   - Admin actions sa admin_activity_logs
   - Security events sa account_security_logs
```

---

## 📊 SYSTEM STATISTICS & ANALYTICS

### **Daily Statistics Collection**

```
┌─────────────────────────────────────────────────────────────┐
│              ANALYTICS COLLECTION                            │
└─────────────────────────────────────────────────────────────┘

Every day at midnight (cron job):

1. Count total users
2. Count active mechanics
3. Count active shops
4. Count service requests (total, completed, cancelled)
5. Calculate total revenue
6. Calculate platform earnings
7. Store in platform_statistics table

Queries:
- Total users by type
- Completion rate
- Average rating
- Peak hours
- Popular services
- Geographic heatmap
- Earnings trends
```

---

## 🎯 COMPLETE USER JOURNEY EXAMPLE

### **Real-World Scenario: Flat Tire Emergency**

```
🚗 SCENARIO: Si Maria ay nasa NLEX at na-flat tire

[7:30 AM] - Maria realizes tire is flat
   ↓
[7:32 AM] - Opens RoadAid app
   ↓
[7:33 AM] - Creates broadcast request:
   - Service: Tire Repair
   - Location: Auto-detected (NLEX KM 42)
   - Priority: Urgent
   - Photos: Uploaded flat tire photo
   ↓
[7:34 AM] - System searches nearby mechanics
   - Found 8 mechanics within 15km
   - Broadcast sent to all 8
   ↓
[7:35 AM] - Pedro (mechanic) receives notification
   - 5km away
   - Accepts request (first to respond)
   ↓
[7:35 AM] - Maria receives confirmation
   - "Pedro accepted your request"
   - Can see Pedro's location on map
   - Pedro: 4.9★ rating, 150 jobs
   ↓
[7:36 AM] - Pedro starts traveling
   - ETA: 10 minutes
   - Real-time location visible to Maria
   ↓
[7:38 AM] - Pedro messages Maria
   - "On my way po. Do you have spare tire?"
   - Maria: "Yes, nasa trunk"
   ↓
[7:45 AM] - Pedro arrives
   - Clicks "Arrived" button
   - Takes arrival photo
   - Maria receives notification
   ↓
[7:47 AM] - Service starts
   - Status: In Progress
   - Pedro uploads inspection photo
   ↓
[8:05 AM] - Pedro uploads progress photos:
   - Removing flat tire
   - Installing spare tire
   - Final check
   ↓
[8:15 AM] - Service completed
   - Pedro marks as complete
   - Total time: 38 minutes
   ↓
[8:16 AM] - QR code verification
   - Maria's phone shows QR code
   - Pedro scans with his phone
   - Verified ✓
   ↓
[8:16 AM] - Invoice generated
   - Base cost: ₱500
   - Service fee (5km): ₱250
   - Emergency multiplier (1.5x): ₱375
   - Platform fee (7%): ₱78.75
   - TOTAL: ₱1,203.75
   ↓
[8:17 AM] - Maria pays via GCash
   - Clicks "Pay with GCash"
   - Redirected to GCash
   - Enters PIN
   - Payment successful
   ↓
[8:18 AM] - Payment confirmed
   - Receipt generated
   - Pedro receives notification
   - Earnings: ₱846.25 (70%)
   ↓
[8:20 AM] - Maria rates service
   - Overall: 5★
   - Service quality: 5★
   - Professionalism: 5★
   - Timeliness: 5★
   - Review: "Super bilis at helpful!"
   ↓
[8:21 AM] - Transaction complete!
   - Maria continues journey
   - Pedro available for next job
   - Job history recorded for both

✅ SUCCESSFUL TRANSACTION COMPLETED
```

---

## 🔄 KEY SYSTEM FLOWS SUMMARY

### **1. CUSTOMER FLOW**
Request → Broadcast → Accept → Service → Payment → Review

### **2. MECHANIC FLOW**
Register → Verify → Receive → Accept → Perform → Complete → Earn

### **3. SHOP OWNER FLOW**
Register → Setup → Hire → Manage → Monitor → Earn

### **4. BROADCAST FLOW**
Create → Search → Notify → Accept → Assign → Track

### **5. PAYMENT FLOW**
Complete → Invoice → Pay → Verify → Distribute → Confirm

### **6. NOTIFICATION FLOW**
Event → Template → Populate → Send → Receive → Read

---

## 📝 CONCLUSION

Ang RoadAid system ay isang comprehensive platform na:

✅ **3 main user types**: Customer, Mechanic, Shop Owner
✅ **3 request types**: Direct, Shop-based, Broadcast
✅ **46 database tables**: Optimized for scalability
✅ **Real-time tracking**: GPS location updates
✅ **Multiple payment methods**: Cash, GCash, PayMaya, Card
✅ **QR verification**: Secure job completion
✅ **Rating system**: Quality assurance
✅ **Push notifications**: Real-time updates
✅ **Admin panel**: Full platform management
✅ **Audit trails**: Complete transaction history

---

**System Status:** ✅ **PRODUCTION READY**

**Last Updated:** October 10, 2025
