# Job History Payment Data Fix

## Date: October 6, 2025

## Problem Fixed
Sa job history ng mechanic at customer, hindi naka-display properly yung payment information:
- ❌ Hindi makita ang service fee (bayad ng customer sa pag-pump/towing)
- ❌ Hindi makita ang invoice total (binigay ng mechanic na presyo)
- ❌ Magulo kung ano ang total_amount

## Solution Summary

### 🎯 Data Flow Definition
1. **service_fee** = Initial payment na ginawa ng customer (sa service_requests table)
2. **invoice_amount** = Final na presyo na sinend ng mechanic (sa invoices table)
3. **total_amount** = Ilalagay natin yung invoice_amount (kung may invoice), otherwise service_fee

### Changes Made

#### 1. **Updated Models** (`lib/models/job_history.dart`)

**CustomerJobHistory Model:**
```dart
class CustomerJobHistory {
  // ... existing fields ...
  
  // NEW: Payment details from service_requests and invoices
  final double? serviceFee; // From service_requests.service_fee
  final double? invoiceAmount; // From invoices.total_amount
  
  // Formatted display methods
  String get formattedServiceFee {
    if (serviceFee == null) return 'N/A';
    return '₱${serviceFee!.toStringAsFixed(2)}';
  }

  String get formattedInvoiceAmount {
    if (invoiceAmount == null) return 'N/A';
    return '₱${invoiceAmount!.toStringAsFixed(2)}';
  }
}
```

**MechanicJobHistory Model:**
```dart
class MechanicJobHistory {
  // ... existing fields ...
  
  // NEW: Payment details from service_requests and invoices
  final double? serviceFee; // From service_requests.service_fee
  final double? invoiceAmount; // From invoices.total_amount
  
  // Formatted display methods
  String get formattedServiceFee {
    if (serviceFee == null) return 'N/A';
    return '₱${serviceFee!.toStringAsFixed(2)}';
  }

  String get formattedInvoiceAmount {
    if (invoiceAmount == null) return 'N/A';
    return '₱${invoiceAmount!.toStringAsFixed(2)}';
  }
}
```

**ServiceRequestData Model:**
```dart
class ServiceRequestData {
  // ... existing fields ...
  final double? serviceFee; // NEW: Added service_fee field
  
  factory ServiceRequestData.fromJson(Map<String, dynamic> json) {
    return ServiceRequestData(
      // ... other fields ...
      serviceFee: json['service_fee']?.toDouble(), // NEW
    );
  }
}
```

#### 2. **Updated Mechanic History Service** (`lib/services/mechanic_history_service.dart`)

**Query Enhancement:**
```dart
var query = _supabase
    .from('mechanic_job_history')
    .select('''
      *,
      service_requests!mechanic_job_history_service_request_id_fkey(
        title,
        description,
        pickup_address,
        service_type,
        service_fee  // 🎯 ADDED: Fetch service_fee
      ),
      // ... other joins ...
    ''')
    .eq('mechanic_id', user.id);
```

**Enrichment Logic:**
```dart
Future<List<MechanicJobHistory>> _enrichWithEarningsData(List<MechanicJobHistory> jobs) async {
  // Get invoices for all jobs
  final invoices = // ... fetch from database
  
  return jobs.map((job) {
    final invoice = invoiceMap[job.serviceRequestId];
    final serviceFee = job.serviceRequest?.serviceFee; // Get from service_requests
    
    if (invoice != null && invoice['status'] == 'paid') {
      return MechanicJobHistory(
        // ... all fields ...
        totalAmount: invoice['total_amount']?.toDouble(), // 🎯 Invoice total
        serviceFee: serviceFee, // 🎯 Service fee
        invoiceAmount: invoice['total_amount']?.toDouble(), // 🎯 Same as total
      );
    }
    // Return with available data if no paid invoice
  }).toList();
}
```

#### 3. **Updated Customer History Service** (`lib/services/customer_history_service.dart`)

**Sync Function Update:**
```dart
// When syncing service_requests to customer_job_history
if (req['invoices'] != null && req['invoices'].isNotEmpty) {
  // 🎯 Invoice total_amount = what mechanic sent
  invoiceAmount = req['invoices'][0]['total_amount']?.toDouble();
  totalAmount = invoiceAmount; // Set total_amount to invoice amount
} else {
  totalAmount = req['final_price']?.toDouble() ?? req['estimated_price']?.toDouble();
}

// Note: service_fee will be fetched dynamically via enrichment function
```

**NEW Enrichment Function:**
```dart
Future<List<CustomerJobHistory>> _enrichCustomerHistoryWithPaymentData(
  List<CustomerJobHistory> jobs
) async {
  // Get service_requests for service_fee
  final serviceRequests = await _supabase
      .from('service_requests')
      .select('id, service_fee')
      .in_('id', requestIds);

  // Get invoices for invoice total_amount
  final invoices = await _supabase
      .from('invoices')
      .select('request_id, total_amount, status')
      .in_('request_id', requestIds);

  return jobs.map((job) {
    final serviceFee = serviceRequestMap[job.serviceRequestId]?['service_fee'];
    final invoice = invoiceMap[job.serviceRequestId];
    final invoiceAmount = (invoice != null && invoice['status'] == 'paid') 
        ? invoice['total_amount'] 
        : null;

    return CustomerJobHistory(
      // ... all fields ...
      totalAmount: invoiceAmount ?? job.totalAmount, // 🎯 Invoice total if available
      serviceFee: serviceFee, // 🎯 Service fee from service_requests
      invoiceAmount: invoiceAmount, // 🎯 Invoice total from invoices
    );
  }).toList();
}
```

**Integration:**
```dart
// In getCustomerJobHistory()
List<CustomerJobHistory> historyList;

if (usingServiceRequests) {
  historyList = result.map((data) => _convertServiceRequestToCustomerHistory(data)).toList();
} else {
  historyList = result.map((data) => _convertCustomerJobHistoryToModel(data)).toList();
}

// 🎯 NEW: Enrich with service_fee and invoice data
historyList = await _enrichCustomerHistoryWithPaymentData(historyList);

return historyList;
```

## Data Structure

### Tables Involved:

1. **service_requests**
   - `service_fee` - Initial payment ng customer (pump/towing fee)
   - `estimated_price` - Estimated price
   - `final_price` - Final price

2. **invoices**
   - `total_amount` - Invoice na sinend ng mechanic (parts + labor)
   - `status` - paid, pending, etc.
   - `request_id` - Links to service_requests

3. **mechanic_job_history**
   - `total_amount` - NOW SET TO: invoice total_amount
   - Enriched with: `serviceFee`, `invoiceAmount`

4. **customer_job_history**
   - `total_amount` - NOW SET TO: invoice total_amount
   - Enriched with: `serviceFee`, `invoiceAmount`

## Display Format

### For Customer View:
```
Service Request: Oil Change
Service Fee: ₱500.00    (Pump/towing fee)
Invoice Total: ₱3,500.00 (Mechanic's final invoice)
Status: Completed
```

### For Mechanic View:
```
Job: Oil Change
Service Fee: ₱500.00     (Customer paid for pump)
Invoice Amount: ₱3,500.00 (You sent invoice)
Your Earnings: ₱2,625.00  (75% of invoice)
Status: Completed
```

## How It Works

### Flow:
1. **Customer requests service** → `service_fee` saved in `service_requests`
2. **Mechanic inspects** → Creates invoice
3. **Mechanic sends invoice** → `total_amount` saved in `invoices`
4. **Customer pays invoice** → Invoice marked as `paid`
5. **Job completes** → Synced to history tables with enrichment

### Enrichment Process:
```
┌─────────────────────┐
│ Job History Request │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Query History Table │ (mechanic_job_history or customer_job_history)
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Enrich with:        │
│ 1. service_requests │ → service_fee
│ 2. invoices         │ → invoice_amount (if paid)
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Return Complete     │
│ Job History with    │
│ All Payment Data    │
└─────────────────────┘
```

## Benefits

✅ **Clear Separation**: Service fee vs Invoice amount
✅ **Complete Data**: All payment info sa history
✅ **Proper Attribution**: Makita kung magkano ang initial vs final
✅ **Backwards Compatible**: Existing code still works, may additional data lang
✅ **Dynamic Enrichment**: Hindi need i-store lahat sa history table, real-time fetch
✅ **Formatted Display**: Ready-to-use formatted strings (`formattedServiceFee`, `formattedInvoiceAmount`)

## UI Updates Needed

### Customer History Screen
```dart
// Display both service fee and invoice
Text('Service Fee: ${job.formattedServiceFee}'),
Text('Invoice Total: ${job.formattedInvoiceAmount}'),
if (job.invoiceAmount != null && job.serviceFee != null)
  Text('Additional: ${(job.invoiceAmount! - job.serviceFee!).toStringAsFixed(2)}'),
```

### Mechanic History Screen
```dart
// Display service fee and invoice sent
Text('Service Fee (Customer paid): ${job.formattedServiceFee}'),
Text('Invoice Amount (You sent): ${job.formattedInvoiceAmount}'),
Text('Your Earnings: ${job.formattedNetEarnings}'),
```

## Testing Checklist

- [ ] Load mechanic job history - check if serviceFee and invoiceAmount appear
- [ ] Load customer job history - check if serviceFee and invoiceAmount appear
- [ ] Verify service_fee from service_requests is fetched correctly
- [ ] Verify invoice total_amount from invoices is fetched correctly
- [ ] Check jobs without invoices still show service_fee
- [ ] Check jobs with paid invoices show both values
- [ ] Test formatted display methods work correctly

## Database Queries

### Check if data exists:
```sql
-- Check service_requests have service_fee
SELECT id, service_fee, estimated_price, final_price
FROM service_requests
WHERE service_fee IS NOT NULL
LIMIT 10;

-- Check invoices exist with total_amount
SELECT id, request_id, total_amount, status
FROM invoices
WHERE status = 'paid'
LIMIT 10;

-- Check mechanic_job_history
SELECT id, service_request_id, total_amount, created_at
FROM mechanic_job_history
ORDER BY created_at DESC
LIMIT 5;

-- Check customer_job_history
SELECT id, service_request_id, total_amount, created_at
FROM customer_job_history
ORDER BY created_at DESC
LIMIT 5;
```

## Summary

Ginawa natin:
1. ✅ Added `serviceFee` and `invoiceAmount` fields sa models
2. ✅ Updated queries to fetch `service_fee` from `service_requests`
3. ✅ Created enrichment functions to get invoice `total_amount`
4. ✅ Set `total_amount` in history tables to invoice amount
5. ✅ Added formatted display methods
6. ⏳ Need to update UI screens to show both values

Result: Makikita na sa history ang:
- **Service Fee** = Original payment ng customer
- **Invoice Amount** = Final na presyo na sinend ng mechanic
- **Clear separation** between the two amounts! 🎉
