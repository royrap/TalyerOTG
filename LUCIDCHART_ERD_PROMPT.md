# 📊 Lucidchart ERD Clean Layout Prompt - RoadAid System

---

## 🎯 COPY THIS PROMPT TO LUCIDCHART AI

```
Create a CLEAN ERD for RoadAid with NO LINE CROSSINGS.

=== 24 ENTITIES (ALL INCLUDED) ===

ROW 1 - AUTHENTICATION (Top):
AUTH_USERS | ACCOUNT_SECURITY_LOGS | ADMIN_ACTIVITY_LOGS

ROW 2 - USER MANAGEMENT:
USER_PROFILES | VEHICLES | NOTIFICATIONS | AUDIT_LOGS | TALYER_OWNER_VERIFICATIONS

ROW 3 - SHOP MANAGEMENT:
SHOPS | SHOP_MECHANICS | SHOP_SERVICES | MECHANIC_INVITATIONS | SERVICE_CATEGORIES

ROW 4 - PROVIDERS:
SERVICE_PROVIDERS | BUSINESS_PERMITS

ROW 5 - CENTER (Main Hub):
SERVICE_REQUESTS (LARGEST - CENTER)

ROW 6 - REQUEST OUTPUTS:
REQUEST_BROADCASTS | JOB_COMPLETION_CODES | SERVICE_COMPLETIONS | REVIEWS

ROW 7 - FINANCIAL:
INVOICES | PAYMENTS | CASH_PAYMENT_VERIFICATIONS

ROW 8 - HISTORY & CONFIG:
MECHANIC_JOB_HISTORY | CUSTOMER_JOB_HISTORY | DISTANCE_PRICING_CONFIG


=== ALL 24 ENTITIES WITH ATTRIBUTES ===

1. AUTH_USERS
   - id (PK, UUID)
   - email (UNIQUE, VARCHAR)
   - encrypted_password (VARCHAR)
   - created_at (TIMESTAMP)

2. USER_PROFILES
   - id (PK, FK → auth_users.id, UUID)
   - first_name (VARCHAR)
   - last_name (VARCHAR)
   - email (UNIQUE, VARCHAR)
   - phone_number (VARCHAR)
   - user_type (VARCHAR) "customer/mechanic/talyer_owner/admin"
   - profile_image_url (TEXT)
   - current_latitude (NUMERIC)
   - current_longitude (NUMERIC)
   - shop_id (FK → shops.id, UUID)
   - status (VARCHAR)
   - rating (NUMERIC)
   - created_at (TIMESTAMP)
   - updated_at (TIMESTAMP)

3. SHOPS
   - id (PK, UUID)
   - owner_id (FK → user_profiles.id, UNIQUE, UUID)
   - shop_name (VARCHAR)
   - shop_address (TEXT)
   - shop_phone (VARCHAR)
   - shop_email (VARCHAR)
   - latitude (NUMERIC)
   - longitude (NUMERIC)
   - service_radius (NUMERIC)
   - business_hours (JSONB)
   - current_status (VARCHAR) "open/closed/busy"
   - rating (NUMERIC)
   - is_active (BOOLEAN)
   - created_at (TIMESTAMP)

4. SERVICE_PROVIDERS
   - id (PK, UUID)
   - user_id (FK → user_profiles.id, UNIQUE, UUID)
   - shop_id (FK → shops.id, UUID)
   - talyer_owner_id (FK → user_profiles.id, UUID)
   - company_name (VARCHAR)
   - rating (NUMERIC)
   - service_radius (NUMERIC)
   - is_verified (BOOLEAN)
   - is_available (BOOLEAN)
   - current_latitude (NUMERIC)
   - current_longitude (NUMERIC)
   - status (VARCHAR)
   - created_at (TIMESTAMP)

5. VEHICLES
   - id (PK, UUID)
   - user_id (FK → user_profiles.id, UUID)
   - brand_name (VARCHAR)
   - model_name (VARCHAR)
   - year (INTEGER)
   - plate_number (VARCHAR)
   - vehicle_type (VARCHAR) "car/motorcycle/truck"
   - is_primary (BOOLEAN)
   - created_at (TIMESTAMP)

6. SERVICE_CATEGORIES
   - id (PK, UUID)
   - name (UNIQUE, VARCHAR)
   - description (TEXT)
   - base_price (NUMERIC)
   - estimated_duration (INTEGER)
   - category_type (VARCHAR)
   - is_active (BOOLEAN)

7. SERVICE_REQUESTS (CENTRAL HUB - MAKE LARGEST)
   - id (PK, UUID)
   - customer_id (FK → user_profiles.id, UUID)
   - provider_id (FK → service_providers.id, UUID)
   - vehicle_id (FK → vehicles.id, UUID)
   - category_id (FK → service_categories.id, UUID)
   - shop_id (FK → shops.id, UUID)
   - assigned_mechanic_id (FK → user_profiles.id, UUID)
   - title (VARCHAR)
   - description (TEXT)
   - status (VARCHAR)
   - pickup_latitude (NUMERIC)
   - pickup_longitude (NUMERIC)
   - pickup_address (TEXT)
   - service_fee (NUMERIC)
   - estimated_price (NUMERIC)
   - final_price (NUMERIC)
   - payment_status (VARCHAR)
   - request_type (VARCHAR) "direct/shop_based/broadcast"
   - is_broadcast_request (BOOLEAN)
   - created_at (TIMESTAMP)
   - completed_at (TIMESTAMP)

8. INVOICES
   - id (PK, UUID)
   - request_id (FK → service_requests.id, UUID)
   - customer_id (FK → user_profiles.id, UUID)
   - mechanic_id (FK → user_profiles.id, UUID)
   - talyer_owner_id (FK → user_profiles.id, UUID)
   - provider_id (FK → service_providers.id, UUID)
   - invoice_number (UNIQUE, VARCHAR)
   - subtotal (NUMERIC)
   - platform_fee (NUMERIC)
   - total_amount (NUMERIC)
   - talyer_net_amount (NUMERIC)
   - provider_net_amount (NUMERIC)
   - status (VARCHAR) "generated/sent/paid"
   - selected_payment_method (VARCHAR)
   - generated_at (TIMESTAMP)
   - paid_at (TIMESTAMP)

9. PAYMENTS
   - id (PK, UUID)
   - request_id (FK → service_requests.id, UUID)
   - customer_id (FK → user_profiles.id, UUID)
   - provider_id (FK → service_providers.id, UUID)
   - invoice_id (FK → invoices.id, UUID)
   - amount (NUMERIC)
   - platform_fee (NUMERIC)
   - provider_amount (NUMERIC)
   - payment_method (VARCHAR)
   - transaction_id (VARCHAR)
   - status (VARCHAR) "pending/completed/failed"
   - payment_gateway (VARCHAR)
   - processed_at (TIMESTAMP)

10. CASH_PAYMENT_VERIFICATIONS
    - id (PK, UUID)
    - invoice_id (FK → invoices.id, UUID)
    - payment_id (FK → payments.id, UUID)
    - request_id (FK → service_requests.id, UUID)
    - customer_id (FK → user_profiles.id, UUID)
    - mechanic_id (FK → user_profiles.id, UUID)
    - verified_by (FK → auth_users.id, UUID)
    - cash_amount (NUMERIC)
    - cash_photo_url (TEXT)
    - verification_status (VARCHAR)
    - verified_at (TIMESTAMP)

11. SHOP_SERVICES
    - id (PK, UUID)
    - shop_id (FK → shops.id, UUID)
    - category_id (FK → service_categories.id, UUID)
    - service_name (VARCHAR)
    - description (TEXT)
    - base_price (NUMERIC)
    - custom_price (NUMERIC)
    - estimated_duration (INTEGER)
    - is_active (BOOLEAN)

12. SHOP_MECHANICS
    - id (PK, UUID)
    - shop_id (FK → shops.id, UUID)
    - mechanic_id (FK → user_profiles.id, UUID)
    - role (VARCHAR)
    - hourly_rate (NUMERIC)
    - is_active (BOOLEAN)
    - is_available (BOOLEAN)

13. MECHANIC_INVITATIONS
    - id (PK, UUID)
    - shop_owner_id (FK → user_profiles.id, UUID)
    - shop_id (FK → shops.id, UUID)
    - mechanic_user_id (FK → auth_users.id, UUID)
    - email (VARCHAR)
    - first_name (VARCHAR)
    - last_name (VARCHAR)
    - temporary_password (VARCHAR)
    - invitation_token (UNIQUE, VARCHAR)
    - status (VARCHAR)
    - expires_at (TIMESTAMP)

14. MECHANIC_JOB_HISTORY
    - id (PK, UUID)
    - mechanic_id (FK → user_profiles.id, UUID)
    - service_request_id (FK → service_requests.id, UUID)
    - customer_id (FK → user_profiles.id, UUID)
    - shop_id (FK → shops.id, UUID)
    - job_title (VARCHAR)
    - job_description (TEXT)
    - job_status (VARCHAR)
    - completed_at (TIMESTAMP)
    - total_amount (NUMERIC)
    - mechanic_earnings (NUMERIC)
    - shop_earnings (NUMERIC)
    - platform_fee (NUMERIC)
    - rating (NUMERIC)
    - review_text (TEXT)

15. CUSTOMER_JOB_HISTORY
    - id (PK, UUID)
    - customer_id (FK → user_profiles.id, UUID)
    - service_request_id (FK → service_requests.id, UUID)
    - mechanic_id (FK → user_profiles.id, UUID)
    - shop_id (FK → shops.id, UUID)
    - job_title (VARCHAR)
    - job_description (TEXT)
    - job_status (VARCHAR)
    - completed_at (TIMESTAMP)
    - total_amount (NUMERIC)
    - rating (NUMERIC)
    - review_text (TEXT)

16. NOTIFICATIONS
    - id (PK, UUID)
    - user_id (FK → user_profiles.id, UUID)
    - title (VARCHAR)
    - body (TEXT)
    - type (VARCHAR)
    - data (JSONB)
    - read (BOOLEAN)
    - created_at (TIMESTAMP)

17. REQUEST_BROADCASTS
    - id (PK, UUID)
    - request_id (FK → service_requests.id, UUID)
    - provider_id (FK → service_providers.id, UUID)
    - shop_id (FK → shops.id, UUID)
    - mechanic_id (FK → user_profiles.id, UUID)
    - provider_type (VARCHAR)
    - distance_km (NUMERIC)
    - notification_sent_at (TIMESTAMP)
    - response_status (VARCHAR)
    - responded_at (TIMESTAMP)

18. JOB_COMPLETION_CODES
    - id (PK, UUID)
    - request_id (FK → service_requests.id, UUID)
    - customer_id (FK → user_profiles.id, UUID)
    - used_by_provider_id (FK → service_providers.id, UUID)
    - completion_code (UNIQUE, VARCHAR)
    - is_used (BOOLEAN)
    - expires_at (TIMESTAMP)
    - used_at (TIMESTAMP)
    - verification_status (VARCHAR)

19. SERVICE_COMPLETIONS
    - id (PK, UUID)
    - request_id (FK → service_requests.id, UUID)
    - mechanic_id (FK → user_profiles.id, UUID)
    - customer_id (FK → user_profiles.id, UUID)
    - completion_code (UNIQUE, VARCHAR)
    - qr_code_data (TEXT)
    - is_scanned (BOOLEAN)
    - scanned_at (TIMESTAMP)
    - verification_status (VARCHAR)

20. REVIEWS
    - id (PK, UUID)
    - request_id (FK → service_requests.id, UUID)
    - customer_id (FK → user_profiles.id, UUID)
    - provider_id (FK → service_providers.id, UUID)
    - rating (INTEGER) "1-5"
    - comment (TEXT)
    - response (TEXT)
    - is_verified (BOOLEAN)
    - created_at (TIMESTAMP)

21. TALYER_OWNER_VERIFICATIONS
    - id (PK, UUID)
    - user_id (FK → user_profiles.id, UNIQUE, UUID)
    - reviewed_by (FK → auth_users.id, UUID)
    - business_name (VARCHAR)
    - business_permit_url (TEXT)
    - valid_id_url (TEXT)
    - id_type (VARCHAR)
    - permit_expiry_date (DATE)
    - id_expiry_date (DATE)
    - status (VARCHAR)
    - admin_notes (TEXT)
    - verification_score (INTEGER)
    - reviewed_at (TIMESTAMP)
    - created_at (TIMESTAMP)

22. BUSINESS_PERMITS
    - id (PK, UUID)
    - provider_id (FK → service_providers.id, UUID)
    - verified_by (FK → auth_users.id, UUID)
    - business_permit_name (VARCHAR)
    - registered_address (TEXT)
    - receipt_no (UNIQUE, VARCHAR)
    - permit_document_url (TEXT)
    - is_verified (BOOLEAN)
    - verified_at (TIMESTAMP)

23. ADMIN_ACTIVITY_LOGS
    - id (PK, UUID)
    - admin_id (FK → auth_users.id, UUID)
    - action_type (VARCHAR)
    - target_type (VARCHAR)
    - target_id (UUID)
    - action_details (JSONB)
    - ip_address (VARCHAR)
    - created_at (TIMESTAMP)

24. AUDIT_LOGS
    - id (PK, UUID)
    - user_id (FK → user_profiles.id, UUID)
    - role (VARCHAR)
    - action (VARCHAR)
    - table_name (VARCHAR)
    - record_id (UUID)
    - old_values (JSONB)
    - new_values (JSONB)
    - created_at (TIMESTAMP)

25. ACCOUNT_SECURITY_LOGS
    - id (PK, UUID)
    - user_id (FK → auth_users.id, UUID)
    - action_type (VARCHAR)
    - ip_address (VARCHAR)
    - user_agent (TEXT)
    - success (BOOLEAN)
    - created_at (TIMESTAMP)

26. DISTANCE_PRICING_CONFIG (standalone)
    - id (PK, UUID)
    - base_rate_per_km (NUMERIC)
    - minimum_service_fee (NUMERIC)
    - maximum_service_fee (NUMERIC)
    - emergency_multiplier (NUMERIC)
    - is_active (BOOLEAN)


=== ALL RELATIONSHIPS (34 total) ===

FROM AUTH_USERS (3 lines):
1. auth_users ──"profile"──► user_profiles
2. auth_users ──"security_logs"──► account_security_logs
3. auth_users ──"admin_actions"──► admin_activity_logs

FROM USER_PROFILES (7 lines):
4. user_profiles ──"owns"──► shops
5. user_profiles ──"is"──► service_providers
6. user_profiles ──"owns"──► vehicles
7. user_profiles ──"receives"──► notifications
8. user_profiles ──"owner_verification"──► talyer_owner_verifications
9. user_profiles ──"audit"──► audit_logs
10. user_profiles ──"creates"──► service_requests

FROM SHOPS (5 lines):
11. shops ──"offers"──► shop_services
12. shops ──"employs"──► shop_mechanics
13. shops ──"has"──► mechanic_invitations
14. shops ──"has"──► service_providers
15. shops ──"fulfills"──► service_requests

FROM SERVICE_CATEGORIES (2 lines):
16. service_categories ──"categorized"──► shop_services
17. service_categories ──"categorizes"──► service_requests

FROM VEHICLES (1 line):
18. vehicles ──"used_for"──► service_requests

FROM SERVICE_PROVIDERS (4 lines):
19. service_providers ──"permits"──► business_permits
20. service_providers ──"handles"──► service_requests
21. service_providers ──"broadcasts"──► request_broadcasts
22. service_providers ──"fulfills"──► reviews

FROM SERVICE_REQUESTS (8 lines - CENTRAL HUB):
23. service_requests ──"generates"──► invoices
24. service_requests ──"broadcasts"──► request_broadcasts
25. service_requests ──"completion_code"──► job_completion_codes
26. service_requests ──"completion"──► service_completions
27. service_requests ──"reviews"──► reviews
28. service_requests ──"mechanic_history"──► mechanic_job_history
29. service_requests ──"customer_history"──► customer_job_history
30. service_requests ──"mechanic"──► shop_mechanics (via assigned_mechanic_id)

FROM INVOICES (2 lines):
31. invoices ──"paid_by"──► payments
32. invoices ──"cash_verify"──► cash_payment_verifications

FROM PAYMENTS (1 line):
33. payments ──"cash_verify"──► cash_payment_verifications

FROM MECHANIC_INVITATIONS (1 line):
34. mechanic_invitations ──"has"──► auth_users (mechanic_user_id)


=== LAYOUT RULES ===
1. NO crossing lines
2. ORTHOGONAL connectors (90-degree angles only)
3. SERVICE_REQUESTS = CENTER, LARGEST box
4. Flow: TOP → BOTTOM (Auth → Users → Shops → Requests → Payments → History)
5. Equal spacing (50px minimum)
6. Route lines AROUND entities, never through

=== COLOR CODING ===
#E1BEE7 Purple: AUTH_USERS, ACCOUNT_SECURITY_LOGS, ADMIN_ACTIVITY_LOGS
#FFF9C4 Yellow: USER_PROFILES, VEHICLES, NOTIFICATIONS, TALYER_OWNER_VERIFICATIONS, AUDIT_LOGS
#BBDEFB Blue: SERVICE_REQUESTS (darker/bolder - main entity)
#C8E6C9 Green: SHOPS, SHOP_SERVICES, SHOP_MECHANICS, SERVICE_CATEGORIES, SERVICE_PROVIDERS, MECHANIC_INVITATIONS, BUSINESS_PERMITS
#FFE0B2 Orange: INVOICES, PAYMENTS, CASH_PAYMENT_VERIFICATIONS
#F8BBD9 Pink: REVIEWS, MECHANIC_JOB_HISTORY, CUSTOMER_JOB_HISTORY, JOB_COMPLETION_CODES, SERVICE_COMPLETIONS, REQUEST_BROADCASTS
#E0E0E0 Gray: DISTANCE_PRICING_CONFIG

=== LINE STYLE ===
- Crow's foot notation
- Line color: #666666
- 1px thickness
- Rounded corners

Title: "RoadAid - Roadside Assistance System ERD"
```

---

## ✅ ENTITY CHECKLIST (26 TOTAL)

| # | Entity | Included |
|---|--------|----------|
| 1 | AUTH_USERS | ✓ |
| 2 | USER_PROFILES | ✓ |
| 3 | SHOPS | ✓ |
| 4 | SERVICE_PROVIDERS | ✓ |
| 5 | VEHICLES | ✓ |
| 6 | SERVICE_CATEGORIES | ✓ |
| 7 | SERVICE_REQUESTS | ✓ |
| 8 | INVOICES | ✓ |
| 9 | PAYMENTS | ✓ |
| 10 | CASH_PAYMENT_VERIFICATIONS | ✓ |
| 11 | SHOP_SERVICES | ✓ |
| 12 | SHOP_MECHANICS | ✓ |
| 13 | MECHANIC_INVITATIONS | ✓ |
| 14 | MECHANIC_JOB_HISTORY | ✓ |
| 15 | CUSTOMER_JOB_HISTORY | ✓ |
| 16 | NOTIFICATIONS | ✓ |
| 17 | REQUEST_BROADCASTS | ✓ |
| 18 | JOB_COMPLETION_CODES | ✓ |
| 19 | SERVICE_COMPLETIONS | ✓ |
| 20 | REVIEWS | ✓ |
| 21 | TALYER_OWNER_VERIFICATIONS | ✓ |
| 22 | BUSINESS_PERMITS | ✓ |
| 23 | ADMIN_ACTIVITY_LOGS | ✓ |
| 24 | AUDIT_LOGS | ✓ |
| 25 | ACCOUNT_SECURITY_LOGS | ✓ |
| 26 | DISTANCE_PRICING_CONFIG | ✓ |

---

## ✅ RELATIONSHIP CHECKLIST (34 TOTAL)

| Label | From | To | ✓ |
|-------|------|-----|---|
| profile | auth_users | user_profiles | ✓ |
| security_logs | auth_users | account_security_logs | ✓ |
| admin_actions | auth_users | admin_activity_logs | ✓ |
| owns | user_profiles | shops | ✓ |
| is | user_profiles | service_providers | ✓ |
| owns | user_profiles | vehicles | ✓ |
| receives | user_profiles | notifications | ✓ |
| owner_verification | user_profiles | talyer_owner_verifications | ✓ |
| audit | user_profiles | audit_logs | ✓ |
| creates | user_profiles | service_requests | ✓ |
| offers | shops | shop_services | ✓ |
| employs | shops | shop_mechanics | ✓ |
| has | shops | mechanic_invitations | ✓ |
| has | shops | service_providers | ✓ |
| fulfills | shops | service_requests | ✓ |
| categorized | service_categories | shop_services | ✓ |
| categorizes | service_categories | service_requests | ✓ |
| used_for | vehicles | service_requests | ✓ |
| permits | service_providers | business_permits | ✓ |
| handles | service_providers | service_requests | ✓ |
| broadcasts | service_providers | request_broadcasts | ✓ |
| fulfills | service_providers | reviews | ✓ |
| generates | service_requests | invoices | ✓ |
| broadcasts | service_requests | request_broadcasts | ✓ |
| completion_code | service_requests | job_completion_codes | ✓ |
| completion | service_requests | service_completions | ✓ |
| reviews | service_requests | reviews | ✓ |
| mechanic_history | service_requests | mechanic_job_history | ✓ |
| customer_history | service_requests | customer_job_history | ✓ |
| mechanic | service_requests | shop_mechanics | ✓ |
| paid_by | invoices | payments | ✓ |
| cash_verify | invoices | cash_payment_verifications | ✓ |
| cash_verify | payments | cash_payment_verifications | ✓ |
| has | mechanic_invitations | auth_users | ✓ |

---

**Document Created:** January 19, 2026
