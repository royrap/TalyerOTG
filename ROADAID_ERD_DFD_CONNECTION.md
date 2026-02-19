# 🔗 RoadAid System - ERD & DFD Connection Document

**Date Created:** January 19, 2026  
**System:** RoadAid - Comprehensive Roadside Assistance Platform  
**Version:** 2.0 - Enhanced Edition

---

## 📊 Overview

This document establishes the connection between the Entity Relationship Diagram (ERD) and Data Flow Diagram (DFD) for the RoadAid system. It provides a comprehensive mapping of how data entities are used across different system processes.

---

## 🔗 ERD-to-DFD Mapping Matrix

### Core Entities Mapping

| ERD Entity | DFD Data Store ID | Primary Processes | Operations |
|------------|-------------------|-------------------|------------|
| auth.users | D1 | 1.0, 8.0 | INSERT, SELECT, UPDATE |
| user_profiles | D2 | 1.0, 2.0, 3.0, 4.0, 7.0 | INSERT, SELECT, UPDATE |
| shops | D12 | 3.0, 6.0, 7.0, 8.0 | INSERT, SELECT, UPDATE |
| service_providers | D14 | 3.0, 4.0, 6.0, 7.0 | INSERT, SELECT, UPDATE |
| vehicles | D7 | 2.0 | INSERT, SELECT |
| service_categories | D8 | 2.0, 5.0 | SELECT |
| service_requests | D10 | 2.0, 3.0, 4.0, 5.0, 6.0, 7.0 | INSERT, SELECT, UPDATE |

### Financial Entities Mapping

| ERD Entity | DFD Data Store ID | Primary Processes | Operations |
|------------|-------------------|-------------------|------------|
| invoices | D26 | 5.0, 6.0, 7.0 | INSERT, SELECT, UPDATE |
| payments | D29 | 5.0, 6.0, 7.0 | INSERT, SELECT, UPDATE |
| payment_releases | D31 | 6.0 | INSERT, SELECT, UPDATE |
| cash_payment_verifications | D28 | 5.0 | INSERT, SELECT, UPDATE |

### Supporting Entities Mapping

| ERD Entity | DFD Data Store ID | Primary Processes | Operations |
|------------|-------------------|-------------------|------------|
| notifications | D11 | 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0 | INSERT, SELECT, UPDATE |
| messages | D22 | 4.0 | INSERT, SELECT |
| reviews | D34 | 7.0 | INSERT, SELECT |
| progress_photos | D20 | 4.0 | INSERT, SELECT |
| request_broadcasts | D16 | 3.0 | INSERT, SELECT, UPDATE |

---

## 📈 Process-Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              PROCESS-ENTITY RELATIONSHIP DIAGRAM                                         │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

                                        ┌─────────────┐
                                        │ auth.users  │
                                        │    D1       │
                                        └──────┬──────┘
                                               │
                                     ┌─────────┴─────────┐
                                     │                   │
                              ┌──────▼──────┐     ┌──────▼──────┐
                              │ PROCESS 1.0 │     │  account_   │
                              │ Auth & User │     │  security_  │
                              │ Management  │     │  logs D4    │
                              └──────┬──────┘     └─────────────┘
                                     │
                              ┌──────▼──────┐
                              │user_profiles│
                              │    D2       │
                              └──────┬──────┘
                                     │
        ┌──────────────┬─────────────┼─────────────┬──────────────┐
        │              │             │             │              │
 ┌──────▼──────┐┌──────▼──────┐┌─────▼─────┐┌─────▼─────┐┌───────▼───────┐
 │  vehicles   ││   shops     ││  service_ ││ notifi-   ││   reviews     │
 │    D7       ││    D12      ││  providers││  cations  ││     D34       │
 └──────┬──────┘└──────┬──────┘│    D14    ││    D11    │└───────────────┘
        │              │       └─────┬─────┘└───────────┘
        │              │             │
        │       ┌──────┼─────────────┘
        │       │      │
 ┌──────▼───────▼──────▼──────┐
 │       PROCESS 2.0          │
 │   Service Request Mgmt     │
 │  (service_categories D8)   │
 │  (distance_pricing D9)     │
 └────────────┬───────────────┘
              │
       ┌──────▼──────┐
       │  service_   │
       │  requests   │
       │    D10      │
       └──────┬──────┘
              │
 ┌────────────┼────────────────────────────────────────┐
 │            │                                        │
 │     ┌──────▼──────┐                          ┌──────▼──────┐
 │     │ PROCESS 3.0 │                          │ PROCESS 4.0 │
 │     │  Routing &  │                          │  Service    │
 │     │ Broadcasting│                          │  Execution  │
 │     └──────┬──────┘                          └──────┬──────┘
 │            │                                        │
 │     ┌──────▼──────┐                          ┌──────▼──────┐
 │     │  request_   │                          │  progress_  │
 │     │ broadcasts  │                          │   photos    │
 │     │    D16      │                          │    D20      │
 │     └─────────────┘                          └─────────────┘
 │                                                     │
 │            ┌────────────────────────────────────────┘
 │            │
 │     ┌──────▼──────┐
 │     │ PROCESS 5.0 │
 │     │  Billing &  │
 │     │  Payment    │
 │     └──────┬──────┘
 │            │
 │     ┌──────┴──────┐
 │     │             │
 │┌────▼────┐ ┌──────▼──────┐
 ││invoices │ │  payments   │
 ││   D26   │ │    D29      │
 │└────┬────┘ └──────┬──────┘
 │     │             │
 │     └──────┬──────┘
 │            │
 │     ┌──────▼──────┐
 │     │ PROCESS 6.0 │
 │     │  Payment    │
 │     │  Release    │
 │     └──────┬──────┘
 │            │
 │     ┌──────▼──────┐
 │     │  payment_   │
 │     │  releases   │
 │     │    D31      │
 │     └──────┬──────┘
 │            │
 └────────────┘
              │
       ┌──────▼──────┐
       │ PROCESS 7.0 │
       │  History &  │
       │  Reviews    │
       └──────┬──────┘
              │
       ┌──────┴──────┐
       │             │
┌──────▼──────┐┌─────▼─────┐
│  mechanic_  ││ customer_ │
│ job_history ││job_history│
│    D32      ││   D33     │
└─────────────┘└───────────┘
```

---

## 🔄 Data Flow Through Entities

### Complete Service Request Lifecycle

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                           SERVICE REQUEST LIFECYCLE - DATA FLOW                                          │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

 PHASE 1: REQUEST CREATION
 ─────────────────────────
 
    Customer ──► [auth.users] ──► [user_profiles] ──► [vehicles]
                      │                │                   │
                      │                │                   │
                      └───────┬────────┴───────────────────┘
                              │
                              ▼
                     ┌─────────────────┐
                     │ service_requests │◄──── [service_categories]
                     │    (CREATED)     │◄──── [distance_pricing_config]
                     └────────┬────────┘
                              │
                              
 PHASE 2: ROUTING & ASSIGNMENT
 ─────────────────────────────
 
                              │
                              ▼
                     ┌─────────────────┐
                     │ service_requests │──────► [request_broadcasts]
                     │   (ACCEPTED)     │◄────── [service_providers]
                     └────────┬────────┘◄────── [shops]
                              │         ◄────── [mechanic_availability_status]
                              │
                              
 PHASE 3: SERVICE EXECUTION
 ──────────────────────────
 
                              │
                              ▼
                     ┌─────────────────┐
                     │ service_requests │──────► [progress_photos]
                     │  (IN_PROGRESS)   │──────► [messages]
                     └────────┬────────┘──────► [service_phase_tracking]
                              │
                              ▼
                     ┌─────────────────┐
                     │ service_requests │──────► [job_completion_codes]
                     │   (COMPLETED)    │──────► [service_completions]
                     └────────┬────────┘
                              │
                              
 PHASE 4: BILLING & PAYMENT
 ──────────────────────────
 
                              │
                              ▼
                     ┌─────────────────┐
                     │    invoices      │◄────── service_requests
                     │   (GENERATED)    │──────► [notifications]
                     └────────┬────────┘
                              │
                              ▼
                     ┌─────────────────┐
                     │    payments      │◄────── PayMongo Gateway
                     │    (PAID)        │──────► [cash_payment_verifications]
                     └────────┬────────┘
                              │
                              
 PHASE 5: SETTLEMENT & HISTORY
 ─────────────────────────────
 
                              │
                              ▼
                     ┌─────────────────┐
                     │ payment_releases │──────► [service_providers] (earnings)
                     │   (RELEASED)     │──────► [shops] (revenue)
                     └────────┬────────┘
                              │
                              ▼
                     ┌─────────────────┐
                     │mechanic_job_hist│◄────── service_requests
                     │customer_job_hist│◄────── invoices
                     └────────┬────────┘◄────── payments
                              │
                              ▼
                     ┌─────────────────┐
                     │    reviews       │──────► [service_providers] (rating)
                     │   (SUBMITTED)    │──────► [shops] (rating)
                     └─────────────────┘──────► [user_profiles] (rating)
```

---

## 📊 Entity Usage by Process

### Process 1.0: User Authentication & Management

| Operation | Entity | Fields Used | Trigger |
|-----------|--------|-------------|---------|
| INSERT | auth.users | email, encrypted_password | Registration |
| INSERT | user_profiles | first_name, last_name, email, user_type | Registration |
| INSERT | account_security_logs | user_id, action_type, ip_address | Login/Logout |
| INSERT | password_reset_tokens | user_id, token, expires_at | Password Reset |
| UPDATE | user_profiles | profile fields | Profile Update |

### Process 2.0: Service Request Management

| Operation | Entity | Fields Used | Trigger |
|-----------|--------|-------------|---------|
| SELECT | user_profiles | id, current_location | Request Creation |
| SELECT | vehicles | user_id, brand, model, plate | Vehicle Selection |
| SELECT | service_categories | id, name, base_price | Service Selection |
| SELECT | distance_pricing_config | rates, multipliers | Fee Calculation |
| INSERT | service_requests | all request fields | Request Submission |
| INSERT | notifications | user_id, title, body | Request Confirmation |

### Process 3.0: Request Routing & Broadcasting

| Operation | Entity | Fields Used | Trigger |
|-----------|--------|-------------|---------|
| SELECT | shops | id, location, service_radius, status | Find Shops |
| SELECT | service_providers | id, location, availability | Find Mechanics |
| SELECT | mechanic_availability_status | status, is_accepting | Check Availability |
| INSERT | request_broadcasts | request_id, provider_id, distance | Create Broadcast |
| UPDATE | request_broadcasts | response_status | Provider Response |
| UPDATE | service_requests | provider_id, status | Assignment |

### Process 4.0: Service Execution & Tracking

| Operation | Entity | Fields Used | Trigger |
|-----------|--------|-------------|---------|
| UPDATE | service_requests | status | Status Change |
| UPDATE | user_profiles | current_latitude, current_longitude | Location Update |
| INSERT | progress_photos | request_id, image_url, phase | Photo Upload |
| INSERT | messages | request_id, sender_id, message | Send Message |
| INSERT | job_completion_codes | request_id, completion_code | Completion |
| INSERT | service_completions | request_id, qr_code_data | QR Generation |

### Process 5.0: Billing & Payment Processing

| Operation | Entity | Fields Used | Trigger |
|-----------|--------|-------------|---------|
| SELECT | service_requests | final_price, service details | Invoice Generation |
| INSERT | invoices | all invoice fields | Generate Invoice |
| INSERT | payments | amount, payment_method, status | Process Payment |
| INSERT | cash_payment_verifications | cash_photo_url | Cash Payment |
| UPDATE | invoices | status, paid_at | Payment Complete |

### Process 6.0: Payment Release & Settlement

| Operation | Entity | Fields Used | Trigger |
|-----------|--------|-------------|---------|
| INSERT | payment_releases | payment_id, provider_amount | Create Release |
| UPDATE | payment_releases | release_status, released_at | Release Approval |
| UPDATE | service_providers | total_earnings | Update Earnings |
| UPDATE | shops | total_revenue | Update Revenue |

### Process 7.0: History & Review Management

| Operation | Entity | Fields Used | Trigger |
|-----------|--------|-------------|---------|
| INSERT | mechanic_job_history | all history fields | Service Complete |
| INSERT | customer_job_history | all history fields | Service Complete |
| INSERT | reviews | rating, comment | Review Submission |
| UPDATE | service_providers | rating | Rating Update |
| UPDATE | shops | rating | Rating Update |

---

## 🔐 Data Integrity Relationships

### Foreign Key Enforcement in DFD Processes

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              FOREIGN KEY CONSTRAINTS IN DATA FLOWS                                       │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

PROCESS 2.0: Service Request Creation
─────────────────────────────────────
    service_requests.customer_id ──FK──► user_profiles.id     (Must exist)
    service_requests.vehicle_id ──FK──► vehicles.id           (Must exist)
    service_requests.category_id ──FK──► service_categories.id (Must exist)

PROCESS 3.0: Request Routing
────────────────────────────
    service_requests.shop_id ──FK──► shops.id                 (Can be null)
    service_requests.provider_id ──FK──► service_providers.id (Set on assignment)
    request_broadcasts.request_id ──FK──► service_requests.id (Must exist)

PROCESS 5.0: Billing & Payment
──────────────────────────────
    invoices.request_id ──FK──► service_requests.id           (Must exist)
    payments.invoice_id ──FK──► invoices.id                   (Must exist)
    payments.customer_id ──FK──► user_profiles.id             (Must exist)

PROCESS 6.0: Payment Release
────────────────────────────
    payment_releases.payment_id ──FK──► payments.id           (Must exist)
    payment_releases.provider_id ──FK──► service_providers.id (Must exist)

PROCESS 7.0: History & Reviews
──────────────────────────────
    mechanic_job_history.service_request_id ──FK──► service_requests.id (Must exist)
    reviews.request_id ──FK──► service_requests.id            (Must exist)
```

---

## 📈 Entity State Transitions Through Processes

### service_requests Status Flow

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                           SERVICE_REQUESTS STATUS TRANSITIONS                                            │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘

    PROCESS 2.0                 PROCESS 3.0                PROCESS 4.0
    ───────────                 ───────────                ───────────
    
    ┌──────────┐               ┌──────────┐               ┌──────────┐
    │  pending │──────────────►│ accepted │──────────────►│ en_route │
    └──────────┘               └──────────┘               └────┬─────┘
         │                                                     │
         │                                                     ▼
         │                                                ┌──────────┐
         │                                                │ arrived  │
         │                                                └────┬─────┘
         │                                                     │
         │                                                     ▼
         │                                                ┌──────────┐
         │                                                │in_progress│
         │                                                └────┬─────┘
         │                                                     │
         │                                                     ▼
         │     PROCESS 4.0                                ┌──────────┐
         │     ───────────                                │awaiting_ │
         │                                                │verification│
         │                                                └────┬─────┘
         │                                                     │
         │                                                     ▼
         │     PROCESS 5.0                                ┌──────────┐
         │     ───────────                                │ completed│
         │                                                └────┬─────┘
         │                                                     │
         │                                                     ▼
         │                                                ┌──────────┐
         └─────────[cancelled]───────────────────────────►│ paid     │
                                                          └──────────┘
```

### invoices Status Flow

```
    PROCESS 5.0
    ───────────
    
    ┌───────────┐          ┌───────┐          ┌──────┐          ┌──────────┐
    │ generated │─────────►│ sent  │─────────►│ paid │─────────►│ released │
    └───────────┘          └───────┘          └──────┘          └──────────┘
         │
         │
         └────────────────────────────►  [disputed]
```

### payments Status Flow

```
    PROCESS 5.0                           PROCESS 6.0
    ───────────                           ───────────
    
    ┌─────────┐          ┌───────────┐          ┌─────────┐
    │ pending │─────────►│ completed │─────────►│ released│
    └─────────┘          └───────────┘          └─────────┘
         │
         │
         ├────────────►  [failed]
         │
         └────────────►  [refunded]
```

---

## 🎯 Data Store CRUD Matrix

| Data Store | Create (C) | Read (R) | Update (U) | Delete (D) | Processes |
|------------|------------|----------|------------|------------|-----------|
| auth.users | ✅ | ✅ | ✅ | ❌ | 1.0 |
| user_profiles | ✅ | ✅ | ✅ | ❌ | 1.0, 2.0, 4.0, 7.0 |
| shops | ✅ | ✅ | ✅ | ❌ | 3.0, 6.0, 7.0, 8.0 |
| service_providers | ✅ | ✅ | ✅ | ❌ | 3.0, 6.0, 7.0 |
| vehicles | ✅ | ✅ | ✅ | ✅ | 2.0 |
| service_categories | ✅ | ✅ | ✅ | ❌ | 2.0, 8.0 |
| service_requests | ✅ | ✅ | ✅ | ❌ | 2.0-7.0 |
| invoices | ✅ | ✅ | ✅ | ❌ | 5.0, 6.0 |
| payments | ✅ | ✅ | ✅ | ❌ | 5.0, 6.0 |
| payment_releases | ✅ | ✅ | ✅ | ❌ | 6.0 |
| notifications | ✅ | ✅ | ✅ | ✅ | 1.0-7.0 |
| messages | ✅ | ✅ | ✅ | ❌ | 4.0 |
| reviews | ✅ | ✅ | ✅ | ❌ | 7.0 |
| progress_photos | ✅ | ✅ | ❌ | ❌ | 4.0 |
| request_broadcasts | ✅ | ✅ | ✅ | ❌ | 3.0 |
| job_completion_codes | ✅ | ✅ | ✅ | ❌ | 4.0 |
| mechanic_job_history | ✅ | ✅ | ✅ | ❌ | 7.0 |
| customer_job_history | ✅ | ✅ | ✅ | ❌ | 7.0 |
| audit_logs | ✅ | ✅ | ❌ | ❌ | 1.0-8.0 |

---

## 📋 Summary

This connection document demonstrates:

1. **Complete ERD-DFD Mapping**: Every ERD entity maps to a DFD data store
2. **Process-Entity Relationships**: Clear definition of which processes use which entities
3. **Data Flow Traceability**: End-to-end tracking of data through the system
4. **Foreign Key Integrity**: Constraint enforcement in data flows
5. **State Transitions**: Entity status changes across processes
6. **CRUD Operations**: Complete operation matrix for all data stores

---

## 📚 Related Documents

| Document | Description |
|----------|-------------|
| [ROADAID_NEW_ERD.md](ROADAID_NEW_ERD.md) | Complete Entity Relationship Diagram |
| [ROADAID_NEW_DFD.md](ROADAID_NEW_DFD.md) | Complete Data Flow Diagram |
| [DATABASE_SCHEMA.sql](DATABASE_SCHEMA.sql) | SQL Schema Definition |
| [COMPLETE_ROADAID_DATABASE_SCHEMA.sql](COMPLETE_ROADAID_DATABASE_SCHEMA.sql) | Full Database Schema |

---

**Document Version:** 2.0  
**Last Updated:** January 19, 2026  
**Author:** System Documentation
