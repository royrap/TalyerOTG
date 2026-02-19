# PayMongo Webhook Setup for Automatic Payment Updates

## 🎯 Goal: "dapat kusa ma update yung status pag click sa PayMongo di manual"

Your ₱515.00 GCash payment completed successfully but didn't auto-update because PayMongo webhooks aren't configured yet. Here's how to fix it:

## ⚡ IMMEDIATE FIX (For Current Payment)

Run this in your app to sync the ₱515.00 payment:

```dart
// In your Flutter app, call this function
final paymongoService = PayMongoService.instance;
final success = await paymongoService.forceSyncPaymentByAmount(515.00);
if (success) {
  print('✅ ₱515.00 payment synced successfully!');
} else {
  print('❌ Payment sync failed');
}
```

Or run the SQL script: `SYNC_REAL_PAYMONGO_PAYMENTS.sql`

## 🔧 PERMANENT FIX (For Future Automatic Updates)

### Step 1: Create Supabase Edge Function

Create a webhook endpoint in Supabase:

```sql
-- Create this as a Supabase Edge Function
create or replace function handle_paymongo_webhook(
  event_data jsonb
) returns json as $$
declare
  event_type text;
  payment_data jsonb;
  request_id text;
  checkout_session jsonb;
begin
  -- Extract event details
  event_type := event_data->'data'->'attributes'->>'type';
  payment_data := event_data->'data'->'attributes'->'data';
  
  -- Log the webhook
  insert into paymongo_webhook_events (
    paymongo_event_id,
    event_type,
    event_data,
    processed,
    created_at
  ) values (
    event_data->'data'->>'id',
    event_type,
    event_data,
    false,
    now()
  );
  
  -- Handle checkout session payment success
  if event_type = 'checkout_session.payment.paid' then
    request_id := payment_data->'attributes'->>'reference_number';
    
    if request_id is not null then
      -- Update service request to ready_to_assign
      update service_requests set
        status = 'ready_to_assign',
        payment_status = 'completed',
        payment_completed_at = now(),
        updated_at = now()
      where id = request_id::uuid;
      
      -- Update payment record
      update payments set
        status = 'completed',
        payment_gateway = 'paymongo',
        payment_method = 'gcash',
        processed_at = now()
      where request_id = request_id::uuid;
      
      -- Mark webhook as processed
      update paymongo_webhook_events set
        processed = true,
        processed_at = now()
      where paymongo_event_id = event_data->'data'->>'id';
      
      return json_build_object('success', true, 'message', 'Payment processed');
    end if;
  end if;
  
  return json_build_object('success', false, 'message', 'Event not handled');
end;
$$ language plpgsql;
```

### Step 2: Get Your Webhook URL

Your webhook endpoint will be:
```
https://[your-supabase-project].supabase.co/functions/v1/paymongo-webhook
```

### Step 3: Configure PayMongo Dashboard

1. Go to PayMongo Dashboard: https://dashboard.paymongo.com/
2. Navigate to **Developers** → **Webhooks**
3. Click **Create Webhook**
4. Set:
   - **URL**: `https://[your-supabase-project].supabase.co/functions/v1/paymongo-webhook`
   - **Events**: Select `checkout_session.payment.paid`
   - **Description**: RoadAid Payment Automation

### Step 4: Test the Webhook

Create a test payment and verify it auto-updates:

```dart
// Test function in your app
Future<void> testPaymentWebhook() async {
  final paymongoService = PayMongoService.instance;
  
  // Create a test payment
  final checkoutUrl = await paymongoService.createQRCodeForPayment(
    invoiceId: 'test-request-id',
    amount: 100.00,
    description: 'Test Payment for Webhook',
  );
  
  print('Test payment URL: $checkoutUrl');
  // Complete payment and check if status updates automatically
}
```

## 🔍 Verification

After setup, check if webhooks are working:

```sql
-- Check webhook events
SELECT 
  paymongo_event_id,
  event_type,
  processed,
  created_at,
  processed_at
FROM paymongo_webhook_events
ORDER BY created_at DESC
LIMIT 10;

-- Check ready_to_assign requests
SELECT 
  id,
  status,
  payment_status,
  final_price,
  payment_completed_at
FROM service_requests
WHERE status = 'ready_to_assign'
ORDER BY updated_at DESC;
```

## 🚀 Current Status

✅ **Database triggers**: Working  
✅ **Webhook processing system**: Ready  
✅ **Payment sync functions**: Available  
❌ **Webhook endpoint**: Needs configuration  
❌ **PayMongo webhook URL**: Not set up yet  

## 🎯 Result After Setup

Once configured, when users click "Complete Payment" in PayMongo:
1. PayMongo sends webhook to your endpoint
2. Your system automatically processes the webhook
3. Service request status changes to `ready_to_assign`
4. Payment status becomes `completed`
5. **NO MANUAL INTERVENTION NEEDED!** ✨

## 📱 For Your Current ₱515.00 Payment

Use the manual sync function until webhooks are configured:

```dart
await PayMongoService.instance.forceSyncPaymentByAmount(515.00);
```

This will immediately update your ₱515.00 GCash payment to completed status.
