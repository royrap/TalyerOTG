-- ====================================================================
-- JOB COMPLETION REAL-TIME NOTIFICATION TRIGGER
-- ====================================================================
-- Purpose: Automatically notify customer when mechanic completes job
-- Triggers customer popup: "Service completed! Rate your mechanic?"
-- Date: October 7, 2025
-- ====================================================================

-- 1. Create notifications table if it doesn't exist
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  notification_type TEXT NOT NULL
    CHECK (notification_type IN (
      'job_completed', 'invoice_sent', 'payment_received',
      'request_accepted', 'request_rejected', 'mechanic_arrived',
      'invoice_disputed', 'cash_verification_needed'
    )),
  message TEXT NOT NULL,
  title TEXT,
  related_id UUID,  -- service_request_id, invoice_id, etc.
  related_table TEXT,  -- 'service_requests', 'invoices', etc.
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  expires_at TIMESTAMP DEFAULT (NOW() + INTERVAL '7 days')
);

-- 2. Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;

-- 3. Enable RLS on notifications
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 4. RLS policies for notifications
DROP POLICY IF EXISTS "Users can view their own notifications" ON notifications;
CREATE POLICY "Users can view their own notifications"
ON notifications FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "System can insert notifications" ON notifications;
CREATE POLICY "System can insert notifications"
ON notifications FOR INSERT
WITH CHECK (TRUE);

DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;
CREATE POLICY "Users can update their own notifications"
ON notifications FOR UPDATE
USING (auth.uid() = user_id);

-- 5. Function to send notification
CREATE OR REPLACE FUNCTION send_notification(
  user_id_param UUID,
  type_param TEXT,
  message_param TEXT,
  title_param TEXT DEFAULT NULL,
  related_id_param UUID DEFAULT NULL,
  related_table_param TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  notification_id UUID;
BEGIN
  INSERT INTO notifications (
    user_id,
    notification_type,
    message,
    title,
    related_id,
    related_table,
    created_at
  ) VALUES (
    user_id_param,
    type_param,
    message_param,
    title_param,
    related_id_param,
    related_table_param,
    NOW()
  )
  RETURNING id INTO notification_id;
  
  RETURN notification_id;
END;
$$ LANGUAGE plpgsql;

-- 6. Main trigger function for job completion
CREATE OR REPLACE FUNCTION notify_job_completion()
RETURNS TRIGGER AS $$
DECLARE
  customer_name TEXT;
  mechanic_name TEXT;
  service_name TEXT;
BEGIN
  -- Only trigger when status changes to 'completed'
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    
    -- Get customer name
    SELECT (first_name || ' ' || last_name) INTO customer_name
    FROM user_profiles
    WHERE id = NEW.customer_id;
    
    -- Get mechanic name
    SELECT (first_name || ' ' || last_name) INTO mechanic_name
    FROM user_profiles
    WHERE id = NEW.provider_id;
    
    -- Get service description
    service_name := COALESCE(NEW.service_type, 'service');
    
    -- 1. Send notification to CUSTOMER
    INSERT INTO notifications (
      user_id,
      notification_type,
      title,
      message,
      related_id,
      related_table,
      created_at
    ) VALUES (
      NEW.customer_id,
      'job_completed',
      '🎉 Service Completed!',
      'Your ' || service_name || ' service has been completed by ' || COALESCE(mechanic_name, 'your mechanic') || '. Would you like to rate your experience?',
      NEW.id,
      'service_requests',
      NOW()
    );
    
    -- 2. Log completion in audit logs
    INSERT INTO admin_activity_logs (
      action_type,
      action_description,
      user_id,
      affected_table,
      affected_record_id,
      metadata,
      created_at
    ) VALUES (
      'job_completed',
      'Service request completed: ' || NEW.id,
      NEW.provider_id,
      'service_requests',
      NEW.id,
      jsonb_build_object(
        'customer_id', NEW.customer_id,
        'mechanic_id', NEW.provider_id,
        'service_type', NEW.service_type,
        'completed_at', NEW.completed_at,
        'qr_scanned', (NEW.qr_scanned_at IS NOT NULL)
      ),
      NOW()
    );
    
    -- 3. Update mechanic availability (mark as available again)
    UPDATE mechanic_availability_status
    SET 
      availability_status = 'available',
      current_job_id = NULL,
      updated_at = NOW()
    WHERE mechanic_id = NEW.provider_id;
    
    -- 4. If part of a shop, update shop stats
    IF NEW.shop_id IS NOT NULL THEN
      UPDATE shops
      SET 
        total_completed_jobs = COALESCE(total_completed_jobs, 0) + 1,
        last_job_completed_at = NOW(),
        updated_at = NOW()
      WHERE id = NEW.shop_id;
    END IF;
    
    -- 5. Send notification to SHOP OWNER (if applicable)
    IF NEW.shop_id IS NOT NULL THEN
      INSERT INTO notifications (
        user_id,
        notification_type,
        title,
        message,
        related_id,
        related_table,
        created_at
      )
      SELECT 
        s.owner_id,
        'job_completed',
        '✅ Job Completed',
        mechanic_name || ' completed a job for ' || customer_name,
        NEW.id,
        'service_requests',
        NOW()
      FROM shops s
      WHERE s.id = NEW.shop_id AND s.owner_id IS NOT NULL;
    END IF;
    
    RAISE NOTICE '✅ Job completion notifications sent for request %', NEW.id;
    
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 7. Create trigger on service_requests table
DROP TRIGGER IF EXISTS trigger_job_completion ON service_requests;
CREATE TRIGGER trigger_job_completion
AFTER UPDATE ON service_requests
FOR EACH ROW
EXECUTE FUNCTION notify_job_completion();

-- 8. Function to mark notification as read
CREATE OR REPLACE FUNCTION mark_notification_read(notification_id_param UUID)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE notifications
  SET 
    is_read = TRUE,
    read_at = NOW()
  WHERE id = notification_id_param
    AND user_id = auth.uid();
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- 9. Function to get unread notification count
CREATE OR REPLACE FUNCTION get_unread_notification_count(user_id_param UUID)
RETURNS INTEGER AS $$
DECLARE
  unread_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO unread_count
  FROM notifications
  WHERE user_id = user_id_param
    AND is_read = FALSE
    AND (expires_at IS NULL OR expires_at > NOW());
  
  RETURN unread_count;
END;
$$ LANGUAGE plpgsql;

-- 10. Function to cleanup old notifications
CREATE OR REPLACE FUNCTION cleanup_old_notifications()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM notifications
  WHERE created_at < NOW() - INTERVAL '30 days'
    OR (expires_at IS NOT NULL AND expires_at < NOW());
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- 11. Create scheduled job to cleanup old notifications (optional)
-- Requires pg_cron extension
/*
SELECT cron.schedule(
  'cleanup-old-notifications',
  '0 2 * * *',  -- Run at 2 AM daily
  $$SELECT cleanup_old_notifications()$$
);
*/

-- ====================================================================
-- TESTING SCRIPTS
-- ====================================================================

-- Test 1: Check if notification table exists
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_name = 'notifications'
ORDER BY ordinal_position;

-- Test 2: Verify trigger exists
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'trigger_job_completion';

-- Test 3: Test notification sending (replace UUIDs with real values)
/*
SELECT send_notification(
  'CUSTOMER_USER_ID'::UUID,
  'job_completed',
  'Test notification: Your service has been completed!',
  'Service Completed',
  'SERVICE_REQUEST_ID'::UUID,
  'service_requests'
);
*/

-- Test 4: Get unread notifications for a user
/*
SELECT * FROM notifications
WHERE user_id = 'YOUR_USER_ID'::UUID
  AND is_read = FALSE
ORDER BY created_at DESC;
*/

-- Test 5: Manually complete a job to test trigger
/*
UPDATE service_requests
SET status = 'completed'
WHERE id = 'YOUR_REQUEST_ID'::UUID;

-- Check if notification was created
SELECT * FROM notifications
WHERE related_id = 'YOUR_REQUEST_ID'::UUID
  AND notification_type = 'job_completed'
ORDER BY created_at DESC;
*/

-- ====================================================================
-- ROLLBACK (if needed)
-- ====================================================================

/*
-- Uncomment to rollback

DROP TRIGGER IF EXISTS trigger_job_completion ON service_requests;
DROP FUNCTION IF EXISTS notify_job_completion();
DROP FUNCTION IF EXISTS send_notification(UUID, TEXT, TEXT, TEXT, UUID, TEXT);
DROP FUNCTION IF EXISTS mark_notification_read(UUID);
DROP FUNCTION IF EXISTS get_unread_notification_count(UUID);
DROP FUNCTION IF EXISTS cleanup_old_notifications();
DROP TABLE IF EXISTS notifications CASCADE;
*/

-- ====================================================================
-- COMPLETE ✅
-- ====================================================================

SELECT '✅ Job completion notification system installed successfully!' as status;
SELECT 'Total notifications: ' || COUNT(*)::TEXT as notification_count
FROM notifications;
