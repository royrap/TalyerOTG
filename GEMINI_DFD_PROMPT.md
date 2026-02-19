# 📊 Gemini AI Prompt - RoadAid DFD (Context, Level 1, Level 2)

---

## 🎯 PROMPT 1: CONTEXT DIAGRAM (LEVEL 0)

Copy this to Gemini:

```
Create a DFD Context Diagram (Level 0) for "RoadAid" - a Roadside Assistance Mobile Application.

=== DFD NOTATION RULES ===
- External Entities: RECTANGLES (sources/destinations of data)
- Process: ONE CIRCLE/ROUNDED RECTANGLE labeled "0 - RoadAid System"
- Data Flows: ARROWS with labels (noun phrases)
- NO data stores at Context Level

=== EXTERNAL ENTITIES (5 total) ===

1. CUSTOMER (Rectangle - Left Side)
   - Description: Mobile app user requesting roadside assistance

2. MECHANIC (Rectangle - Right Side)
   - Description: Service provider who performs repairs

3. TALYER OWNER (Rectangle - Top Right)
   - Description: Shop owner managing mechanics and services

4. ADMIN (Rectangle - Top Left)
   - Description: System administrator managing platform

5. PAYMONGO (Rectangle - Bottom)
   - Description: External payment gateway for online transactions


=== CENTRAL PROCESS ===
Circle/Rounded Rectangle in CENTER:
"0"
"RoadAid System"


=== DATA FLOWS (Arrows with Labels) ===

FROM CUSTOMER → RoadAid System:
- Service Request
- Vehicle Information
- Location Data
- Payment Information
- Review/Rating
- Completion Code Scan

FROM RoadAid System → CUSTOMER:
- Service Confirmation
- Mechanic Details
- Real-time Status Updates
- Invoice/Receipt
- Notifications
- Job History

FROM MECHANIC → RoadAid System:
- Availability Status
- Service Acceptance
- Progress Updates
- Completion Report
- Location Updates

FROM RoadAid System → MECHANIC:
- Service Request Notification
- Customer Details
- Job Assignment
- Earnings Report
- Notifications

FROM TALYER OWNER → RoadAid System:
- Shop Registration
- Mechanic Management
- Service Pricing
- Business Hours

FROM RoadAid System → TALYER OWNER:
- Shop Performance Report
- Mechanic Activity
- Revenue Report
- Verification Status

FROM ADMIN → RoadAid System:
- User Verification
- System Configuration
- Payment Release Approval

FROM RoadAid System → ADMIN:
- Audit Logs
- System Reports
- Pending Verifications

FROM PAYMONGO → RoadAid System:
- Payment Confirmation
- Transaction Status

FROM RoadAid System → PAYMONGO:
- Payment Request
- Transaction Details


=== LAYOUT ===
- Place CUSTOMER on LEFT
- Place MECHANIC on RIGHT
- Place TALYER OWNER on TOP-RIGHT
- Place ADMIN on TOP-LEFT
- Place PAYMONGO on BOTTOM
- Central process "RoadAid System" in the MIDDLE
- All arrows should be labeled with data flow names
- Use straight lines, avoid crossing

Title: "RoadAid System - Context Diagram (Level 0)"
```

---

## 🎯 PROMPT 2: LEVEL 1 DFD

Copy this to Gemini:

```
Create a DFD Level 1 Diagram for "RoadAid" - a Roadside Assistance Mobile Application.

=== DFD NOTATION RULES ===
- External Entities: RECTANGLES (same as Context Diagram)
- Processes: CIRCLES with number and name (1.0, 2.0, 3.0, etc.)
- Data Stores: OPEN-ENDED RECTANGLES (two parallel lines) labeled D1, D2, D3, etc.
- Data Flows: ARROWS with labels (noun phrases describing data)

=== EXTERNAL ENTITIES (5 total) ===
1. CUSTOMER (Rectangle)
2. MECHANIC (Rectangle)
3. TALYER OWNER (Rectangle)
4. ADMIN (Rectangle)
5. PAYMONGO (Rectangle)


=== PROCESSES (8 total) ===

Process 1.0 - USER MANAGEMENT
- Handles registration, login, profile management
- Manages authentication and user verification

Process 2.0 - VEHICLE MANAGEMENT
- Manages customer vehicles
- Stores vehicle information for service requests

Process 3.0 - SHOP & SERVICE MANAGEMENT
- Manages shop registration and services
- Handles mechanic assignments to shops
- Manages service categories and pricing

Process 4.0 - SERVICE REQUEST PROCESSING
- Creates and manages service requests
- Handles request broadcasting to nearby providers
- Assigns mechanics to requests

Process 5.0 - REAL-TIME TRACKING
- Tracks mechanic location
- Provides status updates to customers
- Manages progress photos

Process 6.0 - JOB COMPLETION
- Generates completion codes
- Verifies service completion via QR scan
- Records job history

Process 7.0 - PAYMENT PROCESSING
- Generates invoices
- Processes online and cash payments
- Handles payment verification

Process 8.0 - REVIEW & RATING
- Collects customer reviews
- Calculates provider ratings
- Manages feedback


=== DATA STORES (12 total) ===

D1 - USER_DATA
(user_profiles)

D2 - VEHICLE_DATA
(vehicles)

D3 - SHOP_DATA
(shops, shop_services, shop_mechanics)

D4 - SERVICE_PROVIDER_DATA
(service_providers, mechanic_availability_status)

D5 - SERVICE_REQUEST_DATA
(service_requests, request_broadcasts, request_routing, request_status_history)

D6 - CATEGORY_DATA
(service_categories)

D7 - NOTIFICATION_DATA
(notifications)

D8 - LOCATION_DATA
(user_locations)

D9 - INVOICE_DATA
(invoices)

D10 - PAYMENT_DATA
(payments)

D11 - VERIFICATION_DATA
(talyer_owner_verifications)

D12 - INSPECTION_DATA
(inspection_reports)


=== DATA FLOWS ===

CUSTOMER flows:
- Customer → 1.0: Registration Data, Login Credentials
- 1.0 → Customer: Authentication Result, Profile Data
- Customer → 2.0: Vehicle Details
- 2.0 → Customer: Vehicle List
- Customer → 4.0: Service Request, Location
- 4.0 → Customer: Request Confirmation, Mechanic Assignment
- 5.0 → Customer: Status Updates, Mechanic Location
- Customer → 6.0: Completion Code Scan
- 7.0 → Customer: Invoice, Payment Receipt
- Customer → 7.0: Payment Information
- Customer → 8.0: Review Data
- 8.0 → Customer: Review Confirmation

MECHANIC flows:
- Mechanic → 1.0: Registration Data
- 1.0 → Mechanic: Profile Data
- 4.0 → Mechanic: Service Request Notification
- Mechanic → 4.0: Request Acceptance
- Mechanic → 5.0: Location Updates, Progress Photos
- 5.0 → Mechanic: Navigation Data
- Mechanic → 6.0: Completion Report
- 6.0 → Mechanic: Completion Verification
- 7.0 → Mechanic: Earnings Report

TALYER OWNER flows:
- Talyer Owner → 1.0: Registration Data, Verification Documents
- 1.0 → Talyer Owner: Verification Status
- Talyer Owner → 3.0: Shop Details, Service Pricing, Mechanic Data
- 3.0 → Talyer Owner: Shop Performance, Mechanic Status

ADMIN flows:
- Admin → 1.0: Verification Approval
- 1.0 → Admin: Pending Verifications
- Admin → 7.0: Payment Release Approval
- 7.0 → Admin: Payment Reports

PAYMONGO flows:
- 7.0 → PayMongo: Payment Request
- PayMongo → 7.0: Payment Confirmation


=== DATA STORE CONNECTIONS ===

D1 (USER_DATA):
- 1.0 ↔ D1 (read/write user profiles)
- 4.0 → D1 (read customer/mechanic info)
- 6.0 → D1 (read user info for completion)

D2 (VEHICLE_DATA):
- 2.0 ↔ D2 (read/write vehicles)
- 4.0 → D2 (read vehicle for request)

D3 (SHOP_DATA):
- 3.0 ↔ D3 (read/write shops, services, mechanics)
- 4.0 → D3 (read available shops)

D4 (SERVICE_PROVIDER_DATA):
- 1.0 → D4 (write provider registration)
- 3.0 ↔ D4 (read/write provider data, availability status)
- 4.0 → D4 (read available providers)
- 5.0 ↔ D4 (update mechanic availability status)

D5 (SERVICE_REQUEST_DATA):
- 4.0 ↔ D5 (read/write requests, broadcasts, routing)
- 5.0 ↔ D5 (update status history)
- 6.0 → D5 (update completion status)
- 7.0 → D5 (read for invoice)

D6 (CATEGORY_DATA):
- 3.0 ↔ D6 (read/write categories)
- 4.0 → D6 (read for request)

D7 (NOTIFICATION_DATA):
- 4.0 → D7 (write request notifications)
- 5.0 → D7 (write status notifications)
- 6.0 → D7 (write completion notifications)

D8 (LOCATION_DATA):
- 5.0 ↔ D8 (read/write user locations for tracking)
- 4.0 → D8 (read location for nearby search)

D9 (INVOICE_DATA):
- 7.0 ↔ D9 (read/write invoices)

D10 (PAYMENT_DATA):
- 7.0 ↔ D10 (read/write payments)

D11 (VERIFICATION_DATA):
- 1.0 ↔ D11 (read/write talyer owner verifications)
- Admin verifies through 1.0

D12 (INSPECTION_DATA):
- 6.0 ↔ D12 (read/write inspection reports)


=== LAYOUT INSTRUCTIONS ===
- ALL PROCESSES (circles 1.0 to 8.0) must be arranged in a SINGLE VERTICAL COLUMN in the CENTER of the diagram
- Arrange processes from TOP to BOTTOM in this order:
  * 1.0 USER MANAGEMENT (top)
  * 2.0 VEHICLE MANAGEMENT
  * 3.0 SHOP & SERVICE MANAGEMENT
  * 4.0 SERVICE REQUEST PROCESSING
  * 5.0 REAL-TIME TRACKING
  * 6.0 JOB COMPLETION
  * 7.0 PAYMENT PROCESSING
  * 8.0 REVIEW & RATING (bottom)
- External entities (rectangles) on the EDGES ONLY:
  * ADMIN - Top left corner
  * TALYER OWNER - Top right corner
  * CUSTOMER - Left side (middle)
  * MECHANIC - Right side (middle)
  * PAYMONGO - Bottom center
- Data stores (open-ended rectangles D1-D12) positioned on LEFT and RIGHT sides, between the processes and external entities
- Connect external entities to the CENTER column of processes
- Connect processes to data stores on the sides
- Use ORTHOGONAL (90-degree) connectors for all lines
- MINIMIZE line crossings
- Label ALL data flows with noun phrases
- Keep the diagram BALANCED - data stores evenly distributed left and right

Title: "RoadAid System - Level 1 DFD"
```

---

## 🎯 PROMPT 3: LEVEL 2 DFD - SERVICE REQUEST PROCESSING (Process 4.0)

Copy this to Gemini:

```
Create a DFD Level 2 Diagram for "Process 4.0 - Service Request Processing" of RoadAid System.

=== DFD NOTATION RULES ===
- Processes: CIRCLES numbered 4.1, 4.2, 4.3, etc.
- Data Stores: OPEN-ENDED RECTANGLES (D5, etc.)
- External Entities: RECTANGLES
- Data Flows: ARROWS with labels

=== SUB-PROCESSES (6 total) ===

Process 4.1 - VALIDATE REQUEST
- Validates customer input
- Checks vehicle and location data
- Verifies service category

Process 4.2 - FIND NEARBY PROVIDERS
- Calculates distance to available shops/mechanics
- Filters by service radius
- Checks business hours and availability

Process 4.3 - BROADCAST REQUEST
- Sends request to eligible providers
- Creates broadcast records
- Manages notification delivery

Process 4.4 - RECEIVE RESPONSE
- Handles provider acceptance/rejection
- Tracks response time
- Updates broadcast status

Process 4.5 - ASSIGN MECHANIC
- Assigns accepted mechanic to request
- Updates request status
- Notifies customer of assignment

Process 4.6 - UPDATE REQUEST STATUS
- Manages request lifecycle
- Handles cancellations
- Updates status in real-time


=== DATA STORES ===

D1 - USER_DATA (from Level 1)
D2 - VEHICLE_DATA (from Level 1)
D3 - SHOP_DATA (from Level 1)
D4 - SERVICE_PROVIDER_DATA (from Level 1)
D5 - SERVICE_REQUEST_DATA (from Level 1)
D6 - CATEGORY_DATA (from Level 1)
D7 - NOTIFICATION_DATA (from Level 1)
D8 - LOCATION_DATA (from Level 1)


=== EXTERNAL ENTITIES ===
- CUSTOMER
- MECHANIC


=== DATA FLOWS ===

FROM CUSTOMER:
- Customer → 4.1: Service Request Data (service type, description, location)

TO CUSTOMER:
- 4.1 → Customer: Validation Result
- 4.2 → Customer: Available Providers List
- 4.5 → Customer: Assignment Confirmation
- 4.6 → Customer: Status Update

FROM/TO MECHANIC:
- 4.3 → Mechanic: Request Broadcast Notification
- Mechanic → 4.4: Response (Accept/Reject)
- 4.5 → Mechanic: Assignment Details

BETWEEN PROCESSES:
- 4.1 → 4.2: Validated Request
- 4.2 → 4.3: Nearby Provider List
- 4.3 → 4.4: Broadcast Record
- 4.4 → 4.5: Accepted Response
- 4.5 → 4.6: Assigned Request

DATA STORE CONNECTIONS:
- 4.1 → D1: Read Customer Data
- 4.1 → D2: Read Vehicle Data
- 4.1 → D6: Read Service Category
- 4.1 → D5: Write New Request
- 4.2 → D3: Read Shop Data (location, radius, hours)
- 4.2 → D4: Read Provider Data (availability, location)
- 4.2 → D8: Read User Locations
- 4.3 → D5: Write Broadcast Records, Request Routing
- 4.3 → D7: Write Notifications
- 4.4 → D5: Update Broadcast Response
- 4.5 → D5: Update Request Assignment
- 4.5 → D7: Write Assignment Notification
- 4.6 → D5: Update Request Status History


=== LAYOUT ===
- ALL PROCESSES (circles 4.1 to 4.6) arranged in a SINGLE VERTICAL COLUMN in the CENTER
- Order from TOP to BOTTOM: 4.1 → 4.2 → 4.3 → 4.4 → 4.5 → 4.6
- External entities on EDGES:
  * CUSTOMER - Left side
  * MECHANIC - Right side
- Data stores (D1, D2, D3, D4, D5, D6, D7, D8) on LEFT and RIGHT sides
- Use ORTHOGONAL (90-degree) connectors
- MINIMIZE line crossings
- Label ALL data flows

Title: "RoadAid - Level 2 DFD: Service Request Processing (4.0)"
```

---

## 🎯 PROMPT 4: LEVEL 2 DFD - PAYMENT PROCESSING (Process 7.0)

Copy this to Gemini:

```
Create a DFD Level 2 Diagram for "Process 7.0 - Payment Processing" of RoadAid System.

=== DFD NOTATION RULES ===
- Processes: CIRCLES numbered 7.1, 7.2, 7.3, etc.
- Data Stores: OPEN-ENDED RECTANGLES
- External Entities: RECTANGLES
- Data Flows: ARROWS with labels

=== SUB-PROCESSES (6 total) ===

Process 7.1 - GENERATE INVOICE
- Calculates service fees
- Applies platform fees
- Creates invoice record

Process 7.2 - SELECT PAYMENT METHOD
- Presents payment options (Cash, GCash, Card)
- Records selected method

Process 7.3 - PROCESS ONLINE PAYMENT
- Sends payment request to PayMongo
- Handles payment gateway response
- Records transaction

Process 7.4 - VERIFY CASH PAYMENT
- Captures cash payment photo
- Records cash verification
- Updates payment status

Process 7.5 - CALCULATE EARNINGS
- Computes mechanic share
- Computes shop share
- Computes platform fee

Process 7.6 - RELEASE PAYMENT
- Admin approval for release
- Processes payout to provider
- Updates release status


=== DATA STORES ===

D5 - SERVICE_REQUEST_DATA
D9 - INVOICE_DATA
D10 - PAYMENT_DATA


=== EXTERNAL ENTITIES ===
- CUSTOMER
- MECHANIC
- ADMIN
- PAYMONGO


=== DATA FLOWS ===

FROM/TO CUSTOMER:
- 7.1 → Customer: Invoice Details
- Customer → 7.2: Payment Method Selection
- Customer → 7.3: Payment Authorization
- 7.3 → Customer: Payment Receipt
- Customer → 7.4: Cash Photo

FROM/TO MECHANIC:
- 7.1 → Mechanic: Invoice Copy
- 7.5 → Mechanic: Earnings Statement
- 7.6 → Mechanic: Payment Release Confirmation

FROM/TO ADMIN:
- 7.4 → Admin: Cash Verification Request
- Admin → 7.6: Release Approval
- 7.6 → Admin: Release Report

FROM/TO PAYMONGO:
- 7.3 → PayMongo: Payment Request
- PayMongo → 7.3: Payment Confirmation

BETWEEN PROCESSES:
- 7.1 → 7.2: Invoice Record
- 7.2 → 7.3: Online Payment Selection
- 7.2 → 7.4: Cash Payment Selection
- 7.3 → 7.5: Completed Online Payment
- 7.4 → 7.5: Verified Cash Payment
- 7.5 → 7.6: Calculated Earnings

DATA STORE CONNECTIONS:
- 7.1 → D5: Read Request Data
- 7.1 → D9: Write Invoice
- 7.2 → D9: Update Payment Method
- 7.3 → D10: Write Payment Record
- 7.4 → D10: Write Cash Verification
- 7.5 → D10: Update Earnings
- 7.6 → D10: Update Release Status


=== LAYOUT ===
- ALL PROCESSES (circles 7.1 to 7.6) arranged in a SINGLE VERTICAL COLUMN in the CENTER
- Order from TOP to BOTTOM: 7.1 → 7.2 → 7.3/7.4 (side by side for branching) → 7.5 → 7.6
- External entities on EDGES:
  * CUSTOMER - Left side
  * MECHANIC - Right side
  * ADMIN - Top
  * PAYMONGO - Bottom
- Data stores (D5, D9, D10) on LEFT and RIGHT sides
- Use ORTHOGONAL (90-degree) connectors
- MINIMIZE line crossings
- Label ALL data flows

Title: "RoadAid - Level 2 DFD: Payment Processing (7.0)"
```

---

## 🎯 PROMPT 5: LEVEL 2 DFD - JOB COMPLETION (Process 6.0)

Copy this to Gemini:

```
Create a DFD Level 2 Diagram for "Process 6.0 - Job Completion" of RoadAid System.

=== DFD NOTATION RULES ===
- Processes: CIRCLES numbered 6.1, 6.2, 6.3, etc.
- Data Stores: OPEN-ENDED RECTANGLES
- External Entities: RECTANGLES
- Data Flows: ARROWS with labels

=== SUB-PROCESSES (5 total) ===

Process 6.1 - GENERATE COMPLETION CODE
- Creates unique 6-digit code
- Generates QR code data
- Sets expiration time

Process 6.2 - VERIFY COMPLETION
- Customer scans QR code
- Validates completion code
- Confirms service completion

Process 6.3 - RECORD COMPLETION
- Updates request status to completed
- Records completion timestamp
- Marks code as used

Process 6.4 - CREATE JOB HISTORY
- Creates mechanic job history record
- Creates customer job history record
- Stores completion details

Process 6.5 - TRIGGER NEXT STEPS
- Triggers invoice generation
- Triggers review request
- Sends completion notifications


=== DATA STORES ===

D1 - USER_DATA
D5 - SERVICE_REQUEST_DATA
D7 - NOTIFICATION_DATA
D12 - INSPECTION_DATA


=== EXTERNAL ENTITIES ===
- CUSTOMER
- MECHANIC


=== DATA FLOWS ===

FROM/TO CUSTOMER:
- 6.1 → Customer: QR Code Display
- Customer → 6.2: Scanned Code
- 6.2 → Customer: Verification Result
- 6.5 → Customer: Completion Notification

FROM/TO MECHANIC:
- Mechanic → 6.1: Completion Request
- 6.1 → Mechanic: Completion Code
- 6.3 → Mechanic: Completion Confirmation
- 6.5 → Mechanic: Completion Notification

BETWEEN PROCESSES:
- 6.1 → 6.2: Generated Code Record
- 6.2 → 6.3: Verified Completion
- 6.3 → 6.4: Completion Record
- 6.4 → 6.5: History Created

DATA STORE CONNECTIONS:
- 6.1 → D5: Read Request Data
- 6.1 → D5: Write Completion Code to Request
- 6.2 → D5: Read/Update Code Status
- 6.3 → D5: Update Request Status History
- 6.4 → D1: Read User Data
- 6.4 → D12: Write Inspection Report
- 6.5 → D7: Write Completion Notifications


=== LAYOUT ===
- ALL PROCESSES (circles 6.1 to 6.5) arranged in a SINGLE VERTICAL COLUMN in the CENTER
- Order from TOP to BOTTOM: 6.1 → 6.2 → 6.3 → 6.4 → 6.5
- External entities on EDGES:
  * CUSTOMER - Left side
  * MECHANIC - Right side
- Data stores (D1, D5, D7, D12) on LEFT and RIGHT sides
- Use ORTHOGONAL (90-degree) connectors
- MINIMIZE line crossings
- Label ALL data flows

Title: "RoadAid - Level 2 DFD: Job Completion (6.0)"
```

---

## 📋 DFD SUMMARY TABLE

| Level | Diagram | Processes | Data Stores | External Entities |
|-------|---------|-----------|-------------|-------------------|
| 0 | Context | 1 (RoadAid System) | 0 | 5 |
| 1 | Level 1 | 8 | 12 | 5 |
| 2 | Service Request (4.0) | 6 | 6 | 2 |
| 2 | Payment (7.0) | 6 | 3 | 4 |
| 2 | Job Completion (6.0) | 5 | 4 | 2 |

---

## 📊 ERD TO DFD MAPPING (17 Tables → 12 Data Stores)

| Data Store | Tables from ERD |
|------------|-----------------|
| D1 - USER_DATA | user_profiles |
| D2 - VEHICLE_DATA | vehicles |
| D3 - SHOP_DATA | shops, shop_services, shop_mechanics |
| D4 - SERVICE_PROVIDER_DATA | service_providers, mechanic_availability_status |
| D5 - SERVICE_REQUEST_DATA | service_requests, request_broadcasts, request_routing, request_status_history |
| D6 - CATEGORY_DATA | service_categories |
| D7 - NOTIFICATION_DATA | notifications |
| D8 - LOCATION_DATA | user_locations |
| D9 - INVOICE_DATA | invoices |
| D10 - PAYMENT_DATA | payments |
| D11 - VERIFICATION_DATA | talyer_owner_verifications |
| D12 - INSPECTION_DATA | inspection_reports |

**Total: 17 tables grouped into 12 logical data stores**

---

## ✅ DFD RULES CHECKLIST

- [ ] External entities are RECTANGLES
- [ ] Processes are CIRCLES with numbers
- [ ] Data stores are OPEN-ENDED RECTANGLES (D1, D2, etc.)
- [ ] All flows are LABELED with noun phrases
- [ ] No data flow between two external entities
- [ ] No data flow between two data stores
- [ ] No data flow directly from external entity to data store
- [ ] Every process has at least one input and one output
- [ ] Parent process = sum of child processes
- [ ] Data stores only appear at Level 1 and below

---

**Document Created:** January 19, 2026
