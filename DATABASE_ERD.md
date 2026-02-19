# RoadAid Database - Entity Relationship Diagram (ERD)

**Date:** October 10, 2025  
**Database Type:** PostgreSQL (Supabase)  
**Total Tables:** 66

---

## 📊 Core Entity Tables

### 1. **auth.users** (Supabase Authentication)
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | User authentication ID |
| email | text | UNIQUE | User email |
| encrypted_password | text | | Hashed password |
| created_at | timestamptz | | Account creation timestamp |

**Relationships:**
- → user_profiles (1:1) - Profile details
- → service_providers (1:1) - Provider registration
- → account_security_logs (1:N) - Security events
- → admin_activity_logs (1:N) - Admin actions

---

### 2. **user_profiles**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK, FK | References auth.users(id) |
| first_name | varchar | | User first name |
| last_name | varchar | | User last name |
| email | varchar | UNIQUE | User email |
| phone_number | varchar | | Contact number |
| user_type | varchar | | 'customer', 'mechanic', 'talyer_owner', 'admin' |
| profile_image_url | text | | Profile photo URL |
| current_latitude | numeric | | Current location (lat) |
| current_longitude | numeric | | Current location (lng) |
| shop_id | uuid | FK | References shops(id) |
| status | varchar | | 'active', 'suspended', 'banned' |

**Relationships:**
- ← auth.users (1:1) - Authentication
- → shops (1:1) - Owns shop (if talyer_owner)
- → service_providers (1:1) - Provider profile
- → vehicles (1:N) - Owns vehicles
- → service_requests (1:N) - Creates requests (as customer)
- → mechanic_job_history (1:N) - Job history (as mechanic)
- → customer_job_history (1:N) - Job history (as customer)
- → invoices (1:N) - Receives/sends invoices
- → notifications (1:N) - User notifications
- → reviews (1:N) - Gives/receives reviews

---

### 3. **shops**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Shop ID |
| owner_id | uuid | FK, UNIQUE | References user_profiles(id) |
| shop_name | varchar | | Shop business name |
| shop_address | text | | Physical address |
| shop_phone | text | | Contact number |
| shop_email | text | | Business email |
| latitude | numeric | | Shop location (lat) |
| longitude | numeric | | Shop location (lng) |
| service_radius | numeric | | Coverage area (km) |
| business_hours | jsonb | | Operating schedule |
| current_status | varchar | | 'open', 'closed', 'busy' |
| rating | numeric | | Average rating |
| is_active | boolean | | Active status |

**Relationships:**
- ← user_profiles (1:1) - Owned by talyer owner
- → service_providers (1:N) - Employs mechanics
- → shop_services (1:N) - Offers services
- → service_requests (1:N) - Receives requests
- → mechanic_job_history (1:N) - Job records
- → shop_mechanics (1:N) - Mechanic assignments

---

### 4. **service_providers**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Provider ID |
| user_id | uuid | FK, UNIQUE | References user_profiles(id) |
| shop_id | uuid | FK | References shops(id) |
| talyer_owner_id | uuid | FK | References user_profiles(id) |
| company_name | varchar | | Business name |
| rating | numeric | | Average rating |
| service_radius | numeric | | Service area (km) |
| is_verified | boolean | | Verification status |
| is_available | boolean | | Availability status |
| current_latitude | numeric | | Current location (lat) |
| current_longitude | numeric | | Current location (lng) |
| status | varchar | | 'offline', 'available', 'busy' |

**Relationships:**
- ← user_profiles (1:1) - Provider profile
- ← shops (N:1) - Belongs to shop
- → service_requests (1:N) - Handles requests
- → provider_services (1:N) - Offers services
- → request_broadcasts (1:N) - Receives broadcasts
- → business_permits (1:N) - Verification documents

---

### 5. **vehicles**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Vehicle ID |
| user_id | uuid | FK | References user_profiles(id) |
| brand_name | varchar | | Vehicle brand |
| model_name | varchar | | Vehicle model |
| year | integer | | Manufacturing year |
| plate_number | varchar | | License plate |
| vehicle_type | varchar | | 'car', 'motorcycle', 'truck' |
| is_primary | boolean | | Primary vehicle flag |

**Relationships:**
- ← user_profiles (N:1) - Owned by customer
- → service_requests (1:N) - Used in requests

---

## 🔧 Service Management Tables

### 6. **service_categories**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Category ID |
| name | varchar | UNIQUE | Category name |
| description | text | | Service description |
| base_price | numeric | | Base pricing |
| estimated_duration | integer | | Duration (minutes) |
| category_type | text | | 'standard', 'specialized', 'emergency' |
| is_active | boolean | | Active status |

**Relationships:**
- → shop_services (1:N) - Shop service offerings
- → provider_services (1:N) - Provider capabilities
- → service_requests (1:N) - Service type

---

### 7. **service_requests**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Request ID |
| customer_id | uuid | FK | References user_profiles(id) |
| provider_id | uuid | FK | References service_providers(id) |
| vehicle_id | uuid | FK | References vehicles(id) |
| category_id | uuid | FK | References service_categories(id) |
| shop_id | uuid | FK | References shops(id) |
| assigned_mechanic_id | uuid | FK | References user_profiles(id) |
| title | varchar | | Request title |
| description | text | | Problem description |
| status | varchar | | Request status |
| pickup_latitude | numeric | | Customer location (lat) |
| pickup_longitude | numeric | | Customer location (lng) |
| pickup_address | text | | Customer address |
| service_fee | numeric | | Calculated service fee |
| estimated_price | numeric | | Estimated cost |
| final_price | numeric | | Final cost |
| payment_status | varchar | | Payment state |
| request_type | text | | 'direct_mechanic', 'shop_based', 'broadcast' |
| is_broadcast_request | boolean | | Broadcast flag |
| broadcast_radius_km | numeric | | Broadcast area |

**Relationships:**
- ← user_profiles (N:1) - Created by customer
- ← service_providers (N:1) - Assigned to provider
- ← vehicles (N:1) - For specific vehicle
- ← service_categories (N:1) - Service type
- ← shops (N:1) - Assigned to shop
- → invoices (1:N) - Generated invoices
- → payments (1:N) - Payment records
- → messages (1:N) - Communication
- → progress_photos (1:N) - Work documentation
- → request_broadcasts (1:N) - Broadcast notifications
- → mechanic_job_history (1:1) - Job record
- → customer_job_history (1:1) - Customer record
- → job_completion_codes (1:1) - QR completion

---

### 8. **shop_services**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Service ID |
| shop_id | uuid | FK | References shops(id) |
| category_id | uuid | FK | References service_categories(id) |
| service_name | text | | Service name |
| description | text | | Service details |
| base_price | numeric | | Base pricing |
| custom_price | numeric | | Shop-specific price |
| estimated_duration | integer | | Duration (minutes) |
| is_active | boolean | | Active status |
| availability_status | text | | 'available', 'temporarily_unavailable' |

**Relationships:**
- ← shops (N:1) - Offered by shop
- ← service_categories (N:1) - Service type
- → service_availability_matrix (1:1) - Availability tracking

---

## 💰 Financial Tables

### 9. **invoices**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Invoice ID |
| request_id | uuid | FK | References service_requests(id) |
| customer_id | uuid | FK | References user_profiles(id) |
| mechanic_id | uuid | FK | References user_profiles(id) |
| talyer_owner_id | uuid | FK | References user_profiles(id) |
| provider_id | uuid | FK | References service_providers(id) |
| invoice_number | text | UNIQUE | Invoice number |
| subtotal | numeric | | Subtotal amount |
| platform_fee | numeric | | Platform commission |
| total_amount | numeric | | Total payable |
| talyer_net_amount | numeric | | Shop net earnings |
| provider_net_amount | numeric | | Mechanic net earnings |
| status | text | | 'generated', 'sent', 'paid' |
| selected_payment_method | text | | 'cash', 'gcash', 'paymaya' |
| payment_details | jsonb | | Payment metadata |
| generated_at | timestamptz | | Creation time |
| paid_at | timestamptz | | Payment time |

**Relationships:**
- ← service_requests (N:1) - For service request
- ← user_profiles (N:1) - Customer, mechanic, owner
- → payments (1:N) - Payment records
- → cash_payment_verifications (1:1) - Cash verification

---

### 10. **payments**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Payment ID |
| request_id | uuid | FK | References service_requests(id) |
| customer_id | uuid | FK | References user_profiles(id) |
| provider_id | uuid | FK | References service_providers(id) |
| invoice_id | uuid | FK | References invoices(id) |
| amount | numeric | | Payment amount |
| platform_fee | numeric | | Platform commission |
| provider_amount | numeric | | Provider earnings |
| payment_method | varchar | | Payment method |
| transaction_id | varchar | | Gateway transaction ID |
| status | varchar | | 'pending', 'completed', 'failed' |
| payment_gateway | varchar | | 'paymongo', 'gcash' |

**Relationships:**
- ← service_requests (N:1) - For request
- ← user_profiles (N:1) - From customer
- ← service_providers (N:1) - To provider
- ← invoices (N:1) - Invoice payment
- → payment_releases (1:1) - Release to provider
- → cash_payment_verifications (1:1) - Cash verification

---

### 11. **payment_releases**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Release ID |
| payment_id | uuid | FK | References payments(id) |
| request_id | uuid | FK | References service_requests(id) |
| provider_id | uuid | FK | References service_providers(id) |
| customer_id | uuid | FK | References user_profiles(id) |
| admin_id | uuid | FK | References auth.users(id) |
| total_amount | numeric | | Total amount |
| platform_fee | numeric | | Platform fee |
| provider_amount | numeric | | Provider earnings |
| release_status | varchar | | 'pending', 'approved', 'released' |
| release_method | varchar | | 'bank_transfer', 'gcash' |
| approved_at | timestamptz | | Approval time |
| released_at | timestamptz | | Release time |

**Relationships:**
- ← payments (1:1) - Payment to release
- ← service_requests (N:1) - Related request
- ← service_providers (N:1) - To provider
- ← user_profiles (N:1) - For customer
- ← auth.users (N:1) - Approved by admin

---

### 12. **cash_payment_verifications**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Verification ID |
| invoice_id | uuid | FK | References invoices(id) |
| payment_id | uuid | FK | References payments(id) |
| request_id | uuid | FK | References service_requests(id) |
| customer_id | uuid | FK | References user_profiles(id) |
| mechanic_id | uuid | FK | References user_profiles(id) |
| verified_by | uuid | FK | References auth.users(id) |
| cash_amount | numeric | | Cash amount |
| cash_photo_url | text | | Photo of cash |
| receipt_photo_url | text | | Photo of receipt |
| verification_status | text | | 'pending', 'verified', 'rejected' |
| verified_at | timestamptz | | Verification time |

**Relationships:**
- ← invoices (1:1) - Invoice payment
- ← payments (1:1) - Payment record
- ← service_requests (N:1) - For request
- ← user_profiles (N:1) - Customer and mechanic
- ← auth.users (N:1) - Verified by admin

---

## 📋 Job History Tables

### 13. **mechanic_job_history**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | History ID |
| mechanic_id | uuid | FK | References user_profiles(id) |
| service_request_id | uuid | FK | References service_requests(id) |
| customer_id | uuid | FK | References user_profiles(id) |
| shop_id | uuid | FK | References shops(id) |
| job_title | text | | Job title |
| job_description | text | | Job details |
| job_status | text | | 'completed', 'cancelled' |
| completed_at | timestamptz | | Completion time |
| total_amount | numeric | | Total earnings |
| mechanic_earnings | numeric | | Mechanic share |
| shop_earnings | numeric | | Shop share |
| platform_fee | numeric | | Platform fee |
| rating | numeric | | Customer rating |
| review_text | text | | Customer review |

**Relationships:**
- ← user_profiles (N:1) - Mechanic and customer
- ← service_requests (1:1) - Related request
- ← shops (N:1) - Shop assignment

---

### 14. **customer_job_history**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | History ID |
| customer_id | uuid | FK | References user_profiles(id) |
| service_request_id | uuid | FK | References service_requests(id) |
| mechanic_id | uuid | FK | References user_profiles(id) |
| shop_id | uuid | FK | References shops(id) |
| job_title | text | | Service title |
| job_description | text | | Service details |
| job_status | text | | 'completed', 'cancelled' |
| completed_at | timestamptz | | Completion time |
| total_amount | numeric | | Total paid |
| rating | numeric | | Given rating |
| review_text | text | | Given review |

**Relationships:**
- ← user_profiles (N:1) - Customer and mechanic
- ← service_requests (1:1) - Related request
- ← shops (N:1) - Shop used

---

## 🔔 Notification & Communication Tables

### 15. **notifications**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Notification ID |
| user_id | uuid | FK | References user_profiles(id) |
| title | text | | Notification title |
| body | text | | Notification message |
| type | text | | Notification type |
| data | jsonb | | Additional data |
| read | boolean | | Read status |
| created_at | timestamptz | | Creation time |

**Relationships:**
- ← user_profiles (N:1) - For user
- → notification_delivery_log (1:N) - Delivery tracking

---

### 16. **messages**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Message ID |
| request_id | uuid | FK | References service_requests(id) |
| sender_id | uuid | FK | References user_profiles(id) |
| receiver_id | uuid | FK | References user_profiles(id) |
| message | text | | Message content |
| sent_at | timestamptz | | Send time |
| is_read | boolean | | Read status |

**Relationships:**
- ← service_requests (N:1) - Related to request
- ← user_profiles (N:1) - Sender and receiver

---

### 17. **shop_notifications**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Notification ID |
| shop_id | uuid | FK | References shops(id) |
| shop_owner_id | uuid | FK | References user_profiles(id) |
| related_request_id | uuid | FK | References service_requests(id) |
| notification_type | text | | Type of notification |
| title | text | | Notification title |
| message | text | | Notification message |
| is_read | boolean | | Read status |

**Relationships:**
- ← shops (N:1) - For shop
- ← user_profiles (N:1) - For owner
- ← service_requests (N:1) - Related request

---

## 🚀 Broadcast & Request Routing Tables

### 18. **request_broadcasts**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Broadcast ID |
| request_id | uuid | FK | References service_requests(id) |
| provider_id | uuid | FK | References service_providers(id) |
| shop_id | uuid | FK | References shops(id) |
| mechanic_id | uuid | FK | References user_profiles(id) |
| provider_type | text | | 'shop', 'mechanic' |
| distance_km | numeric | | Distance to customer |
| notification_sent_at | timestamptz | | Notification time |
| viewed_at | timestamptz | | View time |
| response_status | text | | 'pending', 'accepted', 'declined' |
| responded_at | timestamptz | | Response time |

**Relationships:**
- ← service_requests (N:1) - Broadcasted request
- ← service_providers (N:1) - To provider
- ← shops (N:1) - To shop
- ← user_profiles (N:1) - To mechanic

---

### 19. **request_routing**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Routing ID |
| request_id | uuid | FK | References service_requests(id) |
| eligible_mechanic_id | uuid | FK | References user_profiles(id) |
| eligible_shop_id | uuid | FK | References shops(id) |
| routing_type | text | | 'direct_mechanic', 'shop_based' |
| is_notified | boolean | | Notification sent |
| distance_km | numeric | | Distance |

**Relationships:**
- ← service_requests (N:1) - Routed request
- ← user_profiles (N:1) - Eligible mechanic
- ← shops (N:1) - Eligible shop

---

## ⭐ Review & Rating Tables

### 20. **reviews**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Review ID |
| request_id | uuid | FK | References service_requests(id) |
| customer_id | uuid | FK | References user_profiles(id) |
| provider_id | uuid | FK | References service_providers(id) |
| rating | integer | | Rating (1-5) |
| comment | text | | Review text |
| response | text | | Provider response |
| is_verified | boolean | | Verification status |

**Relationships:**
- ← service_requests (N:1) - For request
- ← user_profiles (N:1) - By customer
- ← service_providers (N:1) - For provider

---

## 📸 Progress & Documentation Tables

### 21. **progress_photos**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Photo ID |
| service_request_id | uuid | FK | References service_requests(id) |
| mechanic_id | uuid | FK | References user_profiles(id) |
| service_phase | text | | 'arrival', 'inspection', 'work_in_progress' |
| image_url | text | | Photo URL |
| description | text | | Photo description |
| timestamp | timestamptz | | Upload time |

**Relationships:**
- ← service_requests (N:1) - For request
- ← user_profiles (N:1) - By mechanic

---

### 22. **service_phase_tracking**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Tracking ID |
| service_request_id | uuid | FK, UNIQUE | References service_requests(id) |
| mechanic_id | uuid | FK | References user_profiles(id) |
| current_phase | text | | Current service phase |
| phase_started_at | timestamptz | | Phase start time |
| phase_history | jsonb | | Historical phases |

**Relationships:**
- ← service_requests (1:1) - Tracks request
- ← user_profiles (N:1) - By mechanic

---

## 🔐 Security & Authentication Tables

### 23. **account_security_logs**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Log ID |
| user_id | uuid | FK | References auth.users(id) |
| action_type | text | | 'login', 'logout', 'password_change' |
| ip_address | inet | | IP address |
| user_agent | text | | Browser/device info |
| success | boolean | | Action success |
| created_at | timestamptz | | Log time |

**Relationships:**
- ← auth.users (N:1) - For user

---

### 24. **password_reset_tokens**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Token ID |
| user_id | uuid | FK | References auth.users(id) |
| token | text | UNIQUE | Reset token |
| expires_at | timestamptz | | Expiration time |
| used_at | timestamptz | | Usage time |
| is_active | boolean | | Active status |

**Relationships:**
- ← auth.users (N:1) - For user

---

### 25. **email_verification_tokens**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Token ID |
| user_id | uuid | FK | References auth.users(id) |
| old_email | text | | Previous email |
| new_email | text | | New email |
| token | text | UNIQUE | Verification token |
| token_type | text | | 'registration', 'email_change' |
| expires_at | timestamptz | | Expiration time |

**Relationships:**
- ← auth.users (N:1) - For user

---

## 👤 Mechanic Management Tables

### 26. **mechanic_invitations**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Invitation ID |
| shop_owner_id | uuid | FK | References user_profiles(id) |
| shop_id | uuid | FK | References shops(id) |
| mechanic_user_id | uuid | FK | References auth.users(id) |
| email | text | | Invitee email |
| first_name | text | | Invitee first name |
| last_name | text | | Invitee last name |
| temporary_password | text | | Temp password |
| invitation_token | text | UNIQUE | Invite token |
| status | text | | 'pending', 'sent', 'accepted' |
| expires_at | timestamptz | | Expiration time |

**Relationships:**
- ← user_profiles (N:1) - From shop owner
- ← shops (N:1) - For shop
- ← auth.users (N:1) - Created user

---

### 27. **shop_mechanics**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Assignment ID |
| shop_id | uuid | FK | References shops(id) |
| mechanic_id | uuid | FK | References user_profiles(id) |
| role | varchar | | 'mechanic', 'senior_mechanic' |
| hourly_rate | numeric | | Pay rate |
| is_active | boolean | | Active status |
| is_available | boolean | | Availability |

**Relationships:**
- ← shops (N:1) - Works at shop
- ← user_profiles (N:1) - Mechanic profile

---

### 28. **mechanic_availability_status**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Status ID |
| mechanic_id | uuid | FK, UNIQUE | References user_profiles(id) |
| shop_id | uuid | FK | References shops(id) |
| current_request_id | uuid | FK | References service_requests(id) |
| current_status | text | | 'available', 'busy', 'offline' |
| location_latitude | numeric | | Current location (lat) |
| location_longitude | numeric | | Current location (lng) |
| is_accepting_requests | boolean | | Accepting flag |

**Relationships:**
- ← user_profiles (1:1) - Mechanic status
- ← shops (N:1) - Shop assignment
- ← service_requests (N:1) - Current job

---

## 🔍 Verification & Document Tables

### 29. **document_verifications**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Verification ID |
| user_id | uuid | FK | References auth.users(id) |
| verified_by | uuid | FK | References auth.users(id) |
| document_type | text | | 'business_permit', 'drivers_license' |
| document_url | text | | Document URL |
| verification_status | text | | 'pending', 'verified', 'rejected' |
| verified_at | timestamptz | | Verification time |

**Relationships:**
- ← auth.users (N:1) - For user
- ← auth.users (N:1) - By admin

---

### 30. **business_permits**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Permit ID |
| provider_id | uuid | FK | References service_providers(id) |
| verified_by | uuid | FK | References auth.users(id) |
| business_permit_name | text | | Business name |
| registered_address | text | | Business address |
| receipt_no | text | UNIQUE | Receipt number |
| permit_document_url | text | | Document URL |
| is_verified | boolean | | Verification status |

**Relationships:**
- ← service_providers (N:1) - For provider
- ← auth.users (N:1) - Verified by admin

---

### 31. **talyer_owner_verifications**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Verification ID |
| user_id | uuid | FK, UNIQUE | References user_profiles(id) |
| reviewed_by | uuid | FK | References auth.users(id) |
| business_name | varchar | | Business name |
| business_permit_url | text | | Permit URL |
| valid_id_url | text | | ID URL |
| status | varchar | | 'pending', 'approved', 'rejected' |
| reviewed_at | timestamptz | | Review time |

**Relationships:**
- ← user_profiles (1:1) - For talyer owner
- ← auth.users (N:1) - Reviewed by admin

---

## 🎫 Job Completion & QR Code Tables

### 32. **job_completion_codes**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Code ID |
| request_id | uuid | FK | References service_requests(id) |
| customer_id | uuid | FK | References user_profiles(id) |
| used_by_provider_id | uuid | FK | References service_providers(id) |
| completion_code | text | UNIQUE | Completion code |
| is_used | boolean | | Usage status |
| expires_at | timestamptz | | Expiration time |
| used_at | timestamptz | | Usage time |
| verification_status | varchar | | 'pending', 'verified', 'expired' |

**Relationships:**
- ← service_requests (N:1) - For request
- ← user_profiles (N:1) - For customer
- ← service_providers (N:1) - Used by provider

---

### 33. **service_completions**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Completion ID |
| request_id | uuid | FK | References service_requests(id) |
| mechanic_id | uuid | FK | References user_profiles(id) |
| customer_id | uuid | FK | References user_profiles(id) |
| completion_code | text | UNIQUE | Completion code |
| qr_code_data | text | | QR code data |
| is_scanned | boolean | | Scan status |
| scanned_at | timestamptz | | Scan time |
| verification_status | text | | 'pending', 'verified' |

**Relationships:**
- ← service_requests (N:1) - For request
- ← user_profiles (N:1) - Mechanic and customer

---

## 📊 Admin & Audit Tables

### 34. **admin_activity_logs**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Log ID |
| admin_id | uuid | FK | References auth.users(id) |
| action_type | varchar | | Action type |
| target_type | varchar | | Target entity type |
| target_id | uuid | | Target entity ID |
| action_details | jsonb | | Action details |
| created_at | timestamptz | | Log time |

**Relationships:**
- ← auth.users (N:1) - By admin

---

### 35. **audit_logs**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Log ID |
| user_id | uuid | FK | References user_profiles(id) |
| role | varchar | | User role |
| action | text | | Action performed |
| table_name | varchar | | Affected table |
| record_id | uuid | | Affected record |
| old_values | jsonb | | Before values |
| new_values | jsonb | | After values |

**Relationships:**
- ← user_profiles (N:1) - By user

---

## 📧 Email & Notification Templates

### 36. **email_notifications**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Email ID |
| recipient_user_id | uuid | FK | References auth.users(id) |
| sender_user_id | uuid | FK | References auth.users(id) |
| email_type | text | | Email type |
| recipient_email | text | | Recipient email |
| subject | text | | Email subject |
| body | text | | Email body |
| delivery_status | text | | 'pending', 'sent', 'delivered' |

**Relationships:**
- ← auth.users (N:1) - Recipient and sender

---

### 37. **notification_templates**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Template ID |
| category | text | | Template category |
| priority | text | | 'low', 'normal', 'high', 'urgent' |
| title_template | text | | Title template |
| message_template | text | | Message template |
| is_active | boolean | | Active status |

**Relationships:**
- None (Template master data)

---

## 🛠️ Utility & Configuration Tables

### 38. **app_settings**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Setting ID |
| key | varchar | UNIQUE | Setting key |
| value | text | | Setting value |
| description | text | | Description |
| is_public | boolean | | Public access |
| category | text | | Setting category |

**Relationships:**
- None (Configuration data)

---

### 39. **distance_pricing_config**
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | uuid | PK | Config ID |
| base_rate_per_km | numeric | | Base rate (per km) |
| minimum_service_fee | numeric | | Minimum fee |
| maximum_service_fee | numeric | | Maximum fee |
| emergency_multiplier | numeric | | Emergency rate |
| is_active | boolean | | Active status |

**Relationships:**
- None (Pricing configuration)

---

## 🔗 Complete Entity Relationship Map

```
auth.users
    ↓ (1:1)
user_profiles ←→ shops (1:1 owner)
    ↓ (1:1)          ↓ (1:N)
service_providers    shop_services
    ↓ (1:N)          ↓ (N:1)
service_requests ← service_categories
    ↓ (1:1)
invoices → payments → payment_releases
    ↓ (1:1)
mechanic_job_history
customer_job_history
```

## 📈 Key Relationships Summary

| From Table | To Table | Type | Description |
|------------|----------|------|-------------|
| auth.users | user_profiles | 1:1 | Authentication to profile |
| user_profiles | shops | 1:1 | Talyer owner owns shop |
| user_profiles | service_providers | 1:1 | User is provider |
| user_profiles | vehicles | 1:N | User owns vehicles |
| shops | service_providers | 1:N | Shop has mechanics |
| shops | shop_services | 1:N | Shop offers services |
| service_requests | invoices | 1:N | Request generates invoices |
| invoices | payments | 1:N | Invoice has payments |
| payments | payment_releases | 1:1 | Payment released to provider |
| service_requests | progress_photos | 1:N | Request has progress photos |
| service_requests | messages | 1:N | Request has conversations |
| service_requests | request_broadcasts | 1:N | Request broadcast to providers |
| user_profiles | notifications | 1:N | User receives notifications |
| service_requests | reviews | 1:N | Request receives reviews |

---

## 🎯 Total Database Statistics

- **Total Tables:** 66
- **Core Entity Tables:** 5
- **Service Management:** 8
- **Financial Tables:** 4
- **Job History:** 2
- **Notification:** 3
- **Broadcast/Routing:** 2
- **Reviews:** 1
- **Documentation:** 2
- **Security:** 3
- **Mechanic Management:** 3
- **Verification:** 3
- **Job Completion:** 2
- **Admin/Audit:** 2
- **Email/Templates:** 2
- **Utility/Config:** 2
- **Supporting Tables:** 24

---

**Legend:**
- **PK** = Primary Key
- **FK** = Foreign Key
- **UNIQUE** = Unique Constraint
- **1:1** = One-to-One Relationship
- **1:N** = One-to-Many Relationship
- **N:1** = Many-to-One Relationship
- **N:M** = Many-to-Many Relationship

---

**Database Design Principles:**
1. ✅ Normalized to 3NF
2. ✅ Foreign key constraints enforced
3. ✅ Check constraints for data integrity
4. ✅ JSONB columns for flexible data
5. ✅ Timestamp tracking (created_at, updated_at)
6. ✅ Soft deletes via status flags
7. ✅ UUID primary keys
8. ✅ RLS (Row Level Security) enabled
