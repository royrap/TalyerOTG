-- Enhanced Payment Status Synchronization Fix
-- Addresses payment status inconsistencies between customer and mechanic interfaces

-- 1. Create function to sync payment status across all related tables
CREATE OR REPLACE FUNCTION sync_payment_status(
    p_service_request_id UUID,
    p_payment_status TEXT DEFAULT 'completed'
)
RETURNS jsonb AS $$
DECLARE
    v_request_exists boolean;
    v_invoice_id UUID;
    v_result jsonb;
BEGIN
    -- Check if service request exists
    SELECT EXISTS(SELECT 1 FROM service_requests WHERE id = p_service_request_id)
    INTO v_request_exists;
    
    IF NOT v_request_exists THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Service request not found'
        );
    END IF;
    
    -- Update service request payment status
    UPDATE service_requests 
    SET 
        payment_status = p_payment_status,
        updated_at = NOW()
    WHERE id = p_service_request_id;
    
    RAISE NOTICE '✅ Updated service_requests payment_status to % for request %', 
                 p_payment_status, p_service_request_id;
    
    -- Find and update related invoice
    SELECT id INTO v_invoice_id 
    FROM invoices 
    WHERE service_request_id = p_service_request_id
    ORDER BY created_at DESC 
    LIMIT 1;
    
    IF v_invoice_id IS NOT NULL THEN
        UPDATE invoices 
        SET 
            status = CASE 
                WHEN p_payment_status = 'completed' THEN 'paid'
                WHEN p_payment_status = 'pending' THEN 'pending'
                ELSE 'pending'
            END,
            updated_at = NOW()
        WHERE id = v_invoice_id;
        
        RAISE NOTICE '✅ Updated invoice % status to match payment_status %', 
                     v_invoice_id, p_payment_status;
    END IF;
    
    -- Update payment record if exists
    UPDATE payments 
    SET 
        status = p_payment_status,
        updated_at = NOW()
    WHERE invoice_id = v_invoice_id OR service_request_id = p_service_request_id;
    
    GET DIAGNOSTICS v_result = ROW_COUNT;
    RAISE NOTICE '✅ Updated % payment records', v_result;
    
    -- Trigger real-time notifications
    PERFORM pg_notify(
        'payment_status_sync', 
        jsonb_build_object(
            'service_request_id', p_service_request_id,
            'payment_status', p_payment_status,
            'invoice_id', v_invoice_id,
            'timestamp', NOW()
        )::text
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'service_request_id', p_service_request_id,
        'invoice_id', v_invoice_id,
        'payment_status', p_payment_status
    );
END;
$$ LANGUAGE plpgsql;

-- 2. Create trigger to auto-sync payment status changes
CREATE OR REPLACE FUNCTION trigger_sync_payment_status()
RETURNS TRIGGER AS $$
BEGIN
    -- When service_requests payment_status changes, sync related tables
    IF TG_TABLE_NAME = 'service_requests' AND OLD.payment_status != NEW.payment_status THEN
        RAISE NOTICE '🔄 Auto-syncing payment status change for request %: % → %',
                     NEW.id, OLD.payment_status, NEW.payment_status;
        
        PERFORM sync_payment_status(NEW.id, NEW.payment_status);
    END IF;
    
    -- When invoices status changes, sync service request
    IF TG_TABLE_NAME = 'invoices' AND OLD.status != NEW.status THEN
        UPDATE service_requests 
        SET 
            payment_status = CASE 
                WHEN NEW.status = 'paid' THEN 'completed'
                WHEN NEW.status = 'pending' THEN 'pending'
                ELSE NEW.status
            END,
            updated_at = NOW()
        WHERE id = NEW.service_request_id;
        
        RAISE NOTICE '🔄 Synced service_requests payment_status from invoice % status change',
                     NEW.id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Apply triggers
DROP TRIGGER IF EXISTS sync_service_request_payment_status ON service_requests;
CREATE TRIGGER sync_service_request_payment_status
    AFTER UPDATE OF payment_status ON service_requests
    FOR EACH ROW
    WHEN (OLD.payment_status IS DISTINCT FROM NEW.payment_status)
    EXECUTE FUNCTION trigger_sync_payment_status();

DROP TRIGGER IF EXISTS sync_invoice_payment_status ON invoices;
CREATE TRIGGER sync_invoice_payment_status
    AFTER UPDATE OF status ON invoices
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION trigger_sync_payment_status();

-- 4. Fix existing payment status inconsistencies
DO $$
DECLARE
    inconsistent_record RECORD;
    fixed_count INTEGER := 0;
BEGIN
    RAISE NOTICE '🔍 Checking for payment status inconsistencies...';
    
    -- Find service_requests with completed invoices but pending payment_status
    FOR inconsistent_record IN
        SELECT 
            sr.id as request_id,
            sr.payment_status as request_status,
            i.id as invoice_id,
            i.status as invoice_status
        FROM service_requests sr
        JOIN invoices i ON sr.id = i.service_request_id
        WHERE sr.payment_status != 'completed' 
        AND i.status = 'paid'
    LOOP
        -- Fix the inconsistency
        UPDATE service_requests 
        SET payment_status = 'completed'
        WHERE id = inconsistent_record.request_id;
        
        fixed_count := fixed_count + 1;
        RAISE NOTICE '🔧 Fixed inconsistency for request %: % → completed',
                     inconsistent_record.request_id, inconsistent_record.request_status;
    END LOOP;
    
    IF fixed_count > 0 THEN
        RAISE NOTICE '✅ Fixed % payment status inconsistencies', fixed_count;
    ELSE
        RAISE NOTICE '✅ No payment status inconsistencies found';
    END IF;
END;
$$;

-- 5. Test the sync function
DO $$
DECLARE
    test_request_id UUID;
    test_result jsonb;
BEGIN
    -- Find a test request
    SELECT id INTO test_request_id 
    FROM service_requests 
    WHERE payment_status IS NOT NULL
    LIMIT 1;
    
    IF test_request_id IS NOT NULL THEN
        RAISE NOTICE '🧪 Testing payment sync for request: %', test_request_id;
        
        SELECT sync_payment_status(test_request_id, 'completed') INTO test_result;
        
        RAISE NOTICE '📊 Test result: %', test_result;
    ELSE
        RAISE NOTICE 'ℹ️ No service requests found for testing';
    END IF;
END;
$$;

-- 6. Create monitoring view for payment status health
CREATE OR REPLACE VIEW payment_status_health AS
SELECT 
    'total_requests' as metric,
    COUNT(*)::text as value,
    'Total service requests with payment status' as description
FROM service_requests 
WHERE payment_status IS NOT NULL

UNION ALL

SELECT 
    'consistent_payments' as metric,
    COUNT(*)::text as value,
    'Requests with matching invoice payment status' as description
FROM service_requests sr
JOIN invoices i ON sr.id = i.service_request_id
WHERE (sr.payment_status = 'completed' AND i.status = 'paid') 
   OR (sr.payment_status = 'pending' AND i.status = 'pending')

UNION ALL

SELECT 
    'inconsistent_payments' as metric,
    COUNT(*)::text as value,
    'Requests with mismatched payment status (needs fixing)' as description
FROM service_requests sr
JOIN invoices i ON sr.id = i.service_request_id
WHERE NOT (
    (sr.payment_status = 'completed' AND i.status = 'paid') 
    OR (sr.payment_status = 'pending' AND i.status = 'pending')
);

-- 7. Show payment status health
SELECT * FROM payment_status_health;

RAISE NOTICE '🎯 Payment status synchronization enhancement complete!';
RAISE NOTICE '📊 Check payment_status_health view for ongoing monitoring';
RAISE NOTICE '🔄 Auto-sync triggers are now active for real-time consistency';