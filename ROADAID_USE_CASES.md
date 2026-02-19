# 🎯 ROADAID SYSTEM - USE CASES

**Date:** October 10, 2025  
**System:** RoadAid Auto Repair Assistance Platform  
**Document Type:** Use Case Specifications

---

## 📋 TABLE OF CONTENTS

1. [Use Case Overview](#use-case-overview)
2. [Actor Definitions](#actor-definitions)
3. [Customer Use Cases](#customer-use-cases)
4. [Mechanic Use Cases](#mechanic-use-cases)
5. [Shop Owner Use Cases](#shop-owner-use-cases)
6. [Admin Use Cases](#admin-use-cases)
7. [Use Case Diagrams](#use-case-diagrams)

---

## 🎭 ACTOR DEFINITIONS

### Primary Actors

| Actor | Description | Responsibilities |
|-------|-------------|------------------|
| **Customer** | Motorista na nangangailangan ng auto repair service | Request service, pay, rate |
| **Mechanic** | Certified mechanic (independent o shop-based) | Accept requests, perform service, earn |
| **Shop Owner** | May-ari ng auto repair shop (Talyer) | Manage shop, hire mechanics, monitor |
| **Admin** | System administrator | Verify documents, manage platform, resolve issues |

### Secondary Actors

| Actor | Description |
|-------|-------------|
| **Payment Gateway** | PayMongo API for digital payments |
| **Notification Service** | Firebase Cloud Messaging for push notifications |
| **Location Service** | GPS/Maps API for location tracking |
| **Storage Service** | Supabase Storage for images/documents |

---

## 👤 CUSTOMER USE CASES

### **UC-C01: Register Account**

**Actor:** Customer  
**Precondition:** User has mobile device with internet connection  
**Postcondition:** Customer account created successfully

**Main Flow:**
1. Customer opens RoadAid app
2. Customer clicks "Sign Up"
3. System displays registration form
4. Customer enters:
   - Email address
   - Password
   - Full name
   - Phone number
5. System validates input
6. System creates auth.users entry
7. System creates user_profiles entry (user_type: 'customer')
8. System sends email verification
9. Customer verifies email
10. System activates account
11. Customer redirected to home screen

**Alternative Flow:**
- **3a.** Customer chooses Google Sign-In
  - 3a1. System redirects to Google OAuth
  - 3a2. Customer authorizes
  - 3a3. System creates account with Google details
  - 3a4. Continue to step 11

**Exception Flow:**
- **5a.** Email already exists
  - 5a1. System shows "Email already registered"
  - 5a2. Suggest "Login" or "Forgot Password"

---

### **UC-C02: Add Vehicle**

**Actor:** Customer  
**Precondition:** Customer is logged in  
**Postcondition:** Vehicle added to customer's profile

**Main Flow:**
1. Customer navigates to "My Vehicles"
2. Customer clicks "Add Vehicle"
3. System displays vehicle form
4. Customer enters:
   - Brand/Make (Toyota, Honda, etc.)
   - Model (Vios, Civic, etc.)
   - Year (2020, 2021, etc.)
   - Color
   - License Plate Number
   - Vehicle Type (Car/Motorcycle/Truck)
5. Customer sets as primary vehicle (optional)
6. Customer clicks "Save"
7. System validates data
8. System inserts to vehicles table
9. System displays success message
10. Vehicle appears in "My Vehicles" list

**Business Rules:**
- Customer can have multiple vehicles
- Only one vehicle can be primary
- License plate must be unique

---

### **UC-C03: Create Direct Mechanic Request**

**Actor:** Customer  
**Precondition:** 
- Customer is logged in
- Customer has at least one vehicle
- GPS location enabled

**Postcondition:** Service request created and sent to specific mechanic

**Main Flow:**
1. Customer clicks "Request Service"
2. System displays request type options
3. Customer selects "Direct Mechanic"
4. System shows list of verified mechanics with:
   - Name
   - Photo
   - Rating
   - Distance
   - Specializations
5. Customer selects mechanic
6. Customer fills request form:
   - Select vehicle
   - Service type (dropdown from service_categories)
   - Problem description
   - Upload photos (optional)
   - Confirm location (auto-detected or manual)
7. System calculates service fee based on distance
8. System displays estimated cost
9. Customer reviews and confirms
10. System creates service_requests entry (status: 'pending')
11. System sends notification to selected mechanic
12. System shows "Request sent" message
13. Customer can track request status

**Alternative Flow:**
- **6a.** Customer wants emergency service
  - 6a1. Customer toggles "Emergency" switch
  - 6a2. System applies 1.5x multiplier to cost
  - 6a3. Request marked as high priority

**Exception Flow:**
- **11a.** Mechanic is offline/unavailable
  - 11a1. System shows "Mechanic currently unavailable"
  - 11a2. Suggest alternative mechanics

---

### **UC-C04: Create Broadcast Request**

**Actor:** Customer  
**Precondition:** 
- Customer is logged in
- GPS location enabled

**Postcondition:** Request broadcasted to nearby mechanics

**Main Flow:**
1. Customer clicks "Request Service"
2. System displays request type options
3. Customer selects "Broadcast Request"
4. Customer fills request form:
   - Select vehicle
   - Service type
   - Problem description
   - Upload photos
   - Location (auto-detected)
   - Set broadcast radius (5km, 10km, 15km, 20km)
5. System calculates service fee
6. Customer confirms request
7. System creates service_requests entry:
   - is_broadcast_request: true
   - broadcast_radius_km: selected
8. System searches nearby mechanics using get_nearby_mechanics()
9. System creates request_broadcasts entries for each mechanic
10. System sends push notifications to all nearby mechanics
11. System shows "Broadcast sent to X mechanics"
12. Customer waits for acceptance
13. System shows real-time responses

**Alternative Flow:**
- **12a.** No mechanics available within radius
  - 12a1. System suggests expanding radius
  - 12a2. Customer can expand or cancel

**Business Rules:**
- First mechanic to accept gets the job
- Broadcast expires after 15 minutes if no response
- Customer can cancel anytime before acceptance

---

### **UC-C05: Track Service Progress**

**Actor:** Customer  
**Precondition:** Service request is accepted

**Main Flow:**
1. Customer opens request details
2. System displays:
   - Mechanic information
   - Current status
   - Real-time location on map
   - ETA
   - Progress photos
3. Customer can:
   - View mechanic's route
   - See distance to location
   - View uploaded photos
   - Send messages to mechanic
4. System updates every 30 seconds
5. Customer receives notifications on status changes:
   - Mechanic en route
   - Mechanic arrived
   - Service started
   - Service completed

---

### **UC-C06: Complete Payment**

**Actor:** Customer, Payment Gateway  
**Precondition:** Service is completed and invoice generated

**Postcondition:** Payment processed and recorded

**Main Flow:**
1. Mechanic marks service as complete
2. System generates invoice
3. Customer receives payment notification
4. Customer opens invoice details showing:
   - Service breakdown
   - Distance fee
   - Platform fee
   - Total amount
5. Customer selects payment method:
   - Cash
   - GCash
   - PayMaya
   - Credit/Debit Card
6. **If Cash:**
   - 6.1. Customer pays mechanic directly
   - 6.2. Mechanic/Customer takes photo of cash
   - 6.3. Upload photo proof
   - 6.4. System creates cash_payment_verifications entry
   - 6.5. Admin verifies later
7. **If Digital (GCash/PayMaya/Card):**
   - 7.1. System creates PayMongo payment intent
   - 7.2. Customer redirected to payment gateway
   - 7.3. Customer completes payment
   - 7.4. Payment Gateway processes transaction
   - 7.5. Payment Gateway sends webhook to system
   - 7.6. System verifies webhook signature
   - 7.7. System updates payment status to 'completed'
8. System updates invoice (paid_at timestamp)
9. System distributes earnings
10. System sends receipt to customer
11. Customer receives confirmation

---

### **UC-C07: Rate and Review Service**

**Actor:** Customer  
**Precondition:** Payment completed

**Main Flow:**
1. System prompts customer to rate service
2. Customer opens rating screen
3. Customer rates (1-5 stars):
   - Overall rating
   - Service quality
   - Professionalism
   - Timeliness
   - Value for money
4. Customer writes review (optional)
5. Customer uploads photos (optional)
6. Customer clicks "Submit"
7. System validates ratings
8. System creates reviews entry
9. System recalculates mechanic average rating
10. System updates mechanics.rating
11. System updates mechanics.total_reviews
12. System sends notification to mechanic
13. Customer sees "Thank you for your feedback"

**Business Rules:**
- Rating required (1-5 stars)
- Review text optional
- Can only rate once per service
- Cannot edit after submission

---

### **UC-C08: View Service History**

**Actor:** Customer  
**Precondition:** Customer has completed at least one service

**Main Flow:**
1. Customer navigates to "Service History"
2. System queries customer_job_history table
3. System displays list showing:
   - Date and time
   - Service type
   - Mechanic name
   - Shop (if applicable)
   - Amount paid
   - Status
   - Rating given
4. Customer can:
   - Filter by date range
   - Filter by service type
   - Search by mechanic name
   - View full details
   - Download receipts
5. Customer selects a history item
6. System shows complete details:
   - All progress photos
   - Messages exchanged
   - Invoice
   - Review given

---

## 🔧 MECHANIC USE CASES

### **UC-M01: Register as Independent Mechanic**

**Actor:** Mechanic  
**Precondition:** User has valid documents

**Main Flow:**
1. Mechanic opens RoadAid app
2. Mechanic clicks "Sign Up as Mechanic"
3. System displays registration form
4. Mechanic enters:
   - Email
   - Password
   - Full name
   - Phone number
5. System creates auth.users and user_profiles
6. Mechanic continues to profile setup
7. Mechanic enters:
   - Specializations (multi-select):
     * Tire specialist
     * Engine repair
     * Electrical
     * Transmission
     * Brake specialist
     * AC repair
   - Years of experience
   - Service radius (km)
   - Profile photo
8. Mechanic uploads documents:
   - Driver's license
   - Mechanic license (if available)
   - Valid ID
9. System saves to document_verifications table
10. System creates mechanics entry:
    - is_independent: true
    - is_verified: false (pending)
11. System sends to admin for verification
12. Mechanic sees "Pending Verification" status

**Postcondition:** Mechanic registered, awaiting verification

---

### **UC-M02: Accept Broadcast Request**

**Actor:** Mechanic  
**Precondition:** 
- Mechanic is verified
- Mechanic status is 'available'
- Broadcast request sent

**Main Flow:**
1. Mechanic receives push notification
2. Notification shows:
   - Service type
   - Distance from customer
   - Estimated earnings
   - Customer rating
3. Mechanic opens notification
4. System displays request details:
   - Problem description
   - Vehicle details
   - Customer location on map
   - Photos (if any)
   - Estimated service fee
5. Mechanic reviews information
6. Mechanic clicks "Accept"
7. System checks if request still available
8. **If available:**
   - 8.1. System updates service_requests:
     * mechanic_id assigned
     * status: 'accepted'
     * accepted_at: NOW()
   - 8.2. System updates mechanic_availability_status:
     * current_status: 'busy'
     * current_request_id: assigned
   - 8.3. System cancels other broadcasts
   - 8.4. System notifies customer
   - 8.5. Mechanic sees "Request accepted!"
9. **If already accepted by another:**
   - 9.1. System shows "Request already taken"
   - 9.2. Update request_broadcasts status to 'expired'

**Alternative Flow:**
- **6a.** Mechanic declines
  - 6a1. System updates request_broadcasts (response: 'declined')
  - 6a2. Mechanic returns to available status

---

### **UC-M03: Navigate to Customer Location**

**Actor:** Mechanic, Location Service  
**Precondition:** Request accepted

**Main Flow:**
1. Mechanic views request details
2. System displays customer location on map
3. Mechanic clicks "Start Navigation"
4. System opens preferred navigation app:
   - Google Maps
   - Waze
5. Mechanic follows route
6. System tracks mechanic's real-time location
7. System updates customer with ETA
8. Customer sees mechanic approaching on map
9. Mechanic arrives at location
10. Mechanic clicks "I've Arrived"
11. System updates service_phase_tracking
12. System notifies customer
13. Mechanic can now start service

---

### **UC-M04: Perform Service with Photo Documentation**

**Actor:** Mechanic, Storage Service  
**Precondition:** Mechanic arrived at location

**Main Flow:**
1. Mechanic inspects vehicle
2. Mechanic clicks "Start Service"
3. System updates service_requests.status to 'in_progress'
4. Mechanic takes inspection photos
5. Mechanic uploads photos:
   - Select photo from camera/gallery
   - Add description
   - Select phase: 'inspection'
6. System uploads to Supabase Storage
7. System creates progress_photos entry
8. Customer receives notification with photo
9. Mechanic performs repair work
10. During work, mechanic uploads:
    - Diagnosis photos
    - Work in progress photos
    - Before/after photos
11. Each photo instantly visible to customer
12. Mechanic completes work
13. Mechanic takes completion photos
14. Mechanic clicks "Complete Service"
15. System prompts for final details:
    - Actual cost (if different from estimate)
    - Parts used
    - Additional notes
16. Mechanic confirms completion
17. System updates status to 'completed'

**Business Rules:**
- Minimum 3 photos required (arrival, during, completion)
- Photos timestamped automatically
- Customer can request additional photos

---

### **UC-M05: Verify Job Completion with QR Code**

**Actor:** Mechanic, Customer  
**Precondition:** Service completed

**Main Flow:**
1. System generates unique QR code
2. System saves to job_completion_codes table
3. Customer's phone displays QR code
4. Mechanic opens scanner in app
5. Mechanic scans customer's QR code
6. System validates code:
   - Checks if code matches request
   - Checks if code not expired
   - Checks if not already used
7. System marks code as scanned:
   - is_scanned: true
   - scanned_at: NOW()
8. System updates service_requests:
   - completed_at: NOW()
9. System triggers invoice generation
10. Both parties see "Verification Complete"
11. System proceeds to payment

**Exception Flow:**
- **6a.** Invalid QR code
  - 6a1. System shows "Invalid code"
  - 6a2. Mechanic can retry
- **6b.** QR code expired
  - 6b1. System generates new code
  - 6b2. Customer gets updated QR

---

### **UC-M06: View Earnings and Payouts**

**Actor:** Mechanic  
**Precondition:** Mechanic has completed jobs

**Main Flow:**
1. Mechanic navigates to "Earnings"
2. System queries earnings table
3. System displays dashboard:
   - Total earnings (all time)
   - This month earnings
   - Pending earnings
   - Released earnings
   - Average per job
4. System shows earnings breakdown:
   - Date
   - Customer name
   - Service type
   - Gross amount
   - Platform fee (7%)
   - Net earnings
   - Status (pending/approved/released)
5. Mechanic can filter by:
   - Date range
   - Status
   - Service type
6. Mechanic clicks "Request Payout"
7. System shows available balance
8. Mechanic enters payout details:
   - Bank account or GCash number
   - Amount to withdraw
9. System validates minimum amount (₱500)
10. Mechanic confirms request
11. System creates payout request
12. Admin processes payout
13. Mechanic receives payout notification

**Business Rules:**
- Minimum payout: ₱500
- Earnings held for 7 days (cooling period)
- Maximum one payout per week

---

### **UC-M07: View Job History**

**Actor:** Mechanic  
**Precondition:** Mechanic completed at least one job

**Main Flow:**
1. Mechanic opens "Job History"
2. System queries mechanic_job_history
3. System displays list with:
   - Date and time
   - Customer name
   - Service type
   - Location
   - Earnings
   - Rating received
   - Status
4. Mechanic can:
   - Filter by date range
   - Filter by rating
   - Search by customer name
   - Export to PDF
5. Mechanic selects job
6. System shows full details:
   - All photos uploaded
   - Customer review
   - Time breakdown
   - Earnings breakdown
   - Invoice copy

---

### **UC-M08: Update Availability Status**

**Actor:** Mechanic  
**Precondition:** Mechanic is logged in

**Main Flow:**
1. Mechanic opens settings
2. System shows current status badge
3. Mechanic toggles availability:
   - Available (green) - Can receive requests
   - Busy (yellow) - Currently on job
   - Offline (gray) - Not accepting requests
4. System updates mechanic_availability_status
5. System updates mechanics.is_available
6. If going offline:
   - 6.1. System stops sending broadcast notifications
   - 6.2. Mechanic hidden from customer searches
7. If going available:
   - 7.1. System enables broadcast notifications
   - 7.2. Mechanic visible in searches
8. Status reflected immediately

**Business Rules:**
- Cannot go offline while on active job
- Auto-offline after 30 minutes of inactivity
- Auto-busy when request accepted

---

## 🏪 SHOP OWNER USE CASES

### **UC-S01: Register and Setup Shop**

**Actor:** Shop Owner  
**Precondition:** Valid business documents available

**Main Flow:**
1. Shop owner registers account
2. System creates user_profiles (user_type: 'talyer_owner')
3. Shop owner clicks "Setup Shop"
4. System displays shop registration form
5. Shop owner enters:
   - Shop name
   - Address
   - Coordinates (GPS or manual)
   - Phone number
   - Email
   - Description
6. Shop owner sets business hours:
   ```json
   {
     "monday": {"open": "08:00", "close": "18:00"},
     "tuesday": {"open": "08:00", "close": "18:00"},
     ...
   }
   ```
7. Shop owner uploads shop photo
8. System creates shops entry (is_verified: false)
9. Shop owner uploads business documents:
   - Business permit
   - Mayor's permit
   - DTI registration
   - Owner's valid ID
10. System saves to business_permits table
11. System sends for admin verification
12. Shop owner sees "Pending Verification"

**Postcondition:** Shop registered, awaiting verification

---

### **UC-S02: Add Shop Services**

**Actor:** Shop Owner  
**Precondition:** Shop is verified

**Main Flow:**
1. Shop owner navigates to "Manage Services"
2. Shop owner clicks "Add Service"
3. System displays service form
4. Shop owner:
   - Selects category from service_categories
   - Or enters custom service name
5. Shop owner enters:
   - Service description
   - Base price (₱)
   - Estimated duration (minutes)
   - Parts/materials included
6. Shop owner sets availability:
   - Always available
   - Temporarily unavailable
   - Available on specific days
7. Shop owner can upload service photos
8. Shop owner clicks "Save"
9. System validates data
10. System inserts to shop_services table
11. Service now visible to customers
12. System updates shops.services_offered array

**Business Rules:**
- Shop can offer multiple services
- Custom pricing per service allowed
- Can disable service temporarily

---

### **UC-S03: Invite Mechanic to Shop**

**Actor:** Shop Owner  
**Precondition:** Shop is verified and active

**Main Flow:**
1. Shop owner navigates to "Mechanics"
2. Shop owner clicks "Invite Mechanic"
3. System displays invitation form
4. Shop owner enters:
   - Mechanic's email
   - First name
   - Last name
   - Role (Mechanic/Senior Mechanic)
   - Hourly rate (optional)
5. System generates:
   - Temporary password
   - Unique invitation token
6. System creates mechanic_invitations entry
7. System sends email with:
   - Welcome message
   - Shop details
   - Temporary password
   - Invitation link
   - Expiry date (7 days)
8. Email sent to mechanic
9. Shop owner sees "Invitation sent"
10. Mechanic receives email
11. Mechanic clicks invitation link
12. System validates token
13. System auto-creates account:
    - auth.users entry
    - user_profiles (user_type: 'mechanic')
    - mechanics (shop_id assigned)
14. System creates shop_mechanics entry
15. Mechanic can login with temp password
16. Mechanic prompted to change password
17. Shop owner notified of acceptance

**Alternative Flow:**
- **12a.** Token expired
  - 12a1. System shows "Invitation expired"
  - 12a2. Shop owner can resend

**Exception Flow:**
- **4a.** Email already registered
  - 4a1. System suggests "Add Existing Mechanic"

---

### **UC-S04: Assign Mechanic to Service Request**

**Actor:** Shop Owner  
**Precondition:** 
- Shop received service request
- Shop has available mechanics

**Main Flow:**
1. Shop owner receives notification
2. Notification shows:
   - Customer name
   - Service type
   - Location
   - Distance
   - Urgency
3. Shop owner opens request details
4. System displays:
   - Customer information
   - Vehicle details
   - Problem description
   - Photos
   - Estimated earnings
5. Shop owner views available mechanics:
   - Name
   - Current status (available/busy)
   - Specialization
   - Distance from customer
   - Current rating
6. Shop owner selects mechanic
7. Shop owner can add notes for mechanic
8. Shop owner clicks "Assign"
9. System updates service_requests:
   - shop_id assigned
   - assigned_mechanic_id assigned
10. System notifies selected mechanic
11. Mechanic receives request details
12. Mechanic can accept or decline
13. If accepted, job proceeds normally

**Business Rules:**
- Only available mechanics shown
- Can reassign if mechanic declines
- Shop owner gets commission from job

---

### **UC-S05: Monitor Shop Operations**

**Actor:** Shop Owner  
**Precondition:** Shop is active

**Main Flow:**
1. Shop owner opens "Dashboard"
2. System queries v_shop_statistics view
3. System displays metrics:
   - **Today:**
     * Active jobs: 3
     * Completed jobs: 7
     * Total revenue: ₱15,750
   - **This Week:**
     * Total jobs: 45
     * Average rating: 4.8★
     * Total revenue: ₱89,500
   - **This Month:**
     * Total jobs: 180
     * New customers: 67
     * Revenue: ₱342,000
4. System shows:
   - Mechanics performance table:
     | Name | Jobs | Rating | Earnings |
     |------|------|--------|----------|
     | Juan | 23 | 4.9★ | ₱45,600 |
     | Pedro | 18 | 4.7★ | ₱38,200 |
   - Active requests map
   - Revenue chart (daily/weekly/monthly)
   - Service breakdown (tire, engine, etc.)
5. Shop owner can:
   - Filter by date range
   - Filter by mechanic
   - Export reports
   - View individual transactions

---

### **UC-S06: Set Shop Status**

**Actor:** Shop Owner  
**Precondition:** Shop owner is logged in

**Main Flow:**
1. Shop owner opens shop settings
2. System shows current status
3. Shop owner selects new status:
   - **Open** - Accepting all requests
   - **Closed** - Not accepting requests
   - **Busy** - All mechanics occupied
4. Shop owner confirms change
5. System updates shops.current_status
6. If closed:
   - 6.1. Shop hidden from customer searches
   - 6.2. Existing active requests unaffected
   - 6.3. New requests not routed to shop
7. If open:
   - 7.1. Shop visible in searches
   - 7.2. Can receive broadcast requests
   - 7.3. Listed in nearby shops
8. System sends notification to all shop mechanics
9. Status displayed to customers

**Business Rules:**
- Auto-close at end of business hours
- Auto-open at start of business hours
- Can override auto-schedule

---

### **UC-S07: Manage Shop Mechanics**

**Actor:** Shop Owner  
**Precondition:** Shop has mechanics

**Main Flow:**
1. Shop owner opens "Mechanics Management"
2. System displays list of mechanics:
   - Name and photo
   - Status (active/inactive)
   - Jobs completed
   - Average rating
   - Total earnings
   - Hire date
3. Shop owner can:
   - View mechanic details
   - Edit mechanic role
   - Update hourly rate
   - Deactivate mechanic
   - View performance history
4. Shop owner selects mechanic
5. System shows detailed profile:
   - Personal information
   - Specializations
   - Job history with shop
   - Customer ratings
   - Earnings breakdown
   - Attendance/punctuality
6. Shop owner can:
   - Give bonus
   - Assign training
   - Set performance goals
   - View chat history

---

## 👨‍💼 ADMIN USE CASES

### **UC-A01: Verify Mechanic Documents**

**Actor:** Admin  
**Precondition:** Mechanic submitted documents

**Main Flow:**
1. Admin logs into admin portal
2. Admin navigates to "Pending Verifications"
3. System shows list with:
   - Applicant name
   - Submission date
   - Document type
   - Status
4. Admin selects mechanic application
5. System displays:
   - Applicant information
   - Uploaded documents:
     * Driver's license
     * Mechanic license
     * Valid ID
   - Profile details
6. Admin reviews each document:
   - Check authenticity
   - Verify details match
   - Check expiry dates
7. Admin checks applicant background (optional)
8. Admin makes decision:
   
   **If APPROVED:**
   - 8.1. Admin clicks "Approve"
   - 8.2. System updates mechanics.is_verified = true
   - 8.3. System updates document_verifications.verification_status = 'verified'
   - 8.4. System sends approval notification to mechanic
   - 8.5. Mechanic can now accept requests
   
   **If REJECTED:**
   - 8.6. Admin clicks "Reject"
   - 8.7. Admin enters rejection reason
   - 8.8. System updates verification_status = 'rejected'
   - 8.9. System sends rejection notification with reason
   - 8.10. Mechanic can resubmit corrected documents

9. System logs action to admin_activity_logs

**Business Rules:**
- All documents must be verified within 48 hours
- Rejection must include reason
- Applicant can appeal rejection

---

### **UC-A02: Verify Shop Business Permit**

**Actor:** Admin  
**Precondition:** Shop owner submitted business documents

**Main Flow:**
1. Admin opens "Shop Verifications"
2. System lists pending shop verifications
3. Admin selects shop application
4. System displays:
   - Shop information
   - Owner details
   - Business documents:
     * Business permit image
     * Mayor's permit
     * DTI registration
     * Owner's ID
5. Admin verifies:
   - Business permit number
   - Registered business name
   - Registered address
   - Permit validity/expiry
   - Owner identity matches
6. Admin cross-checks with LGU database (if available)
7. Admin inspects shop location on map
8. Admin makes decision:
   
   **If APPROVED:**
   - 8.1. Admin marks as verified
   - 8.2. System updates shops.is_verified = true
   - 8.3. System updates business_permits.is_verified = true
   - 8.4. Shop now visible to customers
   - 8.5. Owner notified
   
   **If REJECTED:**
   - 8.6. Admin provides rejection reason
   - 8.7. System notifies owner
   - 8.8. Owner can resubmit

9. System creates audit log entry

---

### **UC-A03: Verify Cash Payment**

**Actor:** Admin  
**Precondition:** Cash payment submitted with photo proof

**Main Flow:**
1. Admin navigates to "Payment Verifications"
2. System shows list of pending cash payments:
   - Date
   - Customer name
   - Mechanic name
   - Amount
   - Status
3. Admin selects payment to verify
4. System displays:
   - Service request details
   - Invoice breakdown
   - Uploaded photo proof
   - Mechanic confirmation
   - Customer confirmation
5. Admin examines photo:
   - Clear view of cash
   - Correct amount visible
   - No signs of tampering
6. Admin cross-checks:
   - Amount matches invoice
   - Both parties confirmed
   - Timestamp reasonable
7. Admin makes decision:
   
   **If VERIFIED:**
   - 7.1. Admin clicks "Verify"
   - 7.2. System updates cash_payment_verifications.verification_status = 'verified'
   - 7.3. System updates payment.payment_status = 'completed'
   - 7.4. System releases earnings to mechanic
   - 7.5. Both parties notified
   
   **If SUSPICIOUS:**
   - 7.6. Admin marks for investigation
   - 7.7. Admin can contact parties
   - 7.8. System holds payment
   
   **If REJECTED:**
   - 7.9. Admin provides reason
   - 7.10. Parties notified to resolve

8. System logs verification to audit_logs

---

### **UC-A04: Resolve Dispute**

**Actor:** Admin  
**Precondition:** Dispute reported by user

**Main Flow:**
1. Admin receives dispute notification
2. Admin opens "Disputes" section
3. System shows dispute details:
   - Reporting party
   - Accused party
   - Service request involved
   - Dispute type:
     * Service quality
     * Payment issue
     * Behavior/conduct
     * Fraud/scam
   - Description
   - Evidence (photos, messages)
4. Admin reviews all evidence:
   - Service request timeline
   - Messages exchanged
   - Photos uploaded
   - Payment records
   - Previous reviews/ratings
5. Admin can:
   - Request additional information
   - Contact both parties
   - Review similar cases
   - Check user history
6. Admin investigates:
   - Timeline of events
   - Contract/agreement terms
   - Platform policies violated
7. Admin makes decision:
   
   **Resolution options:**
   - Full refund to customer
   - Partial refund
   - No refund (favor mechanic)
   - Account warning
   - Account suspension
   - Account ban
   
8. Admin enters decision and reasoning
9. System executes resolution:
   - Processes refund if applicable
   - Updates user records
   - Sends notifications
   - Logs all actions
10. Both parties notified of decision
11. Appeal period starts (if applicable)

**Business Rules:**
- Disputes must be resolved within 7 days
- All decisions must include reasoning
- Users can appeal once
- Serious violations result in immediate suspension

---

### **UC-A05: Monitor Platform Statistics**

**Actor:** Admin  
**Precondition:** Admin has access to analytics

**Main Flow:**
1. Admin opens analytics dashboard
2. System displays comprehensive metrics:
   
   **User Statistics:**
   - Total users: 15,432
   - Customers: 12,045
   - Mechanics: 2,890
   - Shop owners: 497
   - New users today: 67
   
   **Service Statistics:**
   - Total requests: 8,945
   - Completed: 7,234 (81%)
   - In progress: 145 (2%)
   - Cancelled: 1,566 (17%)
   - Average completion time: 42 mins
   
   **Financial Statistics:**
   - Total revenue: ₱4,567,890
   - Platform earnings: ₱319,752 (7%)
   - Pending payouts: ₱234,560
   - Average transaction: ₱512
   
   **Performance Metrics:**
   - Average mechanic rating: 4.6★
   - Average shop rating: 4.5★
   - Customer satisfaction: 87%
   - Response time: 3.2 mins

3. Admin can:
   - Filter by date range
   - Compare periods
   - Export reports
   - Generate charts
   - Drill down into specifics

4. System provides insights:
   - Peak hours
   - Popular services
   - Geographic hotspots
   - Growth trends
   - Problem areas

---

### **UC-A06: Manage System Settings**

**Actor:** Admin  
**Precondition:** Admin has super_admin role

**Main Flow:**
1. Admin opens "System Settings"
2. System displays configuration options:
   
   **Financial Settings:**
   - Platform fee percentage: 7%
   - Minimum service fee: ₱200
   - Maximum service fee: ₱5,000
   - Emergency multiplier: 1.5x
   - Minimum payout: ₱500
   
   **Service Settings:**
   - Broadcast radius: 15km
   - Max active requests per customer: 3
   - Request timeout: 15 minutes
   - QR code expiry: 24 hours
   
   **Quality Settings:**
   - Minimum mechanic rating: 3.0
   - Auto-suspend threshold: 2.5
   - Review required: Yes
   - Photo documentation required: Yes

3. Admin can modify any setting
4. System validates new values
5. Admin saves changes
6. System updates app_settings table
7. System logs change to admin_activity_logs
8. Changes take effect immediately
9. Affected users notified if necessary

**Business Rules:**
- Only super_admin can modify critical settings
- All changes logged
- Some changes require system restart

---

## 📊 USE CASE DIAGRAMS

### **Customer Use Case Diagram**

```
                    RoadAid System
                         
┌──────────────────────────────────────────────────┐
│                                                  │
│  Customer                                        │
│    │                                             │
│    ├─→ Register Account                         │
│    ├─→ Add Vehicle                              │
│    ├─→ Create Service Request                   │
│    │   ├─→ Direct Mechanic Request              │
│    │   ├─→ Shop-Based Request                   │
│    │   └─→ Broadcast Request                    │
│    ├─→ Track Service Progress                   │
│    ├─→ Chat with Mechanic                       │
│    ├─→ Complete Payment                         │
│    │   ├─→ Pay Cash                             │
│    │   ├─→ Pay GCash                            │
│    │   ├─→ Pay PayMaya                          │
│    │   └─→ Pay Card                             │
│    ├─→ Rate and Review                          │
│    ├─→ View Service History                     │
│    └─→ Manage Profile                           │
│                                                  │
└──────────────────────────────────────────────────┘
```

### **Mechanic Use Case Diagram**

```
                    RoadAid System
                         
┌──────────────────────────────────────────────────┐
│                                                  │
│  Mechanic                                        │
│    │                                             │
│    ├─→ Register Account                         │
│    ├─→ Complete Profile                         │
│    ├─→ Upload Documents                         │
│    ├─→ Receive Service Requests                 │
│    │   ├─→ View Broadcast Requests              │
│    │   └─→ View Direct Requests                 │
│    ├─→ Accept/Decline Request                   │
│    ├─→ Navigate to Customer                     │
│    ├─→ Perform Service                          │
│    │   ├─→ Update Status                        │
│    │   └─→ Upload Progress Photos               │
│    ├─→ Complete Service                         │
│    ├─→ Scan QR Code Verification                │
│    ├─→ View Earnings                            │
│    ├─→ Request Payout                           │
│    ├─→ View Job History                         │
│    ├─→ Update Availability                      │
│    └─→ Respond to Reviews                       │
│                                                  │
└──────────────────────────────────────────────────┘
```

### **Shop Owner Use Case Diagram**

```
                    RoadAid System
                         
┌──────────────────────────────────────────────────┐
│                                                  │
│  Shop Owner                                      │
│    │                                             │
│    ├─→ Register Shop                            │
│    ├─→ Upload Business Documents                │
│    ├─→ Setup Shop Profile                       │
│    ├─→ Add Shop Services                        │
│    ├─→ Manage Services                          │
│    ├─→ Invite Mechanics                         │
│    ├─→ Manage Mechanics                         │
│    │   ├─→ View Mechanic Performance            │
│    │   ├─→ Assign Jobs                          │
│    │   └─→ Deactivate Mechanic                  │
│    ├─→ Receive Service Requests                 │
│    ├─→ Assign Mechanic to Request               │
│    ├─→ Monitor Shop Operations                  │
│    ├─→ View Shop Statistics                     │
│    ├─→ View Earnings                            │
│    ├─→ Set Shop Status (Open/Closed)            │
│    ├─→ Manage Business Hours                    │
│    └─→ Respond to Reviews                       │
│                                                  │
└──────────────────────────────────────────────────┘
```

### **Admin Use Case Diagram**

```
                    RoadAid System
                         
┌──────────────────────────────────────────────────┐
│                                                  │
│  Admin                                           │
│    │                                             │
│    ├─→ Login to Admin Portal                    │
│    ├─→ Verify Mechanic Documents                │
│    ├─→ Verify Shop Business Permits             │
│    ├─→ Verify Cash Payments                     │
│    ├─→ Review User Reports                      │
│    ├─→ Resolve Disputes                         │
│    ├─→ Suspend/Ban Users                        │
│    ├─→ Monitor Platform Statistics              │
│    ├─→ Generate Reports                         │
│    ├─→ Manage System Settings                   │
│    ├─→ View Audit Logs                          │
│    ├─→ Manage Service Categories                │
│    ├─→ Manage Notification Templates            │
│    ├─→ Process Payout Requests                  │
│    └─→ Broadcast Announcements                  │
│                                                  │
└──────────────────────────────────────────────────┘
```

---

## 📋 USE CASE SUMMARY

### **Total Use Cases: 31**

| Actor | Number of Use Cases |
|-------|---------------------|
| Customer | 8 |
| Mechanic | 8 |
| Shop Owner | 7 |
| Admin | 6 |
| System (Automated) | 2 |

### **Use Case Priority**

| Priority | Use Cases |
|----------|-----------|
| **Critical** | UC-C03, UC-C04, UC-M02, UC-M04, UC-M05, UC-C06 |
| **High** | UC-C01, UC-M01, UC-S01, UC-A01, UC-A02 |
| **Medium** | UC-C07, UC-M06, UC-S04, UC-A03 |
| **Low** | UC-C08, UC-M07, UC-S05, UC-A05 |

---

## ✅ USE CASE VALIDATION CHECKLIST

- [x] All actors identified
- [x] All main flows documented
- [x] Alternative flows included
- [x] Exception flows handled
- [x] Preconditions defined
- [x] Postconditions defined
- [x] Business rules specified
- [x] System interactions documented
- [x] Use case diagrams created
- [x] Relationships mapped

---

**Document Status:** ✅ **COMPLETE**  
**Last Updated:** October 10, 2025  
**Version:** 1.0
