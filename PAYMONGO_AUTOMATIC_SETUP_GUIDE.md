# 🚀 PayMongo Automatic Webhook Setup Guide

## ✅ CURRENT STATUS
You already have the Flutter webhook handling code in `paymongo_service.dart` and `paymongo_webhook_handler.dart`. Now we need to ensure the webhook endpoint is accessible to PayMongo.

## 🔧 SETUP STEPS

### 1. **Database Setup** (Execute First)
Run `AUTOMATIC_PAYMONGO_SYNC.sql` in Supabase Dashboard to create:
- ✅ Automatic webhook processing triggers
- ✅ Webhook events table
- ✅ Payment completion simulation functions
- ✅ Integration status checking

### 2. **Webhook Endpoint Configuration**

#### Option A: Supabase Edge Functions (Recommended)
Create a new Edge Function in Supabase:

```typescript
// supabase/functions/paymongo-webhook/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, paymongo-signature',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const body = await req.text()
    const headers = Object.fromEntries(req.headers.entries())
    
    console.log('🔔 PayMongo webhook received')
    
    // Parse webhook data
    const webhookData = JSON.parse(body)
    const eventId = webhookData.data.id
    const eventType = webhookData.data.attributes.type
    
    // Store webhook event (this will trigger our automatic processing)
    const { error } = await supabase
      .from('paymongo_webhook_events')
      .insert({
        paymongo_event_id: eventId,
        event_type: eventType,
        webhook_data: webhookData,
        processed: false
      })
    
    if (error) {
      console.error('❌ Error storing webhook event:', error)
      return new Response(JSON.stringify({ error: 'Failed to process webhook' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }
    
    console.log('✅ Webhook processed successfully:', eventId)
    
    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
    
  } catch (error) {
    console.error('❌ Webhook processing error:', error)
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
```

Deploy this to Supabase:
```bash
supabase functions deploy paymongo-webhook
```

#### Option B: Your Domain Webhook Endpoint
If you have your own server, create endpoint at: `https://yourdomain.com/api/paymongo/webhook`

### 3. **PayMongo Dashboard Configuration**

1. **Login to PayMongo Dashboard**: https://dashboard.paymongo.com/
2. **Go to Webhooks section**
3. **Create New Webhook**:
   - **URL**: `https://your-supabase-project.supabase.co/functions/v1/paymongo-webhook`
   - **Events to Listen**: 
     - ✅ `payment_intent.payment.paid`
     - ✅ `payment_intent.payment.failed` 
     - ✅ `checkout_session.payment.paid`
   - **Status**: Active

### 4. **Test Automatic Sync**

After setup, test with this SQL:
```sql
-- Test automatic webhook processing
SELECT simulate_paymongo_payment_completion(
    'your-request-id-here'::uuid,
    'test_transaction_123'
);

-- Check if it worked
SELECT * FROM service_requests WHERE id = 'your-request-id-here';
```

## 🎯 EXPECTED FLOW

### **Customer Payment Process:**
1. **Customer clicks "Pay Now"** → Opens PayMongo checkout
2. **Customer completes payment** → PayMongo processes payment
3. **PayMongo sends webhook** → Your endpoint receives event
4. **Automatic trigger fires** → Database updates `status = 'ready_to_assign'`
5. **Talyer owner sees request** → In "Ready to Assign" tab immediately

### **No Manual Intervention Required!** ✅

## 📊 MONITORING

### Check if webhooks are working:
```sql
-- See recent webhook events
SELECT * FROM paymongo_webhook_events 
ORDER BY created_at DESC LIMIT 10;

-- Check integration status
SELECT * FROM check_paymongo_integration_status();

-- See ready-to-assign requests
SELECT id, status, payment_status, payment_completed_at 
FROM service_requests 
WHERE status = 'ready_to_assign'
ORDER BY payment_completed_at DESC;
```

## 🚨 TROUBLESHOOTING

### If payments aren't auto-updating:
1. **Check webhook endpoint is reachable** from PayMongo
2. **Verify webhook events are being stored** in `paymongo_webhook_events` table
3. **Check Supabase logs** for any errors
4. **Test with simulation function** to verify triggers work

### Force update stuck payments:
```sql
-- For payments that completed in PayMongo but didn't sync
SELECT simulate_paymongo_payment_completion(
    'request-id-here'::uuid,
    'paymongo-transaction-id-here'
);
```

## ✅ SUCCESS CRITERIA

After setup, when customer pays via PayMongo:
- ✅ **Service request status** automatically becomes `'ready_to_assign'`
- ✅ **Payment status** automatically becomes `'completed'`
- ✅ **Request appears** in talyer owner's "Ready to Assign" tab
- ✅ **No manual SQL scripts** needed anymore!

**"dapat kusa ma update yung status pag click sa paymonggo di manual"** ← SOLVED! 🎉
