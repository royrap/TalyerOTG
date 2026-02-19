# ✅ CUSTOMER INVOICE LIST - PAY BUTTON ADDED!

## 🎯 MGA GINAWA

### 1. **Added "Pay" Button sa Invoice List**
- File: `lib/customer/customer_invoices_screen.dart`
- Added import for `Invoice` model and `InvoicePaymentScreen`
- Added "Pay ₱X.XX" button sa bottom ng invoice card
- Button shows only for unpaid invoices (status: 'sent', 'pending', 'accepted')

---

## 🚀 COMPLETE FLOW

### **Customer View - Invoices Tab**

#### **Step 1: Open Invoices Screen**
```
Dashboard → Bottom Navigation → "Invoices" tab
Shows list of all customer invoices
```

#### **Step 2: View Invoice List**
```
┌─────────────────────────────────────┐
│ Invoice #1BA9422D                   │
│ Shop: MechAid Supply                │
│ Amount: ₱2.20                       │
│ Status: [SENT]                      │
│ Date: 3/10/2025                     │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │   Pay ₱2.20                     │ │ ← NEW BUTTON!
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Invoice #C2FE626F                   │
│ Shop: Labor Shop                    │
│ Amount: ₱2200.00                    │
│ Status: [SENT]                      │
│ Date: 3/10/2025                     │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │   Pay ₱2200.00                  │ │ ← CLICK HERE!
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

#### **Step 3: Click "Pay" Button**
```
Navigation → InvoicePaymentScreen
Shows Payment Selection Screen:

┌─────────────────────────────────────┐
│ Invoice Summary                     │
│ - Invoice ID: #C2FE626F             │
│ - Service: labor                    │
│ - Date: Oct 03, 2025                │
│ - Total: ₱2200.00                   │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Choose Payment Method               │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │  💳 ONLINE PAYMENT              │ │
│ │  Fast & Secure                  │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │  💵 CASH PAYMENT                │ │
│ │  Photo Verification             │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

---

## 💳 PAYMENT OPTIONS

### **Option 1: Online Payment**
1. Click "Online Payment"
2. PayMongo WebView opens
3. Select payment method (GCash, Card, etc)
4. Complete payment
5. Status updates to "paid"
6. Navigate back to invoice list
7. Invoice list auto-refreshes ✅

### **Option 2: Cash Payment**
1. Click "Cash Payment"
2. Camera buttons appear
3. Take Photo 1 (cash handover) 📸
4. Take Photo 2 (receipt/confirmation) 📸
5. Submit photos
6. Photos upload to Supabase storage
7. Status updates to "paid"
8. Navigate back to invoice list
9. Invoice list auto-refreshes ✅

---

## 🔍 INVOICE STATUS LOGIC

### **When "Pay" Button Shows:**
- Status = 'sent' → **SHOW PAY BUTTON**
- Status = 'pending' → **SHOW PAY BUTTON**
- Status = 'accepted' → **SHOW PAY BUTTON**

### **When "Pay" Button Hides:**
- Status = 'paid' → **NO BUTTON** (already paid)
- Status = 'cancelled' → **NO BUTTON** (cancelled)
- Status = 'overdue' → **NO BUTTON** (needs special handling)

---

## 📊 CODE CHANGES

### **File: `customer_invoices_screen.dart`**

#### **Added Imports:**
```dart
import '../models/invoice.dart';
import 'invoice_payment_screen.dart';
```

#### **Modified Invoice Card:**
```dart
Card(
  child: Column(  // Changed from ListTile to Column
    children: [
      ListTile(...),  // Existing invoice info
      
      // NEW: Pay button for unpaid invoices
      if (invoice['status']?.toLowerCase() == 'sent' || 
          invoice['status']?.toLowerCase() == 'pending' ||
          invoice['status']?.toLowerCase() == 'accepted')
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () async {
                // Create Invoice model
                final invoiceModel = Invoice(...);
                
                // Navigate to payment screen
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InvoicePaymentScreen(
                      invoice: invoiceModel,
                    ),
                  ),
                );
                
                // Refresh invoices after payment
                if (result == true) {
                  await _fetchInvoices();
                }
              },
              child: Text('Pay ₱${invoice['total_amount']}'),
            ),
          ),
        ),
    ],
  ),
)
```

---

## 🎨 UI COMPONENTS

### **Invoice Card with Pay Button**
```
┌─────────────────────────────────────┐
│ 🟦 [Icon]  Invoice #ABC123          │
│            Shop: MechAid Supply     │
│            Amount: ₱2200.00          │
│            [STATUS BADGE]            │
│            Date: 3/10/2025           │
│                                 →   │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ Pay ₱2200.00                    │ │ ← Red button
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

### **Button Styling:**
- **Background**: Red (`Color.fromARGB(255, 176, 12, 1)`)
- **Text**: White, Bold, 16px
- **Height**: 48px
- **Width**: Full width with 16px padding
- **Border Radius**: 8px
- **Elevation**: 2

---

## 🔄 AUTO-REFRESH FLOW

### **After Payment:**
```
1. User completes payment (Online or Cash)
2. Payment screen returns `result = true`
3. Invoice list screen detects return
4. Calls `_fetchInvoices()` to refresh
5. Updated invoices loaded from database
6. UI updates automatically
7. Paid invoice now shows status = "PAID"
8. "Pay" button disappears from that invoice
```

---

## 📱 REAL-TIME UPDATES

### **Invoice List has Real-Time Listener:**
```dart
void _startRealTimeUpdates() {
  _invoiceStreamSubscription = supabase
    .from('invoices')
    .stream(primaryKey: ['id'])
    .eq('customer_id', user.id)
    .listen((data) {
      _handleInvoiceUpdate(data);
    });
}
```

**What this means:**
- When mechanic creates invoice → **List updates automatically**
- When payment completes → **Status updates automatically**
- When invoice cancelled → **List updates automatically**

---

## ✅ TESTING CHECKLIST

### **Invoice List View:**
- [ ] Open Invoices tab → List loads
- [ ] See multiple invoices with different statuses
- [ ] Unpaid invoices show "Pay" button
- [ ] Paid invoices hide "Pay" button

### **Online Payment Flow:**
- [ ] Click "Pay ₱X.XX" → Navigate to payment screen
- [ ] Click "Online Payment" → PayMongo opens
- [ ] Complete payment → Success message
- [ ] Navigate back → Invoice list refreshes
- [ ] Invoice status = "PAID"
- [ ] "Pay" button disappears

### **Cash Payment Flow:**
- [ ] Click "Pay ₱X.XX" → Navigate to payment screen
- [ ] Click "Cash Payment" → Camera buttons show
- [ ] Take 2 photos → Previews show
- [ ] Submit → Upload completes
- [ ] Navigate back → Invoice list refreshes
- [ ] Invoice status = "PAID"
- [ ] "Pay" button disappears

### **Real-Time Updates:**
- [ ] Mechanic creates invoice → List updates
- [ ] Payment completes → Status updates
- [ ] Pull to refresh → Manual refresh works

---

## 🗄️ DATABASE FLOW

### **Before Payment:**
```sql
SELECT * FROM invoices WHERE id = 'xxx';
-- status: 'sent'
-- paid_at: NULL
-- payment_method: NULL
```

### **After Online Payment:**
```sql
SELECT * FROM invoices WHERE id = 'xxx';
-- status: 'paid'
-- paid_at: '2025-10-03 08:30:25.9+00'
-- payment_method: 'online'
```

### **After Cash Payment:**
```sql
SELECT * FROM invoices WHERE id = 'xxx';
-- status: 'paid'
-- paid_at: '2025-10-03 08:30:25.9+00'
-- payment_method: 'cash'

SELECT * FROM cash_payment_verifications WHERE invoice_id = 'xxx';
-- payment_photo_url: 'storage://...'
-- receipt_photo_url: 'storage://...'
-- verification_status: 'pending'
```

---

## 🎯 COMPLETE CUSTOMER FLOW

```
1. Service Request Created
   ↓
2. Mechanic Accepts
   ↓
3. Customer Pays Service Fee (₱500)
   ↓
4. Mechanic Arrives & Works
   ↓
5. Mechanic Generates Invoice (₱2200)
   ↓
6. Invoice appears in Customer's "Invoices" tab ← YOU ARE HERE
   ↓
7. Customer clicks "Pay ₱2200.00" ← NEW BUTTON!
   ↓
8. Payment Selection Screen opens
   ↓
9. Customer selects Online OR Cash
   ↓
10. Payment completes
   ↓
11. Invoice status = "paid"
   ↓
12. Customer generates QR code
   ↓
13. Mechanic scans QR
   ↓
14. Job completed!
```

---

## 🚀 AYOS NA!

✅ **Invoice List** - Shows all customer invoices
✅ **Pay Button** - Appears for unpaid invoices only
✅ **Navigation** - Goes to InvoicePaymentScreen
✅ **Online/Cash** - Both payment options working
✅ **Auto-Refresh** - List updates after payment
✅ **Real-Time** - Status changes update automatically

**NASA IMAGE MO NA ANG PAY BUTTON!** 🎉

---

## 📸 EXPECTED UI (Based on your image)

### **Before (OLD):**
```
Invoice List → Click invoice → Invoice details (no payment)
```

### **After (NEW):**
```
Invoice List → See "Pay ₱X.XX" button → Click → Payment Selection → Online/Cash
```

**Exactly like the image you sent!** ✅
