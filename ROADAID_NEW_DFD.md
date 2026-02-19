# 🔄 RoadAid System - Enhanced Data Flow Diagram (DFD)

**Date Created:** January 19, 2026  
**System:** RoadAid - Comprehensive Roadside Assistance Platform  
**Database:** PostgreSQL (Supabase)  
**Version:** 2.0 - Enhanced Edition

---

## 📊 DFD Level 0 - Context Diagram

```
                                     ╔══════════════════════════════════════════════════════════════╗
                                     ║                    EXTERNAL ENTITIES                         ║
                                     ╚══════════════════════════════════════════════════════════════╝
                                     
         ┌─────────────┐                                                          ┌─────────────┐
         │  CUSTOMER   │                                                          │  MECHANIC   │
         │    👤       │                                                          │    🔧       │
         └──────┬──────┘                                                          └──────┬──────┘
                │                                                                        │
                │ • Registration/Login                                                   │ • Registration/Login
                │ • Service Request                                                      │ • Accept/Decline Jobs
                │ • Payment                                                              │ • Update Status
                │ • Rating/Review                                                        │ • Complete Service
                │                                                                        │
                ▼                                                                        ▼
         ╔════════════════════════════════════════════════════════════════════════════════════════╗
         ║                                                                                        ║
         ║                              RoadAid System                                            ║
         ║                     (Roadside Assistance Platform)                                     ║
         ║                                                                                        ║
         ║  ┌────────────────────────────────────────────────────────────────────────────────┐   ║
         ║  │                                                                                │   ║
         ║  │   📱 Mobile App (Flutter)  ←→  🌐 Backend (Supabase)  ←→  🗄️ Database (PostgreSQL)  │   ║
         ║  │                                                                                │   ║
         ║  └────────────────────────────────────────────────────────────────────────────────┘   ║
         ║                                                                                        ║
         ╚════════════════════════════════════════════════════════════════════════════════════════╝
                │                                                                        │
                │                                                                        │
                ▼                                                                        ▼
         ┌─────────────┐                                                          ┌─────────────┐
         │ SHOP OWNER  │                                                          │    ADMIN    │
         │    🏪       │                                                          │    👨‍💼       │
         └─────────────┘                                                          └─────────────┘
                │                                                                        │
                │ • Shop Management                                                      │ • User Management
                │ • Mechanic Management                                                  │ • Verification
                │ • Service Configuration                                                │ • Payment Approval
                │ • Earnings Tracking                                                    │ • Analytics
                │
                │                          ┌─────────────┐
                └──────────────────────────│  PAYMONGO   │
                                           │  Gateway    │
                                           │    💳       │
                                           └─────────────┘
```

### External Entities Description

| Entity | Role | Primary Functions |
|--------|------|-------------------|
| **Customer** | Service Requester | Creates service requests, makes payments, provides ratings |
| **Mechanic** | Service Provider | Accepts jobs, performs repairs, completes services |
| **Shop Owner** | Shop Manager | Manages shop, mechanics, services, and tracks earnings |
| **Admin** | Platform Manager | Verifies users, approves payments, monitors system |
| **PayMongo** | Payment Gateway | Processes online payments (GCash, PayMaya, Card) |

---

## 📊 DFD Level 1 - Main System Processes

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    DFD LEVEL 1 - MAIN PROCESSES                                         │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

     [CUSTOMER]           [MECHANIC]           [SHOP OWNER]             [ADMIN]           [PAYMONGO]
          │                    │                      │                    │                    │
          │                    │                      │                    │                    │
          ▼                    ▼                      ▼                    ▼                    │
    ┌───────────────────────────────────────────────────────────────────────────────────────┐  │
    │                           1.0 USER AUTHENTICATION & MANAGEMENT                        │  │
    │  ┌──────────────────────────────────────────────────────────────────────────────────┐ │  │
    │  │ • User Registration        • Login/Logout        • Profile Management            │ │  │
    │  │ • Password Reset           • Email Verification  • Account Security              │ │  │
    │  └──────────────────────────────────────────────────────────────────────────────────┘ │  │
    └───────────────────────────────────────────────────┬───────────────────────────────────┘  │
                                                        │                                      │
                                                        ▼                                      │
    ┌───────────────────────────────────────────────────────────────────────────────────────┐  │
    │                           2.0 SERVICE REQUEST MANAGEMENT                              │  │
    │  ┌──────────────────────────────────────────────────────────────────────────────────┐ │  │
    │  │ • Create Service Request   • Vehicle Selection   • Service Category Selection    │ │  │
    │  │ • Location Detection       • Fee Calculation     • Request Type Determination    │ │  │
    │  └──────────────────────────────────────────────────────────────────────────────────┘ │  │
    └───────────────────────────────────────────────────┬───────────────────────────────────┘  │
                                                        │                                      │
                                                        ▼                                      │
    ┌───────────────────────────────────────────────────────────────────────────────────────┐  │
    │                           3.0 REQUEST ROUTING & BROADCASTING                          │  │
    │  ┌──────────────────────────────────────────────────────────────────────────────────┐ │  │
    │  │ • Find Nearby Providers    • Broadcast Request   • Provider Notification         │ │  │
    │  │ • Distance Calculation     • Accept/Decline      • Mechanic Assignment           │ │  │
    │  └──────────────────────────────────────────────────────────────────────────────────┘ │  │
    └───────────────────────────────────────────────────┬───────────────────────────────────┘  │
                                                        │                                      │
                                                        ▼                                      │
    ┌───────────────────────────────────────────────────────────────────────────────────────┐  │
    │                           4.0 SERVICE EXECUTION & TRACKING                            │  │
    │  ┌──────────────────────────────────────────────────────────────────────────────────┐ │  │
    │  │ • Real-time Location       • Status Updates      • Progress Photos               │ │  │
    │  │ • In-app Messaging         • Service Phases      • QR Code Completion            │ │  │
    │  └──────────────────────────────────────────────────────────────────────────────────┘ │  │
    └───────────────────────────────────────────────────┬───────────────────────────────────┘  │
                                                        │                                      │
                                                        ▼                                      │
    ┌───────────────────────────────────────────────────────────────────────────────────────┐  │
    │                           5.0 BILLING & PAYMENT PROCESSING                            │◄─┘
    │  ┌──────────────────────────────────────────────────────────────────────────────────┐ │
    │  │ • Invoice Generation       • Payment Selection   • Online Payment Processing     │ │
    │  │ • Cash Payment Capture     • Payment Verification • Transaction Recording        │ │
    │  └──────────────────────────────────────────────────────────────────────────────────┘ │
    └───────────────────────────────────────────────────┬───────────────────────────────────┘
                                                        │
                                                        ▼
    ┌───────────────────────────────────────────────────────────────────────────────────────┐
    │                           6.0 PAYMENT RELEASE & SETTLEMENT                            │
    │  ┌──────────────────────────────────────────────────────────────────────────────────┐ │
    │  │ • Create Release Request   • Admin Approval      • Earnings Distribution         │ │
    │  │ • Platform Fee Deduction   • Provider Payout     • Settlement Recording          │ │
    │  └──────────────────────────────────────────────────────────────────────────────────┘ │
    └───────────────────────────────────────────────────┬───────────────────────────────────┘
                                                        │
                                                        ▼
    ┌───────────────────────────────────────────────────────────────────────────────────────┐
    │                           7.0 HISTORY & REVIEW MANAGEMENT                             │
    │  ┌──────────────────────────────────────────────────────────────────────────────────┐ │
    │  │ • Job History Recording    • Rating Submission   • Review Management             │ │
    │  │ • Provider Rating Update   • Analytics Generation • Performance Tracking         │ │
    │  └──────────────────────────────────────────────────────────────────────────────────┘ │
    └───────────────────────────────────────────────────┬───────────────────────────────────┘
                                                        │
                                                        ▼
    ┌───────────────────────────────────────────────────────────────────────────────────────┐
    │                           8.0 SHOP & VERIFICATION MANAGEMENT                          │
    │  ┌──────────────────────────────────────────────────────────────────────────────────┐ │
    │  │ • Shop Registration        • Document Verification • Mechanic Invitation         │ │
    │  │ • Service Configuration    • Business Hours       • Shop Dashboard               │ │
    │  └──────────────────────────────────────────────────────────────────────────────────┘ │
    └───────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 📊 DFD Level 2 - Process 1.0: User Authentication & Management

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                         PROCESS 1.0 - USER AUTHENTICATION & MANAGEMENT                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

    [CUSTOMER/MECHANIC/SHOP OWNER]
              │
              │ Registration Data (email, password, user_type, personal info)
              ▼
    ┌─────────────────────────────────┐
    │  1.1 USER REGISTRATION          │
    │  ──────────────────────────────│
    │  • Validate input data          │
    │  • Check email uniqueness       │
    │  • Hash password                │
    │  • Generate verification token  │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D1: auth.users
                  │                                            (email, password, created_at)
                  │
                  │ ─────────────────────────────────────────► D2: user_profiles
                  │                                            (first_name, last_name, user_type)
                  │
                  │ ─────────────────────────────────────────► D3: email_verification_tokens
                  │                                            (token, user_id, expires_at)
                  ▼
    ┌─────────────────────────────────┐
    │  1.2 EMAIL VERIFICATION         │
    │  ──────────────────────────────│
    │  • Send verification email      │
    │  • Validate token               │
    │  • Activate user account        │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D2: user_profiles
                  │                                            (status = 'active')
                  ▼
    ┌─────────────────────────────────┐
    │  1.3 USER LOGIN                 │ ◄──────── Login Credentials
    │  ──────────────────────────────│
    │  • Validate credentials         │
    │  • Check account status         │
    │  • Generate session token       │
    │  • Log security event           │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D4: account_security_logs
                  │                                            (user_id, action_type, ip_address)
                  │
                  │ ─────────────────────────────────────────► D2: user_profiles
                  │                                            (last_login_at)
                  ▼
    ┌─────────────────────────────────┐
    │  1.4 PASSWORD RESET             │ ◄──────── Reset Request (email)
    │  ──────────────────────────────│
    │  • Validate email exists        │
    │  • Generate reset token         │
    │  • Send reset email             │
    │  • Update password              │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D5: password_reset_tokens
                  │                                            (user_id, token, expires_at)
                  ▼
    ┌─────────────────────────────────┐
    │  1.5 PROFILE MANAGEMENT         │ ◄──────── Profile Updates
    │  ──────────────────────────────│
    │  • Update personal info         │
    │  • Upload profile image         │
    │  • Update contact details       │
    │  • Change notification prefs    │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D2: user_profiles
                  │                                            (updated fields)
                  │
                  │ ─────────────────────────────────────────► D6: audit_logs
                  │                                            (action, old_values, new_values)
                  ▼
              [END 1.0]
```

### Data Stores - Process 1.0

| ID | Data Store | Fields Used | Operations |
|----|------------|-------------|------------|
| D1 | auth.users | id, email, encrypted_password, created_at | INSERT, SELECT |
| D2 | user_profiles | All profile fields | INSERT, UPDATE, SELECT |
| D3 | email_verification_tokens | user_id, token, expires_at, used_at | INSERT, UPDATE |
| D4 | account_security_logs | user_id, action_type, ip_address, success | INSERT |
| D5 | password_reset_tokens | user_id, token, expires_at, is_active | INSERT, UPDATE |
| D6 | audit_logs | user_id, action, table_name, old_values, new_values | INSERT |

---

## 📊 DFD Level 2 - Process 2.0: Service Request Management

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                         PROCESS 2.0 - SERVICE REQUEST MANAGEMENT                                        │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

    [CUSTOMER]
         │
         │ Service Request (location, vehicle, service_type, description)
         ▼
    ┌─────────────────────────────────┐
    │  2.1 AUTHENTICATE USER          │
    │  ──────────────────────────────│
    │  • Verify session token         │
    │  • Get user profile             │
    │  • Check account status         │
    └─────────────┬───────────────────┘
                  │
                  │ ◄──────────────────────────────────────── D1: auth.users
                  │ ◄──────────────────────────────────────── D2: user_profiles
                  ▼
    ┌─────────────────────────────────┐
    │  2.2 SELECT VEHICLE             │
    │  ──────────────────────────────│
    │  • Fetch user's vehicles        │
    │  • Select existing vehicle      │
    │  • Or add new vehicle           │
    └─────────────┬───────────────────┘
                  │
                  │ ◄──────────────────────────────────────── D7: vehicles
                  │                                            (user's vehicle list)
                  │
                  │ ─────────────────────────────────────────► D7: vehicles
                  │                                            (new vehicle if added)
                  ▼
    ┌─────────────────────────────────┐
    │  2.3 SELECT SERVICE CATEGORY    │
    │  ──────────────────────────────│
    │  • Fetch available categories   │
    │  • Display service options      │
    │  • Select service type          │
    └─────────────┬───────────────────┘
                  │
                  │ ◄──────────────────────────────────────── D8: service_categories
                  │                                            (available services)
                  ▼
    ┌─────────────────────────────────┐
    │  2.4 DETECT/SET LOCATION        │
    │  ──────────────────────────────│
    │  • Get current GPS location     │
    │  • Or manually set location     │
    │  • Geocode address              │
    │  • Validate service area        │
    └─────────────┬───────────────────┘
                  │
                  │ Location Data (latitude, longitude, address)
                  ▼
    ┌─────────────────────────────────┐
    │  2.5 CALCULATE SERVICE FEE      │
    │  ──────────────────────────────│
    │  • Get base service price       │
    │  • Calculate distance fee       │
    │  • Apply emergency multiplier   │
    │  • Calculate total estimate     │
    └─────────────┬───────────────────┘
                  │
                  │ ◄──────────────────────────────────────── D9: distance_pricing_config
                  │                                            (base_rate, multipliers)
                  │
                  │ ◄──────────────────────────────────────── D8: service_categories
                  │                                            (base_price)
                  ▼
    ┌─────────────────────────────────┐
    │  2.6 DETERMINE REQUEST TYPE     │
    │  ──────────────────────────────│
    │  • Check if specific shop       │
    │  • Check if direct mechanic     │
    │  • Or broadcast to all nearby   │
    │  • Set broadcast radius         │
    └─────────────┬───────────────────┘
                  │
                  │ Request Type (shop_based / direct_mechanic / broadcast)
                  ▼
    ┌─────────────────────────────────┐
    │  2.7 CREATE SERVICE REQUEST     │
    │  ──────────────────────────────│
    │  • Generate request ID          │
    │  • Save all request data        │
    │  • Set initial status           │
    │  • Trigger notifications        │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D10: service_requests
                  │                                             (all request fields)
                  │
                  │ ─────────────────────────────────────────► D11: notifications
                  │                                             (customer confirmation)
                  ▼
              [PROCESS 3.0]
```

### Data Stores - Process 2.0

| ID | Data Store | Fields Used | Operations |
|----|------------|-------------|------------|
| D7 | vehicles | user_id, brand, model, plate_number, vehicle_type | SELECT, INSERT |
| D8 | service_categories | id, name, base_price, estimated_duration | SELECT |
| D9 | distance_pricing_config | base_rate_per_km, minimum_fee, emergency_multiplier | SELECT |
| D10 | service_requests | All request fields | INSERT |
| D11 | notifications | user_id, title, body, type | INSERT |

---

## 📊 DFD Level 2 - Process 3.0: Request Routing & Broadcasting

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                         PROCESS 3.0 - REQUEST ROUTING & BROADCASTING                                    │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

    [FROM PROCESS 2.0]
         │
         │ Service Request (request_id, location, request_type)
         ▼
    ┌─────────────────────────────────┐
    │  3.1 ANALYZE REQUEST TYPE       │
    │  ──────────────────────────────│
    │  • Get request details          │
    │  • Determine routing method     │
    │  • Validate shop/mechanic ID    │
    └─────────────┬───────────────────┘
                  │
                  │ ◄──────────────────────────────────────── D10: service_requests
                  │
                  ├──────────────────────────────────────────────────────────────────┐
                  │                                                                  │
                  │ [SHOP-BASED]                                       [BROADCAST]  │
                  ▼                                                                  ▼
    ┌─────────────────────────────────┐                       ┌─────────────────────────────────┐
    │  3.2A NOTIFY SPECIFIC SHOP      │                       │  3.2B FIND NEARBY PROVIDERS     │
    │  ──────────────────────────────│                       │  ──────────────────────────────│
    │  • Get shop details             │                       │  • Calculate distances          │
    │  • Check shop availability      │                       │  • Filter by service radius     │
    │  • Send notification to shop    │                       │  • Check availability status    │
    │  • Notify shop mechanics        │                       │  • Sort by distance/rating      │
    └─────────────┬───────────────────┘                       └─────────────┬───────────────────┘
                  │                                                         │
                  │ ◄─────────────────────────── D12: shops                │
                  │ ◄─────────────────────────── D13: shop_mechanics       │ ◄─── D12: shops
                  │                                                         │ ◄─── D14: service_providers
                  │                                                         │ ◄─── D15: mechanic_availability_status
                  │                                                         │
                  └─────────────────────────────┬───────────────────────────┘
                                                │
                                                ▼
    ┌─────────────────────────────────┐
    │  3.3 CREATE BROADCAST RECORDS   │
    │  ──────────────────────────────│
    │  • Create broadcast entry       │
    │  • Record distance to each      │
    │  • Set notification timestamp   │
    │  • Set expiration time          │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D16: request_broadcasts
                  │                                             (request_id, provider_id, distance)
                  │
                  │ ─────────────────────────────────────────► D17: request_routing
                  │                                             (routing details)
                  ▼
    ┌─────────────────────────────────┐
    │  3.4 SEND NOTIFICATIONS         │
    │  ──────────────────────────────│
    │  • Push notifications           │
    │  • In-app notifications         │
    │  • Shop notifications           │
    │  • Real-time updates            │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D11: notifications
                  │ ─────────────────────────────────────────► D18: shop_notifications
                  │
                  │                    [MECHANIC/SHOP]
                  │                          │
                  │                          │ Accept/Decline Response
                  ▼                          ▼
    ┌───────────────────────────────────────────────────────┐
    │  3.5 RECEIVE PROVIDER RESPONSE                        │
    │  ────────────────────────────────────────────────────│
    │  • Record response (accept/decline)                   │
    │  • Update broadcast status                            │
    │  • Check for competing accepts (FIFO)                 │
    └─────────────────────────┬─────────────────────────────┘
                              │
                              │ ─────────────────────────────► D16: request_broadcasts
                              │                                 (response_status, responded_at)
                              │
                              │ [ACCEPTED]
                              ▼
    ┌─────────────────────────────────┐
    │  3.6 ASSIGN PROVIDER            │
    │  ──────────────────────────────│
    │  • Update request status        │
    │  • Set assigned_mechanic_id     │
    │  • Update provider availability │
    │  • Notify customer              │
    │  • Decline other broadcasts     │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D10: service_requests
                  │                                             (provider_id, status='accepted')
                  │
                  │ ─────────────────────────────────────────► D15: mechanic_availability_status
                  │                                             (current_status='busy')
                  │
                  │ ─────────────────────────────────────────► D11: notifications
                  │                                             (customer assignment notification)
                  ▼
              [PROCESS 4.0]
```

### Data Stores - Process 3.0

| ID | Data Store | Fields Used | Operations |
|----|------------|-------------|------------|
| D12 | shops | id, location, service_radius, current_status, business_hours | SELECT |
| D13 | shop_mechanics | shop_id, mechanic_id, is_active, is_available | SELECT |
| D14 | service_providers | id, user_id, shop_id, is_available, current_location | SELECT |
| D15 | mechanic_availability_status | mechanic_id, current_status, is_accepting_requests | SELECT, UPDATE |
| D16 | request_broadcasts | request_id, provider_id, distance_km, response_status | INSERT, UPDATE |
| D17 | request_routing | request_id, eligible_mechanic_id, routing_type | INSERT |
| D18 | shop_notifications | shop_id, request_id, notification_type | INSERT |

---

## 📊 DFD Level 2 - Process 4.0: Service Execution & Tracking

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                         PROCESS 4.0 - SERVICE EXECUTION & TRACKING                                      │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

    [FROM PROCESS 3.0]
         │
         │ Assigned Request (mechanic assigned)
         ▼
    ┌─────────────────────────────────┐
    │  4.1 MECHANIC EN ROUTE          │ ◄──────── [MECHANIC] Status Update
    │  ──────────────────────────────│
    │  • Update status to 'en_route'  │
    │  • Start location tracking      │
    │  • Calculate ETA                │
    │  • Notify customer              │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D10: service_requests
                  │                                             (status='en_route')
                  │
                  │ ─────────────────────────────────────────► D2: user_profiles
                  │                                             (mechanic current_location)
                  │
                  │ ─────────────────────────────────────────► D11: notifications
                  │                                             (customer: mechanic on the way)
                  │
                  │ ─────────────────────────────────────────► D19: active_routes
                  │                                             (route tracking data)
                  ▼
    ┌─────────────────────────────────┐
    │  4.2 ARRIVAL CONFIRMATION       │ ◄──────── [MECHANIC] Arrived
    │  ──────────────────────────────│
    │  • Update status to 'arrived'   │
    │  • Stop ETA tracking            │
    │  • Capture arrival photo        │
    │  • Notify customer              │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D10: service_requests
                  │                                             (status='arrived')
                  │
                  │ ─────────────────────────────────────────► D20: progress_photos
                  │                                             (service_phase='arrival')
                  │
                  │ ─────────────────────────────────────────► D11: notifications
                  │                                             (customer: mechanic arrived)
                  ▼
    ┌─────────────────────────────────┐
    │  4.3 VEHICLE INSPECTION         │ ◄──────── [MECHANIC] Inspection Data
    │  ──────────────────────────────│
    │  • Document vehicle issues      │
    │  • Capture inspection photos    │
    │  • Update service phase         │
    │  • Confirm service scope        │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D20: progress_photos
                  │                                             (service_phase='inspection')
                  │
                  │ ─────────────────────────────────────────► D21: service_phase_tracking
                  │                                             (current_phase='inspection')
                  ▼
    ┌─────────────────────────────────┐
    │  4.4 SERVICE EXECUTION          │ ◄──────── [MECHANIC] Progress Updates
    │  ──────────────────────────────│
    │  • Update to 'in_progress'      │
    │  • Capture work photos          │
    │  • Update progress              │
    │  • Log service activities       │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D10: service_requests
                  │                                             (status='in_progress')
                  │
                  │ ─────────────────────────────────────────► D20: progress_photos
                  │                                             (service_phase='work_in_progress')
                  │
                  │ ─────────────────────────────────────────► D21: service_phase_tracking
                  │                                             (phase_history update)
                  ▼
    ┌─────────────────────────────────┐
    │  4.5 COMMUNICATION HANDLER      │ ◄──────── [CUSTOMER/MECHANIC] Messages
    │  ──────────────────────────────│
    │  • Handle chat messages         │
    │  • Send push notifications      │
    │  • Real-time message sync       │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D22: messages
                  │                                             (sender_id, receiver_id, message)
                  │
                  │ ─────────────────────────────────────────► D11: notifications
                  │                                             (new message notification)
                  ▼
    ┌─────────────────────────────────┐
    │  4.6 SERVICE COMPLETION         │ ◄──────── [MECHANIC] Mark Complete
    │  ──────────────────────────────│
    │  • Generate completion code     │
    │  • Generate QR code             │
    │  • Capture completion photos    │
    │  • Update status to 'completed' │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D10: service_requests
                  │                                             (status='awaiting_verification')
                  │
                  │ ─────────────────────────────────────────► D23: job_completion_codes
                  │                                             (completion_code, expires_at)
                  │
                  │ ─────────────────────────────────────────► D24: service_completions
                  │                                             (qr_code_data)
                  │
                  │ ─────────────────────────────────────────► D20: progress_photos
                  │                                             (service_phase='completed')
                  ▼
    ┌─────────────────────────────────┐
    │  4.7 CUSTOMER VERIFICATION      │ ◄──────── [CUSTOMER] Scan QR / Enter Code
    │  ──────────────────────────────│
    │  • Scan QR code                 │
    │  • Or enter completion code     │
    │  • Verify code validity         │
    │  • Confirm service completion   │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D23: job_completion_codes
                  │                                             (is_used=true, used_at)
                  │
                  │ ─────────────────────────────────────────► D24: service_completions
                  │                                             (is_scanned=true, verification_status)
                  │
                  │ ─────────────────────────────────────────► D10: service_requests
                  │                                             (status='completed')
                  ▼
              [PROCESS 5.0]
```

### Data Stores - Process 4.0

| ID | Data Store | Fields Used | Operations |
|----|------------|-------------|------------|
| D19 | active_routes | request_id, mechanic_location, customer_location, eta | INSERT, UPDATE |
| D20 | progress_photos | request_id, mechanic_id, service_phase, image_url | INSERT |
| D21 | service_phase_tracking | request_id, current_phase, phase_history | INSERT, UPDATE |
| D22 | messages | request_id, sender_id, receiver_id, message, sent_at | INSERT |
| D23 | job_completion_codes | request_id, completion_code, is_used, used_at | INSERT, UPDATE |
| D24 | service_completions | request_id, qr_code_data, is_scanned, scanned_at | INSERT, UPDATE |

---

## 📊 DFD Level 2 - Process 5.0: Billing & Payment Processing

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                         PROCESS 5.0 - BILLING & PAYMENT PROCESSING                                      │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

    [FROM PROCESS 4.0]
         │
         │ Service Completion (verified)
         ▼
    ┌─────────────────────────────────┐
    │  5.1 GENERATE INVOICE           │
    │  ──────────────────────────────│
    │  • Calculate subtotal           │
    │  • Calculate platform fee       │
    │  • Calculate provider amount    │
    │  • Calculate shop share         │
    │  • Generate invoice number      │
    └─────────────┬───────────────────┘
                  │
                  │ ◄──────────────────────────────────────── D10: service_requests
                  │                                            (final_price, service details)
                  │
                  │ ◄──────────────────────────────────────── D25: app_settings
                  │                                            (platform_fee_percentage)
                  │
                  │ ─────────────────────────────────────────► D26: invoices
                  │                                             (all invoice fields)
                  ▼
    ┌─────────────────────────────────┐
    │  5.2 SEND INVOICE TO CUSTOMER   │
    │  ──────────────────────────────│
    │  • Send in-app notification     │
    │  • Send email notification      │
    │  • Display in customer app      │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D11: notifications
                  │                                             (invoice ready notification)
                  │
                  │ ─────────────────────────────────────────► D27: email_notifications
                  │                                             (invoice email)
                  ▼
    ┌─────────────────────────────────┐
    │  5.3 CUSTOMER PAYMENT SELECTION │ ◄──────── [CUSTOMER] Select Payment Method
    │  ──────────────────────────────│
    │  • Display payment options      │
    │  • Cash payment                 │
    │  • GCash                        │
    │  • PayMaya                      │
    │  • Credit/Debit Card            │
    └─────────────┬───────────────────┘
                  │
                  ├──────────────────────────────────────────────────────────────────┐
                  │                                                                  │
                  │ [CASH PAYMENT]                                [ONLINE PAYMENT]  │
                  ▼                                                                  ▼
    ┌─────────────────────────────────┐                       ┌─────────────────────────────────┐
    │  5.4A PROCESS CASH PAYMENT      │                       │  5.4B PROCESS ONLINE PAYMENT    │
    │  ──────────────────────────────│                       │  ──────────────────────────────│
    │  • Customer pays mechanic       │                       │  • Redirect to PayMongo         │
    │  • Mechanic captures photo      │                       │  • Process payment              │
    │  • Upload cash photo evidence   │                       │  • Receive webhook callback     │
    │  • Create verification record   │                       │  • Record transaction ID        │
    └─────────────┬───────────────────┘                       └─────────────┬───────────────────┘
                  │                                                         │
                  │ ─────────────────────────────► D28: cash_payment_verifications    │
                  │                                 (cash_photo, verification_status)  │
                  │                                                         │
                  │                                                         │ ──────► [PAYMONGO]
                  │                                                         │ ◄────── Payment Response
                  │                                                         │
                  └─────────────────────────────┬───────────────────────────┘
                                                │
                                                ▼
    ┌─────────────────────────────────┐
    │  5.5 RECORD PAYMENT             │
    │  ──────────────────────────────│
    │  • Create payment record        │
    │  • Record transaction details   │
    │  • Set payment status           │
    │  • Link to invoice              │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D29: payments
                  │                                             (all payment fields)
                  ▼
    ┌─────────────────────────────────┐
    │  5.6 UPDATE INVOICE STATUS      │
    │  ──────────────────────────────│
    │  • Mark invoice as 'paid'       │
    │  • Record payment method        │
    │  • Update timestamps            │
    │  • Update request status        │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D26: invoices
                  │                                             (status='paid', paid_at)
                  │
                  │ ─────────────────────────────────────────► D10: service_requests
                  │                                             (payment_status='paid')
                  ▼
    ┌─────────────────────────────────┐
    │  5.7 VERIFY CASH PAYMENT        │ ◄──────── [ADMIN] Cash Verification
    │  (If cash payment)              │
    │  ──────────────────────────────│
    │  • Review photo evidence        │
    │  • Verify amount matches        │
    │  • Approve or reject            │
    │  • Log admin action             │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D28: cash_payment_verifications
                  │                                             (verification_status, verified_at)
                  │
                  │ ─────────────────────────────────────────► D30: admin_activity_logs
                  │                                             (cash verification action)
                  ▼
              [PROCESS 6.0]
```

### Data Stores - Process 5.0

| ID | Data Store | Fields Used | Operations |
|----|------------|-------------|------------|
| D25 | app_settings | platform_fee_percentage, payment_settings | SELECT |
| D26 | invoices | All invoice fields | INSERT, UPDATE |
| D27 | email_notifications | recipient_email, subject, body, delivery_status | INSERT |
| D28 | cash_payment_verifications | invoice_id, cash_photo_url, verification_status | INSERT, UPDATE |
| D29 | payments | All payment fields | INSERT, UPDATE |
| D30 | admin_activity_logs | admin_id, action_type, action_details | INSERT |

---

## 📊 DFD Level 2 - Process 6.0: Payment Release & Settlement

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                         PROCESS 6.0 - PAYMENT RELEASE & SETTLEMENT                                      │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

    [FROM PROCESS 5.0]
         │
         │ Payment Completed (verified)
         ▼
    ┌─────────────────────────────────┐
    │  6.1 CREATE RELEASE REQUEST     │
    │  ──────────────────────────────│
    │  • Get payment details          │
    │  • Calculate provider amount    │
    │  • Calculate platform fee       │
    │  • Create release record        │
    │  • Set status 'pending'         │
    └─────────────┬───────────────────┘
                  │
                  │ ◄──────────────────────────────────────── D29: payments
                  │ ◄──────────────────────────────────────── D26: invoices
                  │
                  │ ─────────────────────────────────────────► D31: payment_releases
                  │                                             (release_status='pending')
                  ▼
    ┌─────────────────────────────────┐
    │  6.2 ADMIN REVIEW & APPROVAL    │ ◄──────── [ADMIN] Review Request
    │  ──────────────────────────────│
    │  • Verify service completion    │
    │  • Check documentation          │
    │  • Review payment details       │
    │  • Approve or reject release    │
    └─────────────┬───────────────────┘
                  │
                  │ ◄──────────────────────────────────────── D10: service_requests
                  │                                            (completion verification)
                  │
                  │ ◄──────────────────────────────────────── D20: progress_photos
                  │                                            (completion proof)
                  │
                  │ ◄──────────────────────────────────────── D23: job_completion_codes
                  │                                            (verification status)
                  │
                  │ ─────────────────────────────────────────► D31: payment_releases
                  │                                             (release_status='approved')
                  │
                  │ ─────────────────────────────────────────► D30: admin_activity_logs
                  │                                             (approval action)
                  ▼
    ┌─────────────────────────────────┐
    │  6.3 PROCESS PAYMENT RELEASE    │
    │  ──────────────────────────────│
    │  • Execute release method       │
    │  • Bank transfer / GCash        │
    │  • Update release status        │
    │  • Record release timestamp     │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D31: payment_releases
                  │                                             (release_status='released')
                  ▼
    ┌─────────────────────────────────┐
    │  6.4 NOTIFY PROVIDER            │
    │  ──────────────────────────────│
    │  • Send payment release notif   │
    │  • Include amount details       │
    │  • Send email confirmation      │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D11: notifications
                  │                                             (payment released notification)
                  │
                  │ ─────────────────────────────────────────► D27: email_notifications
                  │                                             (release confirmation email)
                  ▼
    ┌─────────────────────────────────┐
    │  6.5 UPDATE EARNINGS RECORDS    │
    │  ──────────────────────────────│
    │  • Update mechanic earnings     │
    │  • Update shop earnings         │
    │  • Update platform earnings     │
    │  • Record settlement            │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D14: service_providers
                  │                                             (total_earnings update)
                  │
                  │ ─────────────────────────────────────────► D12: shops
                  │                                             (total_revenue update)
                  ▼
              [PROCESS 7.0]
```

---

## 📊 DFD Level 2 - Process 7.0: History & Review Management

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                         PROCESS 7.0 - HISTORY & REVIEW MANAGEMENT                                       │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

    [FROM PROCESS 6.0]
         │
         │ Service & Payment Complete
         ▼
    ┌─────────────────────────────────┐
    │  7.1 CREATE JOB HISTORY         │
    │  ──────────────────────────────│
    │  • Create mechanic history      │
    │  • Create customer history      │
    │  • Record service details       │
    │  • Record financial details     │
    └─────────────┬───────────────────┘
                  │
                  │ ◄──────────────────────────────────────── D10: service_requests
                  │ ◄──────────────────────────────────────── D26: invoices
                  │ ◄──────────────────────────────────────── D29: payments
                  │
                  │ ─────────────────────────────────────────► D32: mechanic_job_history
                  │                                             (all mechanic history fields)
                  │
                  │ ─────────────────────────────────────────► D33: customer_job_history
                  │                                             (all customer history fields)
                  ▼
    ┌─────────────────────────────────┐
    │  7.2 REQUEST CUSTOMER REVIEW    │
    │  ──────────────────────────────│
    │  • Send review notification     │
    │  • Display in-app prompt        │
    │  • Set review expiration        │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D11: notifications
                  │                                             (review request notification)
                  ▼
    ┌─────────────────────────────────┐
    │  7.3 SUBMIT RATING & REVIEW     │ ◄──────── [CUSTOMER] Submit Review
    │  ──────────────────────────────│
    │  • Capture star rating (1-5)    │
    │  • Capture review text          │
    │  • Validate review content      │
    │  • Save review record           │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D34: reviews
                  │                                             (rating, comment, request_id)
                  ▼
    ┌─────────────────────────────────┐
    │  7.4 UPDATE PROVIDER RATING     │
    │  ──────────────────────────────│
    │  • Calculate average rating     │
    │  • Update mechanic rating       │
    │  • Update shop rating           │
    │  • Update provider profile      │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D14: service_providers
                  │                                             (rating = AVG(all ratings))
                  │
                  │ ─────────────────────────────────────────► D12: shops
                  │                                             (rating = AVG(all ratings))
                  │
                  │ ─────────────────────────────────────────► D2: user_profiles
                  │                                             (mechanic rating)
                  ▼
    ┌─────────────────────────────────┐
    │  7.5 UPDATE HISTORY WITH REVIEW │
    │  ──────────────────────────────│
    │  • Add rating to job history    │
    │  • Add review text              │
    │  • Update history records       │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D32: mechanic_job_history
                  │                                             (rating, review_text)
                  │
                  │ ─────────────────────────────────────────► D33: customer_job_history
                  │                                             (rating, review_text)
                  ▼
    ┌─────────────────────────────────┐
    │  7.6 GENERATE ANALYTICS         │
    │  ──────────────────────────────│
    │  • Update provider performance  │
    │  • Update service metrics       │
    │  • Update customer satisfaction │
    │  • Log for reporting            │
    └─────────────┬───────────────────┘
                  │
                  │ ─────────────────────────────────────────► D6: audit_logs
                  │                                             (analytics data)
                  ▼
              [END FLOW]
```

---

## 📊 Complete Data Store Inventory

| ID | Data Store | Description | Primary Entity |
|----|------------|-------------|----------------|
| D1 | auth.users | User authentication records | auth.users |
| D2 | user_profiles | User profile information | user_profiles |
| D3 | email_verification_tokens | Email verification tokens | email_verification_tokens |
| D4 | account_security_logs | Security event logs | account_security_logs |
| D5 | password_reset_tokens | Password reset tokens | password_reset_tokens |
| D6 | audit_logs | System audit trail | audit_logs |
| D7 | vehicles | Customer vehicles | vehicles |
| D8 | service_categories | Service types | service_categories |
| D9 | distance_pricing_config | Pricing configuration | distance_pricing_config |
| D10 | service_requests | Service request records | service_requests |
| D11 | notifications | User notifications | notifications |
| D12 | shops | Shop information | shops |
| D13 | shop_mechanics | Shop-mechanic assignments | shop_mechanics |
| D14 | service_providers | Provider profiles | service_providers |
| D15 | mechanic_availability_status | Real-time availability | mechanic_availability_status |
| D16 | request_broadcasts | Broadcast notifications | request_broadcasts |
| D17 | request_routing | Request routing records | request_routing |
| D18 | shop_notifications | Shop notifications | shop_notifications |
| D19 | active_routes | Active route tracking | active_routes |
| D20 | progress_photos | Service documentation | progress_photos |
| D21 | service_phase_tracking | Phase tracking | service_phase_tracking |
| D22 | messages | Chat messages | messages |
| D23 | job_completion_codes | Completion codes | job_completion_codes |
| D24 | service_completions | QR completions | service_completions |
| D25 | app_settings | Application settings | app_settings |
| D26 | invoices | Invoice records | invoices |
| D27 | email_notifications | Email logs | email_notifications |
| D28 | cash_payment_verifications | Cash verifications | cash_payment_verifications |
| D29 | payments | Payment transactions | payments |
| D30 | admin_activity_logs | Admin action logs | admin_activity_logs |
| D31 | payment_releases | Payment releases | payment_releases |
| D32 | mechanic_job_history | Mechanic job history | mechanic_job_history |
| D33 | customer_job_history | Customer job history | customer_job_history |
| D34 | reviews | Rating and reviews | reviews |

---

## 🔄 Data Flow Summary

### Main Data Flows

| Flow ID | Source | Process | Destination | Data |
|---------|--------|---------|-------------|------|
| F1 | Customer | 1.0 | auth.users | Registration data |
| F2 | Customer | 2.0 | service_requests | Service request |
| F3 | System | 3.0 | request_broadcasts | Broadcast data |
| F4 | Mechanic | 4.0 | progress_photos | Service photos |
| F5 | Customer | 5.0 | payments | Payment data |
| F6 | Admin | 6.0 | payment_releases | Release approval |
| F7 | Customer | 7.0 | reviews | Rating & review |

### Cross-Process Data Flows

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    CROSS-PROCESS DATA FLOW MAP                                          │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

    PROCESS 1.0 ─────► user_profiles ─────► PROCESS 2.0
    (Registration)                          (Service Request)
         │                                       │
         ▼                                       ▼
    auth.users ◄─────────────────────────► service_requests
         │                                       │
         ▼                                       ▼
    PROCESS 3.0 ─────► request_broadcasts ────► PROCESS 4.0
    (Routing)                                   (Execution)
         │                                       │
         ▼                                       ▼
    service_providers ◄──────────────────► progress_photos
         │                                       │
         ▼                                       ▼
    PROCESS 5.0 ─────► invoices ─────────────► PROCESS 6.0
    (Billing)                                   (Release)
         │                                       │
         ▼                                       ▼
    payments ◄───────────────────────────► payment_releases
         │                                       │
         ▼                                       ▼
    PROCESS 7.0 ─────► reviews ─────────────► user_profiles
    (History)                                   (Rating Update)
```

---

## 📊 DFD-ERD Connection Map

This section shows how DFD Data Stores map to ERD Entities:

| DFD Data Store | ERD Entity | Relationship |
|----------------|------------|--------------|
| D1: auth.users | auth.users | 1:1 Direct |
| D2: user_profiles | user_profiles | 1:1 Direct |
| D10: service_requests | service_requests | 1:1 Direct |
| D12: shops | shops | 1:1 Direct |
| D14: service_providers | service_providers | 1:1 Direct |
| D26: invoices | invoices | 1:1 Direct |
| D29: payments | payments | 1:1 Direct |
| D34: reviews | reviews | 1:1 Direct |

---

## 🎯 Key Process-Entity Interactions

### Process 2.0: Service Request Management
```
┌─────────────────────────────────────────────────────────────────┐
│                  ENTITIES INVOLVED                              │
├─────────────────────────────────────────────────────────────────┤
│  READ:   user_profiles, vehicles, service_categories,          │
│          distance_pricing_config, shops                         │
│                                                                 │
│  WRITE:  service_requests, notifications, vehicles (if new)    │
└─────────────────────────────────────────────────────────────────┘
```

### Process 5.0: Billing & Payment
```
┌─────────────────────────────────────────────────────────────────┐
│                  ENTITIES INVOLVED                              │
├─────────────────────────────────────────────────────────────────┤
│  READ:   service_requests, app_settings, user_profiles         │
│                                                                 │
│  WRITE:  invoices, payments, cash_payment_verifications,       │
│          notifications, email_notifications                     │
└─────────────────────────────────────────────────────────────────┘
```

---

**Legend:**
- **→** Data flow direction
- **[Entity]** External entity
- **D#** Data store reference
- **◄──** Read operation
- **──►** Write operation
- **Process X.X** Sub-process

---

**Document Version:** 2.0  
**Last Updated:** January 19, 2026  
**Author:** System Documentation
