# RoadAid DFD - Figma Design Guide

**Date:** October 10, 2025  
**Purpose:** Visual Data Flow Diagram for Figma  
**Levels:** 0, 1, and 2

---

## 🎨 Figma Design Instructions

### **Canvas Setup:**
- **Canvas Size for Each Level:**
  - Level 0: 1920 x 1080px
  - Level 1: 2400 x 1600px
  - Level 2: 3200 x 2400px (per process)
- **Background:** #FFFFFF (white)
- **Grid:** 20px grid for alignment

### **Color Scheme:**
```
External Entities:   #3498DB (Blue)
Processes:          #2ECC71 (Green)
Data Stores:        #E74C3C (Red)
Data Flows:         #34495E (Dark Gray)
Highlights:         #F39C12 (Orange)
System Boundary:    #95A5A6 (Gray)
```

### **Component Templates:**

#### **External Entity (Rectangle with rounded corners):**
```
┌─────────────────┐
│   👤 Customer   │
└─────────────────┘

Dimensions: 160px x 80px
Border: 3px solid #3498DB
Corner Radius: 12px
Fill: #EBF5FB (light blue)
Font: 18px Bold
Icon: 32px
```

#### **Process (Rounded Rectangle with number):**
```
┌────────────────────────┐
│  1.0                   │
│  Service Request       │
│  Management            │
└────────────────────────┘

Dimensions: 240px x 100px
Border: 3px solid #2ECC71
Corner Radius: 16px
Fill: #E8F8F5 (light green)
Process Number: 16px Bold
Process Name: 14px Regular
```

#### **Data Store (Open Rectangle):**
```
│  D1: auth.users  │

Dimensions: 200px x 50px
Left Border: 5px solid #E74C3C
Right Border: None
Top/Bottom Border: 2px solid #E74C3C
Fill: #FADBD8 (light red)
Font: 14px Regular
```

#### **Data Flow (Arrow with label):**
```
──────────────────>  Request Data
                     (12px, italic)

Line Weight: 2px
Arrow Size: 12px triangle
Color: #34495E
Label: Above line, 12px italic
```

---

## 📊 DFD Level 0 - Context Diagram

### **Canvas: 1920 x 1080px**

### **Center: System (Large Circle)**
Position: X: 960, Y: 540 (center)

```
                    ┌───────────────────────────────┐
       Customer ───>│                               │<─── Mechanic
                    │       RoadAid System          │
                    │   (Roadside Assistance)       │
   Talyer Owner ───>│                               │<─── Admin
                    └───────────────────────────────┘
                                  │
                                  ▼
                         Payment Gateway
                           (PayMongo)
```

**System Circle:**
- **Diameter:** 400px
- **Border:** 4px solid #2ECC71
- **Fill:** Gradient (#E8F8F5 to #FFFFFF)
- **Title:** "RoadAid System", 24px Bold
- **Subtitle:** "Roadside Assistance Platform", 16px Regular

**External Entities (Position around circle):**

1. **Customer** (Top Left)
   - Position: X: 400, Y: 300
   - Icon: 👤
   - Arrows OUT: Service Request, Payment
   - Arrows IN: Service Status, Invoice

2. **Mechanic** (Top Right)
   - Position: X: 1520, Y: 300
   - Icon: 🔧
   - Arrows OUT: Accept Job, Service Update, Completion
   - Arrows IN: Job Notification, Customer Info

3. **Talyer Owner** (Bottom Left)
   - Position: X: 400, Y: 780
   - Icon: 🏪
   - Arrows OUT: Mechanic Assignment, Shop Config
   - Arrows IN: Job Requests, Earnings Report

4. **Admin** (Bottom Right)
   - Position: X: 1520, Y: 780
   - Icon: 👨‍💼
   - Arrows OUT: Approval, Verification
   - Arrows IN: Payment Release Request, Reports

5. **Payment Gateway** (Bottom Center)
   - Position: X: 960, Y: 900
   - Icon: 💳
   - Arrows OUT: Payment Confirmation
   - Arrows IN: Payment Request

---

## 📊 DFD Level 1 - Main Processes

### **Canvas: 2400 x 1600px**

### **External Entities (Top Row):**
Position Y: 100

```
┌──────────┐                                              ┌──────────┐
│ Customer │                                              │ Mechanic │
└────┬─────┘                                              └────┬─────┘
     │                                                          │
```

### **Main Processes (Center Flow):**

**Process 1.0** (X: 300, Y: 400)
```
┌────────────────────────────┐
│  1.0                       │
│  Service Request           │
│  Management                │
└────────────────────────────┘
```

**Process 2.0** (X: 700, Y: 400)
```
┌────────────────────────────┐
│  2.0                       │
│  Request Routing &         │
│  Broadcasting              │
└────────────────────────────┘
```

**Process 3.0** (X: 1100, Y: 400)
```
┌────────────────────────────┐
│  3.0                       │
│  Service Execution &       │
│  Tracking                  │
└────────────────────────────┘
```

**Process 4.0** (X: 1500, Y: 400)
```
┌────────────────────────────┐
│  4.0                       │
│  Billing & Payment         │
│  Processing                │
└────────────────────────────┘
```

**Process 5.0** (X: 1100, Y: 900)
```
┌────────────────────────────┐
│  5.0                       │
│  Payment Release           │
│  Management                │
└────────────────────────────┘
```

**Process 6.0** (X: 700, Y: 900)
```
┌────────────────────────────┐
│  6.0                       │
│  History & Reviews         │
│  Management                │
└────────────────────────────┘
```

### **Data Stores (Right Side):**
Position X: 2000, Y: 200-1200

```
│  D1: auth.users             │
│  D2: user_profiles          │
│  D3: service_requests       │
│  D4: vehicles               │
│  D5: service_categories     │
│  D6: distance_pricing_config│
│  D7: service_providers      │
│  D8: shops                  │
│  D9: mechanic_availability  │
│  D10: request_broadcasts    │
│  D11: notifications         │
│  D12: messages              │
│  D13: progress_photos       │
│  D14: invoices              │
│  D15: payments              │
│  D16: payment_releases      │
│  D17: job_history           │
│  D18: reviews               │
```

### **Data Flow Connections:**

1. **Customer → Process 1.0:**
   - Label: "Service Request"
   - Data: Vehicle info, location, problem description

2. **Process 1.0 → Process 2.0:**
   - Label: "Request Details"
   - Data: Customer info, service type, location

3. **Process 2.0 → Process 3.0:**
   - Label: "Assigned Request"
   - Data: Mechanic assignment, customer location

4. **Process 3.0 → Process 4.0:**
   - Label: "Service Completion"
   - Data: Work performed, time spent, materials used

5. **Process 4.0 → Process 5.0:**
   - Label: "Payment Confirmation"
   - Data: Invoice paid, payment method, amounts

6. **Process 5.0 → Process 6.0:**
   - Label: "Release Completed"
   - Data: Payment released, earnings breakdown

---

## 📊 DFD Level 2 - Process 1.0: Service Request Management

### **Canvas: 3200 x 2400px**

### **Sub-Processes:**

**1.1 Authenticate User** (X: 400, Y: 300)
```
┌────────────────────────────┐
│  1.1                       │
│  Authenticate User         │
└────────────────────────────┘
```
- **Inputs:** Login credentials (from Customer)
- **Outputs:** User details (to Process 1.2)
- **Data Stores:** D1: auth.users, D2: user_profiles

**1.2 Create Service Request** (X: 900, Y: 300)
```
┌────────────────────────────┐
│  1.2                       │
│  Create Service Request    │
│  • Vehicle selection       │
│  • Service category        │
│  • Location details        │
│  • Problem description     │
└────────────────────────────┘
```
- **Inputs:** User details, vehicle, location, problem
- **Outputs:** Request data (to Process 1.3)
- **Data Stores:** D3: service_requests, D4: vehicles, D5: service_categories

**1.3 Calculate Service Fee** (X: 1400, Y: 300)
```
┌────────────────────────────┐
│  1.3                       │
│  Calculate Service Fee     │
│  • Distance calculation    │
│  • Service type pricing    │
│  • Emergency multiplier    │
└────────────────────────────┘
```
- **Inputs:** Request data, location, service type
- **Outputs:** Fee details (to Process 1.4)
- **Data Stores:** D6: distance_pricing_config

**1.4 Determine Request Type** (X: 1900, Y: 300)
```
┌────────────────────────────┐
│  1.4                       │
│  Determine Request Type    │
│  • Direct Mechanic         │
│  • Shop-based              │
│  • Broadcast               │
└────────────────────────────┘
```
- **Inputs:** Fee details, location, availability
- **Outputs:** Request with type (to Process 2.0)
- **Data Stores:** D3: service_requests

### **Data Flow Diagram:**

```
Customer
   │
   │ Login Credentials
   ▼
┌────────┐  User Details  ┌────────┐  Request Data  ┌────────┐  Fee Details  ┌────────┐
│  1.1   │───────────────>│  1.2   │───────────────>│  1.3   │──────────────>│  1.4   │
└───┬────┘                └───┬────┘                └───┬────┘               └───┬────┘
    │                         │                         │                        │
    ↓                         ↓                         ↓                        ↓
│D1: auth.users│        │D3: service_requests│   │D6: distance_pricing│  │D3: service_requests│
│D2: user_profiles│     │D4: vehicles        │                          
                        │D5: service_categories│                        
```

---

## 📊 DFD Level 2 - Process 2.0: Request Routing & Broadcasting

### **Sub-Processes:**

**2.1 Analyze Request Type** (X: 400, Y: 300)
```
┌────────────────────────────┐
│  2.1                       │
│  Analyze Request Type      │
│  • Check request_type      │
│  • Get location details    │
└────────────────────────────┘
```

**2.2 Find Eligible Providers** (X: 900, Y: 300)
```
┌────────────────────────────┐
│  2.2                       │
│  Find Eligible Providers   │
│  • Calculate distances     │
│  • Check availability      │
│  • Filter by radius        │
└────────────────────────────┘
```

**2.3 Create Broadcast Records** (X: 1400, Y: 300)
```
┌────────────────────────────┐
│  2.3                       │
│  Create Broadcast Records  │
│  • Generate notifications  │
│  • Record distance         │
│  • Set expiration time     │
└────────────────────────────┘
```

**2.4 Send Notifications** (X: 1900, Y: 300)
```
┌────────────────────────────┐
│  2.4                       │
│  Send Notifications        │
│  • Push notifications      │
│  • In-app notifications    │
└────────────────────────────┘
```

**2.5 Receive Provider Response** (X: 1400, Y: 800)
```
┌────────────────────────────┐
│  2.5                       │
│  Receive Provider Response │
│  • Accept/Decline          │
└────────────────────────────┘
```

**2.6 Assign Provider** (X: 900, Y: 800)
```
┌────────────────────────────┐
│  2.6                       │
│  Assign Provider           │
│  • Update request status   │
│  • Set assigned_mechanic   │
│  • Update availability     │
└────────────────────────────┘
```

---

## 📊 DFD Level 2 - Process 3.0: Service Execution & Tracking

### **Sub-Processes:**

**3.1 Mechanic En Route** (X: 400, Y: 300)
```
┌────────────────────────────┐
│  3.1                       │
│  Mechanic En Route         │
│  • Update to 'en_route'    │
│  • Track location          │
└────────────────────────────┘
```

**3.2 Arrival Confirmation** (X: 900, Y: 300)
```
┌────────────────────────────┐
│  3.2                       │
│  Arrival Confirmation      │
│  • Update to 'arrived'     │
│  • Capture arrival photo   │
└────────────────────────────┘
```

**3.3 Vehicle Inspection** (X: 1400, Y: 300)
```
┌────────────────────────────┐
│  3.3                       │
│  Vehicle Inspection        │
│  • Document issues         │
│  • Capture photos          │
│  • Update service phase    │
└────────────────────────────┘
```

**3.4 Service Execution** (X: 1900, Y: 300)
```
┌────────────────────────────┐
│  3.4                       │
│  Service Execution         │
│  • Update to 'in_progress' │
│  • Capture work photos     │
│  • Update progress         │
└────────────────────────────┘
```

**3.5 Communication Handler** (X: 2400, Y: 300)
```
┌────────────────────────────┐
│  3.5                       │
│  Communication Handler     │
│  • Customer-Mechanic chat  │
│  • Send updates            │
└────────────────────────────┘
```

**3.6 Service Completion** (X: 1900, Y: 800)
```
┌────────────────────────────┐
│  3.6                       │
│  Service Completion        │
│  • Generate code           │
│  • Generate QR code        │
│  • Update to 'completed'   │
└────────────────────────────┘
```

**3.7 Customer Verification** (X: 1400, Y: 800)
```
┌────────────────────────────┐
│  3.7                       │
│  Customer Verification     │
│  • Scan QR code            │
│  • Verify completion code  │
└────────────────────────────┘
```

---

## 📊 DFD Level 2 - Process 4.0: Billing & Payment Processing

### **Sub-Processes:**

**4.1 Generate Invoice** (X: 400, Y: 300)
```
┌────────────────────────────┐
│  4.1                       │
│  Generate Invoice          │
│  • Calculate total amount  │
│  • Calculate platform fee  │
│  • Calculate net amounts   │
└────────────────────────────┘
```

**4.2 Send Invoice to Customer** (X: 900, Y: 300)
```
┌────────────────────────────┐
│  4.2                       │
│  Send Invoice to Customer  │
│  • Email notification      │
│  • In-app notification     │
└────────────────────────────┘
```

**4.3 Customer Payment Selection** (X: 1400, Y: 300)
```
┌────────────────────────────┐
│  4.3                       │
│  Payment Selection         │
│  • Cash payment            │
│  • GCash                   │
│  • PayMaya                 │
└────────────────────────────┘
```

**4.4 Process Payment** (X: 1900, Y: 300)
```
┌────────────────────────────┐
│  4.4                       │
│  Process Payment           │
│  • Cash: Capture photo     │
│  • Online: PayMongo        │
└────────────────────────────┘
```

**4.5 Update Invoice Status** (X: 1900, Y: 800)
```
┌────────────────────────────┐
│  4.5                       │
│  Update Invoice Status     │
│  • Mark as 'paid'          │
│  • Record payment method   │
│  • Update request status   │
└────────────────────────────┘
```

**4.6 Verify Cash Payment** (X: 1400, Y: 800)
```
┌────────────────────────────┐
│  4.6                       │
│  Verify Cash Payment       │
│  (If cash payment)         │
│  • Review photo evidence   │
│  • Approve/Reject          │
└────────────────────────────┘
```

---

## 📊 DFD Level 2 - Process 5.0: Payment Release Management

### **Sub-Processes:**

**5.1 Create Release Request** (X: 400, Y: 300)
```
┌────────────────────────────┐
│  5.1                       │
│  Create Release Request    │
│  • Calculate provider amt  │
│  • Calculate shop amount   │
│  • Calculate platform fee  │
└────────────────────────────┘
```

**5.2 Admin Review & Approval** (X: 900, Y: 300)
```
┌────────────────────────────┐
│  5.2                       │
│  Admin Review & Approval   │
│  • Verify completion       │
│  • Check documentation     │
│  • Approve/Reject release  │
└────────────────────────────┘
```

**5.3 Process Payment Release** (X: 1400, Y: 300)
```
┌────────────────────────────┐
│  5.3                       │
│  Process Payment Release   │
│  • Bank transfer           │
│  • GCash/PayMaya           │
│  • Update release status   │
└────────────────────────────┘
```

**5.4 Notify Provider** (X: 1900, Y: 300)
```
┌────────────────────────────┐
│  5.4                       │
│  Notify Provider           │
│  • Payment released        │
│  • Amount details          │
└────────────────────────────┘
```

**5.5 Update Earnings Records** (X: 1900, Y: 800)
```
┌────────────────────────────┐
│  5.5                       │
│  Update Earnings Records   │
│  • Shop earnings           │
│  • Mechanic earnings       │
│  • Platform earnings       │
└────────────────────────────┘
```

---

## 📊 DFD Level 2 - Process 6.0: History & Reviews Management

### **Sub-Processes:**

**6.1 Create Job History** (X: 400, Y: 300)
```
┌────────────────────────────┐
│  6.1                       │
│  Create Job History        │
│  • Mechanic job record     │
│  • Customer job record     │
└────────────────────────────┘
```

**6.2 Request Customer Review** (X: 900, Y: 300)
```
┌────────────────────────────┐
│  6.2                       │
│  Request Customer Review   │
│  • Send notification       │
│  • In-app prompt           │
└────────────────────────────┘
```

**6.3 Submit Rating & Review** (X: 1400, Y: 300)
```
┌────────────────────────────┐
│  6.3                       │
│  Submit Rating & Review    │
│  • Rate mechanic (1-5)     │
│  • Write review text       │
└────────────────────────────┘
```

**6.4 Update Provider Rating** (X: 1900, Y: 300)
```
┌────────────────────────────┐
│  6.4                       │
│  Update Provider Rating    │
│  • Calculate avg rating    │
│  • Update mechanic profile │
│  • Update shop profile     │
└────────────────────────────┘
```

**6.5 Update History with Review** (X: 1900, Y: 800)
```
┌────────────────────────────┐
│  6.5                       │
│  Update History w/ Review  │
│  • Add rating to history   │
│  • Add review text         │
└────────────────────────────┘
```

**6.6 Generate Analytics** (X: 1400, Y: 800)
```
┌────────────────────────────┐
│  6.6                       │
│  Generate Analytics        │
│  • Provider performance    │
│  • Service quality metrics │
│  • Customer satisfaction   │
└────────────────────────────┘
```

---

## 🎯 Legend Template for All DFD Levels

```
┌──────────────────────────────────────────────────┐
│                  DFD LEGEND                      │
├──────────────────────────────────────────────────┤
│                                                  │
│ SYMBOLS:                                         │
│                                                  │
│ ┌─────────┐                                     │
│ │ Entity  │  = External Entity                  │
│ └─────────┘                                     │
│                                                  │
│ ┌─────────┐                                     │
│ │  1.0    │  = Process                          │
│ │ Process │                                     │
│ └─────────┘                                     │
│                                                  │
│ │ D1: data│  = Data Store                       │
│                                                  │
│ ─────────>   = Data Flow                        │
│                                                  │
│ COLORS:                                          │
│ 🔵 Blue   - External Entities                   │
│ 🟢 Green  - Processes                           │
│ 🔴 Red    - Data Stores                         │
│ ⚫ Gray   - Data Flows                          │
│                                                  │
│ LEVELS:                                          │
│ Level 0 - Context Diagram (System Overview)     │
│ Level 1 - Main Processes (6 Major Processes)    │
│ Level 2 - Detailed Processes (Sub-processes)    │
│                                                  │
└──────────────────────────────────────────────────┘
```

---

## 📋 Implementation Checklist

### **DFD Level 0:**
- [ ] Create system circle in center
- [ ] Add 5 external entities around circle
- [ ] Draw data flow arrows with labels
- [ ] Add system title and description
- [ ] Add legend

### **DFD Level 1:**
- [ ] Create 6 main processes
- [ ] Position external entities
- [ ] Add 18 data stores on side
- [ ] Connect all data flows between processes
- [ ] Connect processes to data stores
- [ ] Add data flow labels

### **DFD Level 2 - All 6 Processes:**
- [ ] Process 1.0: 4 sub-processes (Service Request)
- [ ] Process 2.0: 6 sub-processes (Routing & Broadcasting)
- [ ] Process 3.0: 7 sub-processes (Service Execution)
- [ ] Process 4.0: 6 sub-processes (Billing & Payment)
- [ ] Process 5.0: 5 sub-processes (Payment Release)
- [ ] Process 6.0: 6 sub-processes (History & Reviews)

### **Finalization:**
- [ ] Verify all data flows have labels
- [ ] Check all processes numbered correctly
- [ ] Ensure data store consistency across levels
- [ ] Add page numbers and titles
- [ ] Export all levels (PNG, PDF, SVG)

---

## 📤 Export Specifications

### **For Thesis/Documentation:**
- **Format:** PDF
- **Size:** A3 (297 x 420 mm) per level
- **Resolution:** 300 DPI
- **Layout:** Landscape orientation

### **For Presentation:**
- **Format:** PNG
- **Size:** 1920 x 1080 px (16:9)
- **Resolution:** 72 DPI
- **Background:** White

### **For Web:**
- **Format:** SVG
- **Optimization:** Compressed
- **Interactive:** Clickable processes

---

**Created:** October 10, 2025  
**Version:** 1.0  
**Status:** Ready for Figma Implementation  
**Total Processes:** 6 Main + 34 Sub-processes  
**Total Data Stores:** 28  
**Total External Entities:** 5
