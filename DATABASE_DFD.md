# RoadAid System - Data Flow Diagram (DFD)

**Date:** October 10, 2025  
**System:** RoadAid - Roadside Assistance Platform  
**Database:** PostgreSQL (Supabase)

---

## 📊 DFD Level 0 (Context Diagram)

```
                    ┌─────────────────────────────────────┐
                    │                                     │
    Customer ──────>│                                     │<────── Mechanic
                    │                                     │
                    │         RoadAid System              │
                    │    (Roadside Assistance App)        │
                    │                                     │
  Talyer Owner ────>│                                     │<────── Admin
                    │                                     │
                    └─────────────────────────────────────┘
                                    │
                                    ▼
                          Payment Gateway (PayMongo)
```

### External Entities:
1. **Customer** - Requests roadside assistance services
2. **Mechanic** - Provides repair services
3. **Talyer Owner** - Manages shop and mechanics
4. **Admin** - Oversees platform operations
5. **Payment Gateway** - Processes online payments

---

## 📊 DFD Level 1 (Main Processes)

```
┌──────────┐                                                    ┌──────────┐
│ Customer │                                                    │ Mechanic │
└────┬─────┘                                                    └────┬─────┘
     │                                                                │
     │ Service Request                                                │
     │                                                                │
     ▼                                                                │
┌─────────────────────────────────┐                                  │
│   1.0 Service Request           │                                  │
│   Management                    │                                  │
└────────┬────────────────────────┘                                  │
         │                                                            │
         │ Request Details                                            │
         ▼                                                            │
┌─────────────────────────────────┐                                  │
│   2.0 Request Routing           │<─────────────────────────────────┘
│   & Broadcasting                │   Mechanic Location/Availability
└────────┬────────────────────────┘
         │
         │ Assigned Request
         ▼
┌─────────────────────────────────┐
│   3.0 Service Execution         │
│   & Tracking                    │
└────────┬────────────────────────┘
         │
         │ Service Completion
         ▼
┌─────────────────────────────────┐                    ┌──────────────┐
│   4.0 Billing & Payment         │<──────────────────>│ Payment      │
│   Processing                    │  Payment Details   │ Gateway      │
└────────┬────────────────────────┘                    └──────────────┘
         │
         │ Invoice & Payment
         ▼
┌─────────────────────────────────┐
│   5.0 Payment Release           │
│   Management                    │
└────────┬────────────────────────┘
         │
         │ Release Details
         ▼
┌─────────────────────────────────┐
│   6.0 History & Reviews         │
│   Management                    │
└─────────────────────────────────┘
```

---

## 📊 DFD Level 2 - Process 1.0: Service Request Management

```
┌──────────┐
│ Customer │
└────┬─────┘
     │
     │ Login Credentials
     ▼
┌─────────────────────────────────┐
│  1.1 Authenticate User          │────> D1: auth.users
└────────┬────────────────────────┘      D2: user_profiles
         │
         │ User Details
         ▼
┌─────────────────────────────────┐
│  1.2 Create Service Request     │
│  • Vehicle selection            │
│  • Service category             │
│  • Location details             │
│  • Problem description          │
└────────┬────────────────────────┘
         │
         │ Request Data ──────────────────> D3: service_requests
         │                                  D4: vehicles
         │                                  D5: service_categories
         ▼
┌─────────────────────────────────┐
│  1.3 Calculate Service Fee      │<─── D6: distance_pricing_config
│  • Distance calculation         │
│  • Service type pricing         │
│  • Emergency multiplier         │
└────────┬────────────────────────┘
         │
         │ Fee Details
         ▼
┌─────────────────────────────────┐
│  1.4 Determine Request Type     │
│  • Direct Mechanic              │
│  • Shop-based                   │
│  • Broadcast                    │
└────────┬────────────────────────┘
         │
         │ Request with Type ─────────────> D3: service_requests
         │
         ▼
     [Process 2.0]
```

### Data Stores Used:
- **D1: auth.users** - User authentication
- **D2: user_profiles** - Customer profile
- **D3: service_requests** - Service request records
- **D4: vehicles** - Customer vehicles
- **D5: service_categories** - Available services
- **D6: distance_pricing_config** - Pricing rules

---

## 📊 DFD Level 2 - Process 2.0: Request Routing & Broadcasting

```
[From Process 1.0]
         │
         │ Request Details
         ▼
┌─────────────────────────────────┐
│  2.1 Analyze Request Type       │<─── D3: service_requests
│  • Check request_type           │
│  • Get location details         │
└────────┬────────────────────────┘
         │
         ├─── Direct Mechanic ──────────────┐
         │                                  │
         ├─── Shop-based ──────────────┐    │
         │                             │    │
         └─── Broadcast ──────────┐    │    │
                                  │    │    │
                                  ▼    ▼    ▼
┌─────────────────────────────────────────────────────────┐
│  2.2 Find Eligible Providers                            │
│  • Calculate distances                                  │
│  • Check availability status                            │
│  • Filter by service radius                             │
└────────┬────────────────────────────────────────────────┘
         │                    │
         │                    └──> D7: service_providers
         │                         D8: shops
         │                         D9: mechanic_availability_status
         ▼
┌─────────────────────────────────┐
│  2.3 Create Broadcast Records   │
│  • Generate notifications       │
│  • Record distance              │
│  • Set expiration time          │
└────────┬────────────────────────┘
         │
         │ Broadcast Data ────────────────> D10: request_broadcasts
         │                                  D11: request_routing
         ▼
┌─────────────────────────────────┐
│  2.4 Send Notifications         │
│  • Push notifications           │
│  • In-app notifications         │
└────────┬────────────────────────┘
         │
         │ Notification Data ──────────────> D12: notifications
         │                                   D13: shop_notifications
         ▼
┌─────────────────────────────────┐
│  2.5 Receive Provider Response  │<─── Mechanic/Shop
│  • Accept/Decline               │
└────────┬────────────────────────┘
         │
         │ Response Status ────────────────> D10: request_broadcasts
         │                                   D3: service_requests
         ▼
┌─────────────────────────────────┐
│  2.6 Assign Provider            │
│  • Update request status        │
│  • Set assigned_mechanic_id     │
│  • Update availability          │
└────────┬────────────────────────┘
         │
         │ Assignment Data ────────────────> D3: service_requests
         │                                   D9: mechanic_availability_status
         ▼
     [Process 3.0]
```

### Data Stores Used:
- **D3: service_requests** - Request records
- **D7: service_providers** - Provider information
- **D8: shops** - Shop details
- **D9: mechanic_availability_status** - Real-time availability
- **D10: request_broadcasts** - Broadcast tracking
- **D11: request_routing** - Routing records
- **D12: notifications** - User notifications
- **D13: shop_notifications** - Shop notifications

---

## 📊 DFD Level 2 - Process 3.0: Service Execution & Tracking

```
[From Process 2.0]
         │
         │ Assigned Request
         ▼
┌─────────────────────────────────┐
│  3.1 Mechanic En Route          │
│  • Update status to 'en_route'  │
│  • Track mechanic location      │
└────────┬────────────────────────┘
         │
         │ Status Update ──────────────────> D3: service_requests
         │ Location Data ──────────────────> D2: user_profiles
         │
         ▼
┌─────────────────────────────────┐
│  3.2 Arrival Confirmation       │
│  • Update status to 'arrived'   │
│  • Capture arrival photo        │
└────────┬────────────────────────┘
         │
         │ Arrival Data ───────────────────> D3: service_requests
         │ Photo Upload ───────────────────> D14: progress_photos
         │
         ▼
┌─────────────────────────────────┐
│  3.3 Vehicle Inspection         │
│  • Document issues              │
│  • Capture inspection photos    │
│  • Update service phase         │
└────────┬────────────────────────┘
         │
         │ Inspection Data ────────────────> D14: progress_photos
         │ Phase Update ───────────────────> D15: service_phase_tracking
         │
         ▼
┌─────────────────────────────────┐
│  3.4 Service Execution          │
│  • Update to 'in_progress'      │
│  • Capture work photos          │
│  • Update progress              │
└────────┬────────────────────────┘
         │
         │ Work Progress ──────────────────> D3: service_requests
         │ Progress Photos ─────────────────> D14: progress_photos
         │
         ▼
┌─────────────────────────────────┐
│  3.5 Communication Handler      │
│  • Customer-Mechanic chat       │
│  • Send updates                 │
└────────┬────────────────────────┘
         │
         │ Messages ───────────────────────> D16: messages
         │ Notifications ──────────────────> D12: notifications
         │
         ▼
┌─────────────────────────────────┐
│  3.6 Service Completion         │
│  • Generate completion code     │
│  • Generate QR code             │
│  • Update status to 'completed' │
└────────┬────────────────────────┘
         │
         │ Completion Data ────────────────> D3: service_requests
         │ Completion Code ────────────────> D17: job_completion_codes
         │ QR Code ────────────────────────> D18: service_completions
         │
         ▼
┌─────────────────────────────────┐
│  3.7 Customer Verification      │
│  • Scan QR code                 │
│  • Verify completion code       │
└────────┬────────────────────────┘
         │
         │ Verification Status ────────────> D17: job_completion_codes
         │                                   D18: service_completions
         ▼
     [Process 4.0]
```

### Data Stores Used:
- **D2: user_profiles** - User locations
- **D3: service_requests** - Request status
- **D12: notifications** - Notifications
- **D14: progress_photos** - Service documentation
- **D15: service_phase_tracking** - Phase tracking
- **D16: messages** - Communications
- **D17: job_completion_codes** - Completion codes
- **D18: service_completions** - QR codes

---

## 📊 DFD Level 2 - Process 4.0: Billing & Payment Processing

```
[From Process 3.0]
         │
         │ Service Completion
         ▼
┌─────────────────────────────────┐
│  4.1 Generate Invoice           │
│  • Calculate total amount       │
│  • Calculate platform fee       │
│  • Calculate net amounts        │
└────────┬────────────────────────┘
         │
         │ Pricing Data ───────────────────> D3: service_requests
         │                                   D5: service_categories
         │                                   D6: distance_pricing_config
         │
         │ Invoice Data ───────────────────> D19: invoices
         │
         ▼
┌─────────────────────────────────┐
│  4.2 Send Invoice to Customer   │
│  • Email notification           │
│  • In-app notification          │
└────────┬────────────────────────┘
         │
         │ Notification ───────────────────> D12: notifications
         │ Email ──────────────────────────> D20: email_notifications
         │
         ▼
┌─────────────────────────────────┐
│  4.3 Customer Payment Selection │<─── Customer
│  • Cash payment                 │
│  • GCash                        │
│  • PayMaya                      │
└────────┬────────────────────────┘
         │
         ├─── Cash Payment ───────────────┐
         │                                │
         └─── Online Payment ─────────┐   │
                                      │   │
                                      ▼   ▼
┌─────────────────────────────────────────────────────────┐
│  4.4 Process Payment                                    │
│  • Cash: Capture photo evidence                         │
│  • Online: Send to PayMongo                             │
└────────┬────────────────────────────────────────────────┘
         │                    │
         │                    └──> Payment Gateway
         │                         (PayMongo)
         │
         │ Payment Details ────────────────> D21: payments
         │ Cash Verification ──────────────> D22: cash_payment_verifications
         │
         ▼
┌─────────────────────────────────┐
│  4.5 Update Invoice Status      │
│  • Mark as 'paid'               │
│  • Record payment method        │
│  • Update request status        │
└────────┬────────────────────────┘
         │
         │ Payment Status ─────────────────> D19: invoices
         │ Request Update ─────────────────> D3: service_requests
         │
         ▼
┌─────────────────────────────────┐
│  4.6 Verify Cash Payment        │<─── Admin
│  (If cash payment)              │
│  • Review photo evidence        │
│  • Approve/Reject               │
└────────┬────────────────────────┘
         │
         │ Verification Status ────────────> D22: cash_payment_verifications
         │
         ▼
     [Process 5.0]
```

### Data Stores Used:
- **D3: service_requests** - Service details
- **D5: service_categories** - Service pricing
- **D6: distance_pricing_config** - Distance fees
- **D12: notifications** - Payment notifications
- **D19: invoices** - Invoice records
- **D20: email_notifications** - Email logs
- **D21: payments** - Payment records
- **D22: cash_payment_verifications** - Cash verifications

---

## 📊 DFD Level 2 - Process 5.0: Payment Release Management

```
[From Process 4.0]
         │
         │ Payment Completion
         ▼
┌─────────────────────────────────┐
│  5.1 Create Release Request     │
│  • Calculate provider amount    │
│  • Calculate shop amount        │
│  • Calculate platform fee       │
└────────┬────────────────────────┘
         │
         │ Payment Data ───────────────────> D21: payments
         │ Invoice Data ───────────────────> D19: invoices
         │
         │ Release Request ─────────────────> D23: payment_releases
         │
         ▼
┌─────────────────────────────────┐
│  5.2 Admin Review & Approval    │<─── Admin
│  • Verify completion            │
│  • Check documentation          │
│  • Approve/Reject release       │
└────────┬────────────────────────┘
         │
         │ Review Data ─────────────────────> D3: service_requests
         │                                    D14: progress_photos
         │                                    D17: job_completion_codes
         │
         │ Approval Status ─────────────────> D23: payment_releases
         │ Activity Log ────────────────────> D24: admin_activity_logs
         │
         ▼
┌─────────────────────────────────┐
│  5.3 Process Payment Release    │
│  • Bank transfer                │
│  • GCash/PayMaya                │
│  • Update release status        │
└────────┬────────────────────────┘
         │
         │ Release Status ─────────────────> D23: payment_releases
         │
         ▼
┌─────────────────────────────────┐
│  5.4 Notify Provider            │
│  • Payment released             │
│  • Amount details               │
└────────┬────────────────────────┘
         │
         │ Notification ───────────────────> D12: notifications
         │ Email ──────────────────────────> D20: email_notifications
         │
         ▼
┌─────────────────────────────────┐
│  5.5 Update Earnings Records    │
│  • Shop earnings                │
│  • Mechanic earnings            │
│  • Platform earnings            │
└────────┬────────────────────────┘
         │
         │ Earnings Data ──────────────────> D8: shops
         │                                   D7: service_providers
         │
         ▼
     [Process 6.0]
```

### Data Stores Used:
- **D3: service_requests** - Completion verification
- **D7: service_providers** - Provider earnings
- **D8: shops** - Shop earnings
- **D12: notifications** - Release notifications
- **D14: progress_photos** - Completion proof
- **D17: job_completion_codes** - Verification codes
- **D19: invoices** - Invoice details
- **D20: email_notifications** - Email logs
- **D21: payments** - Payment details
- **D23: payment_releases** - Release records
- **D24: admin_activity_logs** - Admin actions

---

## 📊 DFD Level 2 - Process 6.0: History & Reviews Management

```
[From Process 5.0]
         │
         │ Service & Payment Complete
         ▼
┌─────────────────────────────────┐
│  6.1 Create Job History         │
│  • Mechanic job record          │
│  • Customer job record          │
└────────┬────────────────────────┘
         │
         │ Request Data ───────────────────> D3: service_requests
         │ Payment Data ───────────────────> D19: invoices
         │ Provider Data ──────────────────> D7: service_providers
         │
         │ History Records ─────────────────> D25: mechanic_job_history
         │                                    D26: customer_job_history
         │
         ▼
┌─────────────────────────────────┐
│  6.2 Request Customer Review    │
│  • Send notification            │
│  • In-app prompt                │
└────────┬────────────────────────┘
         │
         │ Review Request ─────────────────> D12: notifications
         │
         ▼
┌─────────────────────────────────┐
│  6.3 Submit Rating & Review     │<─── Customer
│  • Rate mechanic (1-5 stars)    │
│  • Write review text            │
└────────┬────────────────────────┘
         │
         │ Review Data ─────────────────────> D27: reviews
         │
         ▼
┌─────────────────────────────────┐
│  6.4 Update Provider Rating     │
│  • Calculate average rating     │
│  • Update mechanic profile      │
│  • Update shop profile          │
└────────┬────────────────────────┘
         │
         │ Rating Updates ─────────────────> D7: service_providers
         │                                   D8: shops
         │                                   D2: user_profiles
         │
         ▼
┌─────────────────────────────────┐
│  6.5 Update History with Review │
│  • Add rating to job history    │
│  • Add review text              │
└────────┬────────────────────────┘
         │
         │ Updated History ────────────────> D25: mechanic_job_history
         │                                   D26: customer_job_history
         │
         ▼
┌─────────────────────────────────┐
│  6.6 Generate Analytics         │
│  • Provider performance         │
│  • Service quality metrics      │
│  • Customer satisfaction        │
└────────┬────────────────────────┘
         │
         │ Analytics Data ─────────────────> D28: audit_logs
         │
         ▼
         [End]
```

### Data Stores Used:
- **D2: user_profiles** - User ratings
- **D3: service_requests** - Service details
- **D7: service_providers** - Provider ratings
- **D8: shops** - Shop ratings
- **D12: notifications** - Review requests
- **D19: invoices** - Payment details
- **D25: mechanic_job_history** - Mechanic records
- **D26: customer_job_history** - Customer records
- **D27: reviews** - Review records
- **D28: audit_logs** - Analytics

---

## 📋 Complete Data Store Inventory

| ID | Data Store | Description |
|----|------------|-------------|
| D1 | auth.users | User authentication records |
| D2 | user_profiles | User profile information |
| D3 | service_requests | Service request records |
| D4 | vehicles | Customer vehicle records |
| D5 | service_categories | Available service types |
| D6 | distance_pricing_config | Pricing configuration |
| D7 | service_providers | Provider profiles |
| D8 | shops | Shop information |
| D9 | mechanic_availability_status | Real-time availability |
| D10 | request_broadcasts | Broadcast notifications |
| D11 | request_routing | Request routing records |
| D12 | notifications | User notifications |
| D13 | shop_notifications | Shop-specific notifications |
| D14 | progress_photos | Service documentation photos |
| D15 | service_phase_tracking | Service phase tracking |
| D16 | messages | Customer-mechanic messages |
| D17 | job_completion_codes | Completion verification codes |
| D18 | service_completions | QR code completions |
| D19 | invoices | Invoice records |
| D20 | email_notifications | Email notification logs |
| D21 | payments | Payment transaction records |
| D22 | cash_payment_verifications | Cash payment verifications |
| D23 | payment_releases | Payment release records |
| D24 | admin_activity_logs | Admin action logs |
| D25 | mechanic_job_history | Mechanic job history |
| D26 | customer_job_history | Customer job history |
| D27 | reviews | Rating and review records |
| D28 | audit_logs | System audit logs |

---

## 🔄 Main Data Flows Summary

### 1. **Service Request Flow**
```
Customer → Authentication → Create Request → Calculate Fee → Determine Type → Route/Broadcast
```

### 2. **Provider Assignment Flow**
```
Broadcast → Find Eligible Providers → Send Notifications → Receive Response → Assign Provider
```

### 3. **Service Execution Flow**
```
En Route → Arrival → Inspection → Work Progress → Completion → Customer Verification
```

### 4. **Payment Flow**
```
Generate Invoice → Send to Customer → Payment Selection → Process Payment → Verify (if cash)
```

### 5. **Payment Release Flow**
```
Create Release Request → Admin Review → Process Release → Notify Provider → Update Earnings
```

### 6. **Review & History Flow**
```
Create Job History → Request Review → Submit Rating → Update Provider Rating → Analytics
```

---

## 🎯 Key Data Transformation Points

### 1. **Service Fee Calculation**
- **Input:** Customer location, service category, distance
- **Process:** Apply distance pricing, service type multiplier, emergency rate
- **Output:** Estimated service fee
- **Data Stores:** D6 (distance_pricing_config), D5 (service_categories)

### 2. **Provider Selection Algorithm**
- **Input:** Request location, service type, provider availability
- **Process:** Calculate distances, filter by radius, check availability
- **Output:** List of eligible providers
- **Data Stores:** D7 (service_providers), D8 (shops), D9 (mechanic_availability_status)

### 3. **Invoice Generation**
- **Input:** Service request, completion data, payment method
- **Process:** Calculate subtotal, platform fee, net amounts
- **Output:** Invoice with breakdown
- **Data Stores:** D3 (service_requests), D19 (invoices)

### 4. **Payment Split Calculation**
- **Input:** Total amount, service type, provider type
- **Process:** Calculate platform fee, shop share, mechanic share
- **Output:** Payment breakdown
- **Data Stores:** D19 (invoices), D21 (payments), D23 (payment_releases)

### 5. **Rating Aggregation**
- **Input:** Individual review rating
- **Process:** Calculate average rating across all reviews
- **Output:** Updated provider/shop rating
- **Data Stores:** D27 (reviews), D7 (service_providers), D8 (shops)

---

## 🔐 Security & Control Flows

### Authentication Flow
```
User Login → Verify Credentials → Generate Session → Grant Access
```

### Authorization Flow
```
User Action → Check Role → Verify Permissions → Allow/Deny
```

### Audit Trail Flow
```
Action Performed → Log Details → Store in Audit Log → Generate Report
```

---

## 📊 Real-Time Data Flows

### 1. **Location Tracking**
```
Mechanic App → GPS Coordinates → Update Location → Customer Map View
```

### 2. **Status Updates**
```
Status Change → Update Database → Trigger Notification → Push to User
```

### 3. **Chat Messages**
```
Send Message → Store in DB → Real-time Sync → Recipient Device
```

---

## 🎯 External System Interactions

### PayMongo Payment Gateway
```
Customer Payment → RoadAid Backend → PayMongo API → Process Payment → 
Webhook Callback → Update Payment Status → Notify Customer
```

### Push Notification Service
```
Event Trigger → Generate Notification → Firebase Cloud Messaging → 
Deliver to Device → Update Read Status
```

### Email Service
```
Event Trigger → Generate Email → Supabase Email → Send to Recipient → 
Log Delivery Status
```

---

## 📈 Analytics & Reporting Flows

### Dashboard Data Flow
```
User Request → Query Database → Aggregate Data → Calculate Metrics → Display Dashboard
```

### Report Generation Flow
```
Admin Request → Define Parameters → Query Historical Data → 
Generate Report → Export/Download
```

---

## 🎯 Error Handling Flows

### Payment Failure Flow
```
Payment Failed → Log Error → Notify Customer → Retry Option → 
Update Request Status → Admin Alert
```

### Service Cancellation Flow
```
Cancel Request → Update Status → Notify Provider → Process Refund (if paid) → 
Update History → Log Cancellation
```

---

**Legend:**
- **→** Data flow direction
- **[Process]** Main process
- **D#** Data store reference
- **←** Data read/query
- **──>** Data write/update

---

**DFD Design Principles:**
1. ✅ Clear separation of processes
2. ✅ Well-defined data flows
3. ✅ Proper data store usage
4. ✅ External entity interactions
5. ✅ Real-time and batch processing
6. ✅ Security and audit controls
7. ✅ Error handling flows
8. ✅ Multi-level decomposition
