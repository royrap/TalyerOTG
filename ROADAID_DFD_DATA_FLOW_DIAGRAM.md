# 📊 ROADAID SYSTEM - DATA FLOW DIAGRAM (DFD)

## 🎯 SYSTEM OVERVIEW

**RoadAid** ay isang on-demand auto repair assistance platform na nag-kokonekta ng customers sa mechanics at talyer owners para sa emergency at regular vehicle repairs.

---

## 🔄 CONTEXT DIAGRAM (Level 0 DFD)

```
┌──────────────┐
│   CUSTOMER   │
│  (Motorist)  │
└──────┬───────┘
       │
       │ Service Request
       │ Payment
       │ Vehicle Info
       ↓
┌─────────────────────────────────────────┐
│                                         │
│         ROADAID SYSTEM                  │
│   (Auto Repair Assistance Platform)    │
│                                         │
└────┬──────────┬──────────┬──────────────┘
     │          │          │
     │          │          └─────────────────┐
     ↓          ↓                            ↓
┌─────────┐  ┌──────────┐           ┌──────────────┐
│MECHANIC │  │  TALYER  │           │   PAYMONGO   │
│         │  │  OWNER   │           │  (Payment)   │
└─────────┘  └──────────┘           └──────────────┘
     │             │                        │
     │             │                        │
     └─────────────┴────────────────────────┘
                   │
                   ↓
           ┌──────────────┐
           │   SUPABASE   │
           │  (Database)  │
           └──────────────┘
```

**External Entities:**
1. **Customer** - Motorists na nangangailangan ng repair service
2. **Mechanic** - Professional mechanics na gumagawa ng repair
3. **Talyer Owner** - Mga may-ari ng auto repair shops
4. **PayMongo** - Third-party payment processor
5. **Supabase** - Database at authentication provider

---

## 📋 LEVEL 1 DFD - MAIN PROCESSES

```
                    ┌────────────────────┐
                    │    CUSTOMER        │
                    └────────┬───────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ↓                    ↓                    ↓
┌─────────────┐      ┌──────────────┐    ┌──────────────┐
│  1.0        │      │  2.0         │    │  3.0         │
│ USER        │      │ SERVICE      │    │ VEHICLE      │
│ MANAGEMENT  │      │ REQUEST      │    │ MANAGEMENT   │
│             │      │ PROCESSING   │    │              │
└──────┬──────┘      └──────┬───────┘    └──────┬───────┘
       │                    │                    │
       │                    │                    │
       ↓                    ↓                    ↓
┌─────────────────────────────────────────────────────┐
│              DATABASE (Supabase)                    │
│  user_profiles | service_requests | vehicles        │
└──────┬──────────────────┬───────────────┬───────────┘
       │                  │               │
       ↓                  ↓               ↓
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  4.0         │  │  5.0         │  │  6.0         │
│ SHOP &       │  │ MECHANIC     │  │ PAYMENT      │
│ MECHANIC     │  │ DISPATCH &   │  │ PROCESSING   │
│ MANAGEMENT   │  │ TRACKING     │  │              │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                  │
       │                 │                  │
       ↓                 ↓                  ↓
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  7.0         │  │  8.0         │  │  9.0         │
│ NOTIFICATION │  │ MESSAGING &  │  │ REVIEW &     │
│ SYSTEM       │  │ COMMUNICATION│  │ RATING       │
│              │  │              │  │              │
└──────────────┘  └──────────────┘  └──────────────┘
```

---

## 🔍 LEVEL 2 DFD - DETAILED PROCESSES

### **PROCESS 1.0: USER MANAGEMENT**

```
┌─────────────┐
│  CUSTOMER   │
└──────┬──────┘
       │
       │ Registration/Login
       ↓
┌──────────────────────────────────────┐
│  1.1                                 │
│  USER AUTHENTICATION                 │
│  - Email/Phone Verification          │
│  - Password Management               │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  DATABASE: auth.users                │
│           user_profiles              │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  1.2                                 │
│  PROFILE MANAGEMENT                  │
│  - Update Info                       │
│  - Upload Documents                  │
│  - Location Tracking                 │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  DATABASE: user_profiles             │
│           document_verifications     │
└──────────────────────────────────────┘
```

**Data Stores:**
- D1: auth.users
- D2: user_profiles
- D3: document_verifications
- D4: account_security_logs

---

### **PROCESS 2.0: SERVICE REQUEST PROCESSING**

```
┌─────────────┐
│  CUSTOMER   │
└──────┬──────┘
       │
       │ Service Request
       ↓
┌──────────────────────────────────────┐
│  2.1                                 │
│  REQUEST CREATION                    │
│  - Select Service Type               │
│  - Add Vehicle Details               │
│  - Location & Photos                 │
│  - Emergency Flag                    │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  DATABASE: service_requests          │
│           vehicles                   │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  2.2                                 │
│  REQUEST BROADCASTING                │
│  - Find Nearby Shops (15km radius)   │
│  - Check Shop Hours (business_hours) │
│  - Notify Available Mechanics        │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  DATABASE: request_broadcasts        │
│           shops                      │
│           mechanics                  │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  2.3                                 │
│  ASSIGNMENT & ACCEPTANCE             │
│  - Mechanic Accepts Request          │
│  - Update Status                     │
│  - Send Notifications                │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  DATABASE: service_requests          │
│           service_request_status_log │
│           notifications              │
└──────────────────────────────────────┘
```

**Data Flow:**
1. Customer → Request Data → Service Request System
2. Service Request System → Request Info → Database
3. Database → Available Mechanics → Broadcast System
4. Mechanic → Acceptance → Service Request System
5. Service Request System → Status Update → Customer

**Data Stores:**
- D5: service_requests
- D6: request_broadcasts
- D7: service_request_status_log
- D8: vehicles

---

### **PROCESS 3.0: VEHICLE MANAGEMENT**

```
┌─────────────┐
│  CUSTOMER   │
└──────┬──────┘
       │
       │ Vehicle Information
       ↓
┌──────────────────────────────────────┐
│  3.1                                 │
│  VEHICLE REGISTRATION                │
│  - Auto-fetch from NHTSA API         │
│  - Manual Entry                      │
│  - Set Default Vehicle               │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  DATABASE: vehicles                  │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  3.2                                 │
│  VEHICLE HISTORY TRACKING            │
│  - Link to Service Requests          │
│  - Maintenance Records               │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  DATABASE: service_requests          │
│           customer_job_history       │
└──────────────────────────────────────┘
```

**Data Stores:**
- D9: vehicles
- D10: customer_job_history

---

### **PROCESS 4.0: SHOP & MECHANIC MANAGEMENT**

```
┌──────────────┐
│ TALYER OWNER │
└──────┬───────┘
       │
       │ Shop Setup
       ↓
┌──────────────────────────────────────┐
│  4.1                                 │
│  SHOP REGISTRATION                   │
│  - Shop Details & Location           │
│  - Business Hours (JSONB)            │
│  - Upload Business Permit            │
│  - Service Offerings                 │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  DATABASE: shops                     │
│           business_permits           │
│           shop_services              │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  4.2                                 │
│  MECHANIC ONBOARDING                 │
│  - Add Mechanic to Shop              │
│  - Scan QR Code                      │
│  - Verify Documents                  │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  DATABASE: mechanics                 │
│           shop_mechanics             │
│           document_verifications     │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  4.3                                 │
│  AVAILABILITY MANAGEMENT             │
│  - Toggle Online/Offline             │
│  - Update Location                   │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  DATABASE: user_profiles             │
│           mechanics                  │
└──────────────────────────────────────┘
```

**Data Stores:**
- D11: shops
- D12: mechanics
- D13: shop_mechanics
- D14: shop_services
- D15: business_permits

---

### **PROCESS 5.0: MECHANIC DISPATCH & JOB TRACKING**

```
┌──────────────┐
│   MECHANIC   │
└──────┬───────┘
       │
       │ Job Acceptance
       ↓
┌──────────────────────────────────────┐
│  5.1                                 │
│  JOB ASSIGNMENT                      │
│  - Accept Request                    │
│  - Update Status to "dispatched"     │
│  - Generate QR Code                  │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  DATABASE: service_requests          │
│           service_request_status_log │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  5.2                                 │
│  LOCATION TRACKING                   │
│  - Real-time GPS Updates             │
│  - ETA Calculation                   │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  DATABASE: mechanics                 │
│           user_profiles              │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  5.3                                 │
│  JOB PROGRESS TRACKING               │
│  - Status: arrived/diagnosing        │
│  - Upload Progress Photos            │
│  - Phase Tracking                    │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  DATABASE: service_requests          │
│           progress_photos            │
│           service_phase_tracking     │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  5.4                                 │
│  JOB COMPLETION                      │
│  - Create Invoice                    │
│  - Scan QR Code for Verification     │
│  - Update Status to "completed"      │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  DATABASE: service_requests          │
│           invoices                   │
│           mechanic_job_history       │
└──────────────────────────────────────┘
```

**Status Flow:**
```
pending → accepted → mechanic_assigned → dispatched → 
arrived → diagnosing → repairing → waiting_payment → 
paid → completed
```

**Data Stores:**
- D16: service_requests
- D17: progress_photos
- D18: service_phase_tracking
- D19: mechanic_job_history

---

### **PROCESS 6.0: PAYMENT PROCESSING**

```
┌─────────────┐
│  CUSTOMER   │
└──────┬──────┘
       │
       │ Payment Request
       ↓
┌──────────────────────────────────────┐
│  6.1                                 │
│  INVOICE GENERATION                  │
│  - Calculate Subtotal                │
│  - Add Service Fee (7%)              │
│  - Generate Invoice Number           │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  DATABASE: invoices                  │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  6.2                                 │
│  PAYMENT METHOD SELECTION            │
│  - GCash/Credit Card (PayMongo)      │
│  - Cash Payment                      │
└────────┬─────────────────────────────┘
         │
         ├─────────────┐
         │             │
         ↓             ↓
┌────────────────┐  ┌───────────────────┐
│ 6.3            │  │ 6.4               │
│ PAYMONGO       │  │ CASH PAYMENT      │
│ PROCESSING     │  │ VERIFICATION      │
│ - Create Link  │  │ - Upload Receipt  │
│ - Webhook      │  │ - Admin Approval  │
└────┬───────────┘  └────┬──────────────┘
     │                   │
     ↓                   ↓
┌──────────────────────────────────────┐
│  DATABASE: payments                  │
│           cash_payment_verifications │
│           paymongo_webhook_events    │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  6.5                                 │
│  EARNINGS DISTRIBUTION               │
│  - Calculate Mechanic Share          │
│  - Platform Commission               │
│  - Update Earnings                   │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  DATABASE: earnings                  │
│           mechanics                  │
└──────────────────────────────────────┘
```

**Payment Flow:**
```
Invoice Created → Payment Method Selected → 
  ├─ PayMongo: Checkout → Webhook → Payment Confirmed
  └─ Cash: Receipt Upload → Admin Verification → Approved
→ Earnings Recorded → Job Completed
```

**Data Stores:**
- D20: invoices
- D21: payments
- D22: cash_payment_verifications
- D23: earnings
- D24: paymongo_webhook_events

---

### **PROCESS 7.0: NOTIFICATION SYSTEM**

```
┌──────────────────────────────────────┐
│  TRIGGER EVENTS                      │
│  - Request Created                   │
│  - Mechanic Assigned                 │
│  - Status Changed                    │
│  - Payment Received                  │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  7.1                                 │
│  NOTIFICATION PREPARATION            │
│  - Load Template                     │
│  - Replace Variables                 │
│  - Check User Preferences            │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  DATABASE: notification_templates    │
│           user_notification_prefs    │
│           do_not_disturb_settings    │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  7.2                                 │
│  DELIVERY ROUTING                    │
│  - In-App Notification               │
│  - Push Notification (FCM)           │
│  - Email Notification                │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  DATABASE: notifications             │
│           notification_delivery_log  │
│           email_notifications        │
└──────────────────────────────────────┘
```

**Notification Types:**
- `request_created` - New service request
- `mechanic_assigned` - Mechanic accepted
- `status_update` - Job progress
- `payment_received` - Payment confirmed
- `job_completed` - Service finished
- `review_reminder` - Rate the service

**Data Stores:**
- D25: notifications
- D26: notification_templates
- D27: notification_delivery_log
- D28: user_notification_preferences

---

### **PROCESS 8.0: MESSAGING & COMMUNICATION**

```
┌─────────────┐         ┌──────────────┐
│  CUSTOMER   │         │   MECHANIC   │
└──────┬──────┘         └──────┬───────┘
       │                       │
       │  Send Message         │
       └───────────┬───────────┘
                   │
                   ↓
┌──────────────────────────────────────┐
│  8.1                                 │
│  MESSAGE PROCESSING                  │
│  - Validate Sender/Receiver          │
│  - Link to Service Request           │
│  - Real-time Delivery                │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  DATABASE: messages                  │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  8.2                                 │
│  MESSAGE NOTIFICATION                │
│  - Push to Receiver                  │
│  - Update Read Status                │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  DATABASE: notifications             │
└──────────────────────────────────────┘
```

**Data Stores:**
- D29: messages

---

### **PROCESS 9.0: REVIEW & RATING SYSTEM**

```
┌─────────────┐
│  CUSTOMER   │
└──────┬──────┘
       │
       │ Submit Review
       ↓
┌──────────────────────────────────────┐
│  9.1                                 │
│  REVIEW SUBMISSION                   │
│  - Rating (1-5 stars)                │
│  - Written Review                    │
│  - Service Quality Ratings           │
│  - Upload Photos                     │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  DATABASE: reviews                   │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  9.2                                 │
│  RATING CALCULATION                  │
│  - Update Mechanic Rating            │
│  - Update Shop Rating                │
│  - Calculate Averages                │
└────────┬─────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────┐
│  DATABASE: mechanics                 │
│           shops                      │
└──────────────────────────────────────┘
```

**Data Stores:**
- D30: reviews

---

## 📊 DATA DICTIONARY

### Primary Data Elements

| Data Element | Description | Type | Example |
|-------------|-------------|------|---------|
| **user_id** | Unique user identifier | UUID | `a1b2c3d4-...` |
| **service_request_id** | Unique request ID | UUID | `e5f6g7h8-...` |
| **status** | Current request status | ENUM | `pending`, `in_progress` |
| **location** | GPS coordinates | GEOGRAPHY | `(14.5995, 120.9842)` |
| **payment_status** | Payment state | ENUM | `unpaid`, `paid` |
| **service_fee** | Platform commission (7%) | DECIMAL | `350.00` |
| **business_hours** | Shop operating hours | JSONB | `{"monday": {"open": "08:00"}}` |
| **rating** | Service rating | INTEGER | `1-5` |
| **qr_code** | Job verification code | TEXT | `QR-2024-12345` |

---

## 🔐 SECURITY & ACCESS CONTROL

### Row Level Security (RLS) Policies

**Customer Access:**
- ✅ Can view own service_requests
- ✅ Can view own vehicles
- ✅ Can view own payments
- ❌ Cannot view other customers' data

**Mechanic Access:**
- ✅ Can view assigned service_requests
- ✅ Can update job progress
- ✅ Can view own earnings
- ❌ Cannot modify completed jobs

**Talyer Owner Access:**
- ✅ Can view shop's service_requests
- ✅ Can manage shop mechanics
- ✅ Can view shop analytics
- ❌ Cannot access other shops' data

**Admin Access:**
- ✅ Full read/write access
- ✅ Audit trail logging
- ✅ Document verification

---

## 📱 SYSTEM INTERFACES

### External APIs

1. **Supabase**
   - Authentication (auth.users)
   - Database (PostgreSQL + PostGIS)
   - Storage (profile images, documents)
   - Realtime subscriptions

2. **PayMongo**
   - Payment processing
   - Webhook notifications
   - Checkout links

3. **Firebase Cloud Messaging (FCM)**
   - Push notifications
   - Device token management

4. **NHTSA API**
   - Vehicle information lookup
   - Auto-populate vehicle details

5. **Google Maps / OpenStreetMap**
   - Location services
   - Geocoding
   - Distance calculation

---

## 🎯 KEY BUSINESS RULES

1. **Service Request Broadcast**
   - Radius: 15km from customer location
   - Only show OPEN shops (based on business_hours)
   - Expire after 15 minutes if no response

2. **Service Fee**
   - Platform charges 7% service fee
   - Calculated on subtotal
   - Added to invoice total

3. **Shop Business Hours**
   - Stored as JSONB format
   - Real-time open/closed check
   - Closed shops hidden from customers

4. **QR Code Verification**
   - Generated after mechanic dispatches
   - Expires after 24 hours
   - Required for job completion

5. **Payment Processing**
   - PayMongo: Instant confirmation via webhook
   - Cash: Requires photo proof + admin approval
   - Earnings released after payment confirmed

6. **Rating System**
   - Customers can rate after job completion
   - 1-5 star scale
   - Updates mechanic and shop averages

---

**Generated for:** RoadAid Auto Repair Assistance System  
**Date:** October 9, 2025  
**Version:** 1.0 (Complete Data Flow)  
**Language:** Taglish (Tagalog + English)
