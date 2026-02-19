# 🛠️ Manage Services - Gabay para sa Talyer Owner

## ✅ Mga Pagbabago (What Changed)

### Dati (Before):
- May mga toggle switches (on/off buttons)
- Required ang category
- May duration field
- Complicated ang form

### Ngayon (Now):
- **SIMPLE LANG** - 3 fields lang kailangan:
  1. **Service Name** (Pangalan ng serbisyo) - REQUIRED
  2. **Description** (Paliwanag) - OPTIONAL
  3. **Price** (Presyo) - REQUIRED

---

## 📱 Paano Gamitin (How to Use)

### 1️⃣ Mag-add ng Service

1. Buksan ang **Manage Services** screen
2. Pindutin ang **RED "Add Service" button** sa baba
3. Punan ang form:
   ```
   Service Name: "Oil Change"
   Description: "Includes filter replacement and full synthetic oil"
   Price: 1500
   ```
4. Pindutin ang **"Add Service"** button
5. ✅ Done! Makikita mo na sa list

### 2️⃣ Mag-edit ng Service

1. Pindutin ang **BLUE EDIT icon** sa service card
2. Baguhin ang gusto mong field
3. Pindutin **"Update"**
4. ✅ Updated na!

### 3️⃣ Mag-delete ng Service

1. Pindutin ang **RED DELETE icon**
2. Confirm ang deletion
3. ✅ Deleted na!

### 4️⃣ Mag-search ng Service

1. May search bar sa taas
2. I-type ang service name o description
3. Automatic na mag-filter ang list

---

## 🗄️ Database Connection

### Table: `shop_services`

Ang app ay direktang naka-connect sa **shop_services table** sa Supabase.

### Required Columns:
```sql
- id (UUID) - auto-generated
- shop_id (UUID) - automatic from your shop
- service_name (TEXT) - yung ilalagay mo
- description (TEXT) - optional
- base_price (NUMERIC) - presyo
- is_custom (BOOLEAN) - automatically set to true
- is_active (BOOLEAN) - automatically set to true
- created_at (TIMESTAMP) - automatic
- updated_at (TIMESTAMP) - automatic
```

### Sample Insert Query:
```sql
INSERT INTO shop_services (
    shop_id,
    service_name,
    description,
    base_price,
    is_custom,
    is_active
) VALUES (
    'your-shop-id',
    'Brake Pad Replacement',
    'Front and rear brake pads with labor',
    2500.00,
    true,
    true
);
```

---

## ✅ Ano ang Kailangan Gawin sa Database

### Step 1: Run ang SQL Setup
```bash
1. Buksan ang Supabase Dashboard
2. Go to SQL Editor
3. Copy-paste ang SHOP_SERVICES_DATABASE_SETUP.sql
4. Click "Run"
```

### Step 2: Verify ang Policies
Dapat may mga policies na ito:
- ✅ Shop owners can view their shop services
- ✅ Shop owners can insert their shop services
- ✅ Shop owners can update their shop services
- ✅ Shop owners can delete their shop services
- ✅ Customers can view active shop services

### Step 3: Test
```sql
-- Check kung may data ka na
SELECT * FROM shop_services 
WHERE shop_id = 'YOUR_SHOP_ID'
ORDER BY created_at DESC;
```

---

## 🔍 Troubleshooting

### Problem: "Error loading services"
**Solution:**
```sql
-- Check kung tama ang RLS policies
SELECT * FROM pg_policies 
WHERE tablename = 'shop_services';

-- Check kung may shop_id ka
SELECT * FROM shops WHERE owner_id = auth.uid();
```

### Problem: "Cannot insert service"
**Solution:**
1. Siguruhing may shop ka na sa `shops` table
2. Check kung naka-login ka as talyer_owner
3. Verify ang RLS policy for INSERT

### Problem: "Services hindi lumalabas"
**Solution:**
```sql
-- Direct query to check
SELECT 
    s.shop_name,
    ss.service_name,
    ss.base_price
FROM shop_services ss
JOIN shops s ON ss.shop_id = s.id
WHERE s.owner_id = 'YOUR_USER_ID';
```

---

## 📊 Sample Services na Pwede Mong I-add

```
1. Service Name: "Oil Change"
   Description: "Full synthetic oil with filter"
   Price: 1500

2. Service Name: "Tire Rotation"
   Description: "All four tires rotated and balanced"
   Price: 800

3. Service Name: "Brake Inspection"
   Description: "Complete brake system check"
   Price: 500

4. Service Name: "Battery Replacement"
   Description: "New battery with installation"
   Price: 3500

5. Service Name: "Aircon Service"
   Description: "Cleaning and recharge"
   Price: 2000
```

---

## 🎯 Key Features

### ✅ Naka-connect sa Database
- Real-time save sa Supabase
- Automatic sync sa lahat ng devices
- Secure with RLS policies

### ✅ Simple Form
- 3 fields lang kailangan
- No complicated dropdowns
- Hindi required ang category

### ✅ Easy to Manage
- Edit anytime
- Delete with confirmation
- Search functionality

### ✅ Custom Services
- Pwede kang mag-lagay ng kahit ano
- Hindi restricted sa default categories
- Pag-aari mo ang list

---

## 📝 Notes

1. **Service Name** - Required. Ito ang lalabas sa customers
2. **Description** - Optional pero recommended para malinaw
3. **Price** - Required. Peso (₱) ang currency
4. **is_custom** - Automatic na true para sa lahat ng dinagdag mo
5. **is_active** - Automatic na true, pwede i-edit later

---

## 🚀 Next Steps

1. **Run ang SQL setup** - SHOP_SERVICES_DATABASE_SETUP.sql
2. **Test ang app** - Try mag-add ng service
3. **Verify sa database** - Check kung na-save
4. **Add more services** - Lagyan ng laman ang shop mo

---

## 📞 Support

Kung may problema:
1. Check ang SQL script
2. Verify ang RLS policies
3. Test ang database connection
4. Check console for errors

---

**Tapos na! Simple lang ngayon ang pag-manage ng services! 🎉**
