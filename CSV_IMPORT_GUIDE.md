# RoadAid Database - Ready-to-Import Files

**Date:** October 10, 2025  
**Purpose:** Downloadable database structure files

---

## 📁 Files Included

### 1. **ROADAID_ERD_TABLES.csv**
Complete table structure with all columns, data types, keys, and colors.

**Columns:**
- Table Name
- Column Name
- Data Type
- Key Type (PK, FK, UNIQUE)
- Description
- Color Group (for Figma)

**Total Rows:** 440+ fields across 66 tables

**Usage:**
- Import to Excel/Google Sheets for documentation
- Import to Figma as table data
- Use in database design tools (dbdiagram.io, draw.io, etc.)

---

### 2. **ROADAID_ERD_RELATIONSHIPS.csv**
All table relationships with cardinality.

**Columns:**
- From Table
- To Table
- Relationship Type (One-to-One, One-to-Many)
- From Cardinality
- To Cardinality
- Foreign Key Column
- Description

**Total Rows:** 56+ relationships

**Usage:**
- Generate relationship lines in Figma
- Import to ER diagram tools
- Reference for foreign key constraints

---

## 🎨 How to Import to Figma

### **Method 1: Using Figma Plugin - "CSV to Table"**

1. **Install Plugin:**
   - Open Figma
   - Go to Plugins → Browse Plugins
   - Search "CSV to Table" or "Google Sheets Sync"
   - Install the plugin

2. **Import Tables:**
   - Select ROADAID_ERD_TABLES.csv
   - Configure columns to show
   - Apply color codes from "Color Group" column
   - Generate table cards automatically

3. **Import Relationships:**
   - Use ROADAID_ERD_RELATIONSHIPS.csv
   - Draw connection lines between tables
   - Apply cardinality symbols (1:1, 1:N)

---

### **Method 2: Using Excel/Google Sheets + Copy to Figma**

1. **Open CSV in Excel:**
   - Open ROADAID_ERD_TABLES.csv
   - Filter by Table Name
   - Copy table data

2. **Create Table Card in Figma:**
   - Create rectangle with rounded corners
   - Apply color from Color Group column
   - Paste fields into text layer
   - Format PK/FK with symbols

3. **Repeat for all 66 tables**

---

### **Method 3: Using Online Tools**

#### **A. dbdiagram.io (Recommended)**
```
1. Go to https://dbdiagram.io
2. Click "Import" → "CSV"
3. Upload ROADAID_ERD_TABLES.csv
4. Auto-generates ERD diagram
5. Export as PNG/PDF
6. Import image to Figma
```

#### **B. draw.io**
```
1. Go to https://app.diagrams.net
2. File → Import → CSV
3. Upload both CSV files
4. Customize layout and colors
5. Export as SVG
6. Import to Figma (vector format)
```

#### **C. Lucidchart**
```
1. Go to https://lucidchart.com
2. Import → CSV
3. Auto-generate ERD
4. Customize with colors
5. Export as PNG/PDF
```

---

## 📊 Excel Import Instructions

### **Step 1: Open CSV Files**
```
- Double-click ROADAID_ERD_TABLES.csv
- Opens in Excel/Google Sheets
- All data formatted in columns
```

### **Step 2: Filter by Table**
```
- Click on "Table Name" column header
- Apply filter
- Select specific table (e.g., "user_profiles")
- View all fields for that table
```

### **Step 3: Group by Color**
```
- Sort by "Color Group" column
- Tables with same color are grouped
- Easy to see entity categories
```

### **Step 4: Generate Documentation**
```
- Use Excel formulas to create table summaries
- Generate field count per table
- Create relationship matrix
- Export as formatted PDF
```

---

## 🔗 Relationship Visualization

### **From ROADAID_ERD_RELATIONSHIPS.csv:**

Example format:
```
auth.users ──(1:1)──> user_profiles
user_profiles ──(1:N)──> vehicles
service_requests ──(1:N)──> invoices
invoices ──(1:N)──> payments
payments ──(1:1)──> payment_releases
```

### **How to Draw in Figma:**
1. Place table cards based on relationships
2. Draw lines between related tables
3. Add cardinality labels (1:1, 1:N)
4. Use crow's foot notation:
   - `●` = One (1)
   - `<` = Many (N)
   - `●──────●` = One-to-One
   - `●──────<` = One-to-Many

---

## 📋 Quick Reference

### **Color Codes:**
```
#4A90E2 - Core Entities (auth.users, user_profiles, shops, etc.)
#7B68EE - Service Management (service_requests, categories, etc.)
#50C878 - Financial (invoices, payments, releases)
#F4A460 - Job History (mechanic_job_history, customer_job_history)
#FF6B6B - Notifications (notifications, messages, shop_notifications)
#2C3E50 - Security (account_security_logs, tokens, verifications)
#F39C12 - Supporting (reviews, invitations, completions)
#95A5A6 - Admin/Config (audit_logs, app_settings)
```

### **Key Types:**
```
PK     = Primary Key (🔑)
FK     = Foreign Key (🔗)
UNIQUE = Unique Constraint (⭐)
PK|FK  = Both Primary and Foreign Key
FK|UNIQUE = Foreign Key with Unique Constraint
```

---

## 🎯 Pre-made Templates

### **For Microsoft Word/PowerPoint:**
1. Open ROADAID_ERD_TABLES.csv in Excel
2. Select table data
3. Copy → Paste to Word as "Table"
4. Apply Word table styles
5. Use in thesis documentation

### **For LaTeX:**
1. Use `csvsimple` package
2. Import CSV directly:
```latex
\usepackage{csvsimple}
\csvautotabular{ROADAID_ERD_TABLES.csv}
```

### **For Markdown:**
CSV data is already formatted for markdown tables in the original DATABASE_ERD.md file.

---

## 📤 Export Options

### **From Excel to Figma:**
```
1. Format table in Excel
2. Take screenshot (Snipping Tool)
3. Import image to Figma
4. Trace over with Figma shapes
```

### **From dbdiagram.io to Figma:**
```
1. Generate ERD at dbdiagram.io
2. Export as PNG (high resolution)
3. Import to Figma as image layer
4. Use as reference for drawing
```

### **From draw.io to Figma:**
```
1. Create ERD in draw.io
2. Export as SVG (vector format)
3. Import SVG to Figma
4. Ungroup and edit directly
```

---

## 🛠️ Tools Compatibility

### **Compatible Tools:**
✅ Microsoft Excel  
✅ Google Sheets  
✅ Figma (with plugins)  
✅ dbdiagram.io  
✅ draw.io / diagrams.net  
✅ Lucidchart  
✅ MySQL Workbench (import structure)  
✅ pgAdmin (PostgreSQL)  
✅ DBeaver  
✅ TablePlus  
✅ Navicat  
✅ Visual Paradigm  
✅ Enterprise Architect  

---

## 📖 Usage Examples

### **Example 1: Create ERD in dbdiagram.io**
```sql
// Paste this to dbdiagram.io

Table auth.users {
  id uuid [pk]
  email text [unique]
  encrypted_password text
  created_at timestamptz
}

Table user_profiles {
  id uuid [pk, ref: > auth.users.id]
  first_name varchar
  last_name varchar
  email varchar [unique]
  phone_number varchar
  user_type varchar
  shop_id uuid [ref: > shops.id]
}

// ... continue for all tables
```

### **Example 2: Import to MySQL Workbench**
```sql
-- Generate CREATE TABLE statements from CSV
-- Use Excel formula to convert CSV to SQL
```

### **Example 3: Google Sheets Formula**
```excel
// In Google Sheets, create visualization
=QUERY(IMPORTDATA("ROADAID_ERD_TABLES.csv"), 
  "SELECT Col1, COUNT(Col1) 
   GROUP BY Col1 
   LABEL COUNT(Col1) 'Field Count'")
```

---

## 🎓 For Thesis Documentation

### **Include in Chapter 3 (Methodology):**
1. **Database Design Section:**
   - Include ERD diagram (from Figma export)
   - Reference ROADAID_ERD_TABLES.csv as Appendix A
   - Reference ROADAID_ERD_RELATIONSHIPS.csv as Appendix B

2. **Data Dictionary:**
   - Use CSV as complete data dictionary
   - Already has all fields, types, descriptions

3. **Relationship Matrix:**
   - Use relationships CSV for table
   - Shows all FK relationships

---

## 📊 Statistics Summary

**From ROADAID_ERD_TABLES.csv:**
- Total Tables: 66
- Total Fields: 440+
- Total Primary Keys: 66
- Total Foreign Keys: 120+
- Total Unique Constraints: 25+

**From ROADAID_ERD_RELATIONSHIPS.csv:**
- Total Relationships: 56+
- One-to-One: 10
- One-to-Many: 46+
- Many-to-Many: 0 (normalized to 3NF)

---

## 🔧 Troubleshooting

### **CSV not opening correctly:**
- Use UTF-8 encoding
- Open with Excel → Data → From Text/CSV
- Delimiter: Comma (,)

### **Colors not showing in Figma:**
- Manually apply hex colors from Color Group column
- Use Figma color picker
- Create color palette from hex codes

### **Relationships not clear:**
- Filter ROADAID_ERD_RELATIONSHIPS.csv by "From Table"
- See all outgoing relationships
- Draw one at a time

---

**Files Ready for Download:**
1. ✅ ROADAID_ERD_TABLES.csv (440+ rows)
2. ✅ ROADAID_ERD_RELATIONSHIPS.csv (56+ relationships)
3. ✅ This README guide

**Next Steps:**
1. Download both CSV files
2. Choose import method (dbdiagram.io recommended)
3. Generate ERD diagram
4. Import to Figma for final design
5. Export as PDF for thesis

---

**Created:** October 10, 2025  
**Format:** CSV (Comma-Separated Values)  
**Encoding:** UTF-8  
**Compatible:** Excel, Google Sheets, Figma, Database Tools
