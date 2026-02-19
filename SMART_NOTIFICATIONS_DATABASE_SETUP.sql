-- Smart Notification System Database Setup
-- This creates the complete notification infrastructure

-- 1. Create notification_templates table for smart messaging
CREATE TABLE IF NOT EXISTS notification_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category TEXT NOT NULL CHECK (category IN (
        'service_update', 'progress_photo', 'eta_update', 
        'payment_required', 'mechanic_arrival', 'service_complete',
        'emergency', 'promotional'
    )),
    priority TEXT NOT NULL CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    title_template TEXT NOT NULL,
    message_template TEXT NOT NULL,
    action_data JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Insert default notification templates
INSERT INTO notification_templates (category, priority, title_template, message_template, action_data) VALUES 
-- Service Updates
('service_update', 'normal', 'Service Request Update', 'Your {{service_type}} service is now {{status}}', '{"action": "view_service"}'),
('service_update', 'high', 'Service Status Changed', 'Your {{service_type}} service has been {{status}}. Tap for details.', '{"action": "view_service"}'),

-- Progress Photos
('progress_photo', 'normal', 'Progress Update 📸', 'Your mechanic shared a new photo for {{phase}}', '{"action": "view_photo"}'),
('progress_photo', 'high', 'Work Progress 📸', '{{mechanic_name}} uploaded a photo showing {{phase}} progress', '{"action": "view_photo"}'),

-- ETA Updates
('eta_update', 'normal', 'Arrival Update 🕐', 'Your mechanic will arrive in {{eta_minutes}} minutes', '{"action": "track_mechanic"}'),
('eta_update', 'high', 'Almost There! 🚗', '{{mechanic_name}} is {{eta_minutes}} minutes away from your location', '{"action": "track_mechanic"}'),

-- Payment Required
('payment_required', 'high', 'Payment Required 💳', 'Your {{service_type}} service fee of ₱{{amount}} is ready for payment', '{"action": "pay_now"}'),
('payment_required', 'urgent', 'Complete Payment 💳', 'Please complete payment of ₱{{amount}} to finalize your service', '{"action": "pay_now"}'),

-- Mechanic Arrival
('mechanic_arrival', 'high', 'Mechanic Arrived 🚗', '{{mechanic_name}} has arrived at your location!', '{"action": "call_mechanic"}'),
('mechanic_arrival', 'urgent', 'Your Mechanic is Here! 🎉', '{{mechanic_name}} is ready to start working on your {{vehicle_type}}', '{"action": "call_mechanic"}'),

-- Service Complete
('service_complete', 'high', 'Service Complete ✅', 'Your {{service_type}} service has been completed successfully!', '{"action": "rate_service"}'),
('service_complete', 'normal', 'All Done! 🎊', '{{mechanic_name}} has finished your {{service_type}}. Please rate your experience.', '{"action": "rate_service"}'),

-- Emergency
('emergency', 'urgent', 'Emergency Alert 🚨', '{{message}}', '{"action": "emergency_response"}'),

-- Promotional  
('promotional', 'low', 'Special Offer 🎁', '{{offer_title}} - Save up to {{discount}}% on your next service!', '{"action": "view_offer"}');

-- 2. Create user_notification_preferences table
CREATE TABLE IF NOT EXISTS user_notification_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    user_type TEXT NOT NULL CHECK (user_type IN ('customer', 'mechanic', 'talyer_owner')),
    category TEXT NOT NULL CHECK (category IN (
        'service_update', 'progress_photo', 'eta_update', 
        'payment_required', 'mechanic_arrival', 'service_complete',
        'emergency', 'promotional'
    )),
    is_enabled BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(user_id, category)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_notification_preferences_user 
ON user_notification_preferences(user_id, user_type);

-- 3. Create notification_delivery_log table for analytics
CREATE TABLE IF NOT EXISTS notification_delivery_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID REFERENCES notifications(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    category TEXT NOT NULL,
    priority TEXT NOT NULL,
    delivery_status TEXT NOT NULL CHECK (delivery_status IN (
        'queued', 'sent', 'delivered', 'failed', 'filtered', 'rate_limited'
    )),
    delivery_method TEXT CHECK (delivery_method IN ('push', 'local', 'email', 'sms')),
    delivered_at TIMESTAMPTZ,
    opened_at TIMESTAMPTZ,
    action_taken TEXT,
    failure_reason TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for analytics
CREATE INDEX IF NOT EXISTS idx_notification_delivery_log_user_date 
ON notification_delivery_log(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notification_delivery_log_category_date 
ON notification_delivery_log(category, created_at DESC);

-- 4. Create do_not_disturb_settings table
CREATE TABLE IF NOT EXISTS do_not_disturb_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES user_profiles(id) ON DELETE CASCADE,
    is_enabled BOOLEAN DEFAULT FALSE,
    start_time TIME DEFAULT '22:00:00',
    end_time TIME DEFAULT '08:00:00',
    allow_urgent BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 5. Function to get user notification preferences
CREATE OR REPLACE FUNCTION get_user_notification_preferences(target_user_id UUID)
RETURNS TABLE (
    category TEXT,
    is_enabled BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        unnest(ARRAY['service_update', 'progress_photo', 'eta_update', 
                     'payment_required', 'mechanic_arrival', 'service_complete',
                     'emergency', 'promotional']) as category,
        COALESCE(unp.is_enabled, TRUE) as is_enabled
    FROM (SELECT unnest(ARRAY['service_update', 'progress_photo', 'eta_update', 
                               'payment_required', 'mechanic_arrival', 'service_complete',
                               'emergency', 'promotional'])) AS categories(category)
    LEFT JOIN user_notification_preferences unp 
        ON unp.user_id = target_user_id 
        AND unp.category = categories.category;
END;
$$ LANGUAGE plpgsql;

-- 6. Function to check if user is in do not disturb mode
CREATE OR REPLACE FUNCTION is_user_in_dnd_mode(target_user_id UUID, check_priority TEXT DEFAULT 'normal')
RETURNS BOOLEAN AS $$
DECLARE
    dnd_settings RECORD;
    current_time_value TIME;
    in_dnd_period BOOLEAN;
BEGIN
    -- Get DND settings
    SELECT * INTO dnd_settings 
    FROM do_not_disturb_settings 
    WHERE user_id = target_user_id;
    
    -- If no settings or DND disabled, return false
    IF dnd_settings IS NULL OR NOT dnd_settings.is_enabled THEN
        RETURN FALSE;
    END IF;
    
    -- Allow urgent notifications if configured
    IF check_priority = 'urgent' AND dnd_settings.allow_urgent THEN
        RETURN FALSE;
    END IF;
    
    -- Check if current time is within DND period
    current_time_value := CURRENT_TIME;
    
    -- Handle overnight DND periods (e.g., 22:00 to 08:00)
    IF dnd_settings.start_time > dnd_settings.end_time THEN
        in_dnd_period := current_time_value >= dnd_settings.start_time 
                        OR current_time_value < dnd_settings.end_time;
    ELSE
        in_dnd_period := current_time_value >= dnd_settings.start_time 
                        AND current_time_value < dnd_settings.end_time;
    END IF;
    
    RETURN in_dnd_period;
END;
$$ LANGUAGE plpgsql;

-- 7. Function to get notification rate limiting info
CREATE OR REPLACE FUNCTION check_notification_rate_limit(
    target_user_id UUID,
    check_category TEXT,
    max_per_hour INTEGER DEFAULT 10,
    min_interval_minutes INTEGER DEFAULT 5
)
RETURNS TABLE (
    is_within_limit BOOLEAN,
    notifications_sent_last_hour INTEGER,
    minutes_since_last_similar INTEGER
) AS $$
DECLARE
    notifications_count INTEGER;
    last_similar_time TIMESTAMPTZ;
    minutes_diff INTEGER;
BEGIN
    -- Count notifications in the last hour
    SELECT COUNT(*) INTO notifications_count
    FROM notification_delivery_log
    WHERE user_id = target_user_id
      AND delivery_status = 'sent'
      AND created_at > CURRENT_TIMESTAMP - INTERVAL '1 hour';
    
    -- Get last notification of same category
    SELECT MAX(created_at) INTO last_similar_time
    FROM notification_delivery_log
    WHERE user_id = target_user_id
      AND category = check_category
      AND delivery_status = 'sent';
    
    -- Calculate minutes since last similar notification
    IF last_similar_time IS NOT NULL THEN
        minutes_diff := EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - last_similar_time)) / 60;
    ELSE
        minutes_diff := 999; -- Large number if no previous notification
    END IF;
    
    RETURN QUERY SELECT 
        (notifications_count < max_per_hour AND minutes_diff >= min_interval_minutes) as is_within_limit,
        notifications_count as notifications_sent_last_hour,
        minutes_diff as minutes_since_last_similar;
END;
$$ LANGUAGE plpgsql;

-- 8. Enhanced function to send smart notification
CREATE OR REPLACE FUNCTION send_smart_notification(
    target_user_id UUID,
    target_user_type TEXT,
    notification_category TEXT,
    template_variables JSONB DEFAULT '{}',
    override_priority TEXT DEFAULT NULL,
    service_request_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    template_record RECORD;
    user_preferences RECORD;
    rate_limit_info RECORD;
    notification_id UUID;
    final_title TEXT;
    final_message TEXT;
    final_priority TEXT;
    should_send BOOLEAN := TRUE;
    delivery_status TEXT := 'sent';
    failure_reason TEXT;
BEGIN
    -- Get notification template
    SELECT * INTO template_record
    FROM notification_templates
    WHERE category = notification_category
      AND is_active = TRUE
    ORDER BY 
        CASE WHEN override_priority IS NOT NULL THEN 
            CASE WHEN priority = override_priority THEN 1 ELSE 2 END
        ELSE 1 END
    LIMIT 1;
    
    IF template_record IS NULL THEN
        RAISE EXCEPTION 'No active template found for category: %', notification_category;
    END IF;
    
    final_priority := COALESCE(override_priority, template_record.priority);
    
    -- Check user preferences
    SELECT is_enabled INTO user_preferences
    FROM get_user_notification_preferences(target_user_id)
    WHERE category = notification_category;
    
    IF NOT COALESCE(user_preferences.is_enabled, TRUE) THEN
        should_send := FALSE;
        delivery_status := 'filtered';
        failure_reason := 'Category disabled by user';
    END IF;
    
    -- Check do not disturb
    IF should_send AND is_user_in_dnd_mode(target_user_id, final_priority) THEN
        should_send := FALSE;
        delivery_status := 'filtered';
        failure_reason := 'Do not disturb active';
    END IF;
    
    -- Check rate limiting
    IF should_send THEN
        SELECT * INTO rate_limit_info
        FROM check_notification_rate_limit(target_user_id, notification_category);
        
        IF NOT rate_limit_info.is_within_limit THEN
            should_send := FALSE;
            delivery_status := 'rate_limited';
            failure_reason := 'Rate limit exceeded';
        END IF;
    END IF;
    
    -- Process template variables
    final_title := template_record.title_template;
    final_message := template_record.message_template;
    
    -- Replace template variables (simplified - in practice you'd want a more robust system)
    IF template_variables ? 'service_type' THEN
        final_title := REPLACE(final_title, '{{service_type}}', template_variables->>'service_type');
        final_message := REPLACE(final_message, '{{service_type}}', template_variables->>'service_type');
    END IF;
    
    IF template_variables ? 'status' THEN
        final_message := REPLACE(final_message, '{{status}}', template_variables->>'status');
    END IF;
    
    IF template_variables ? 'mechanic_name' THEN
        final_message := REPLACE(final_message, '{{mechanic_name}}', template_variables->>'mechanic_name');
    END IF;
    
    IF template_variables ? 'eta_minutes' THEN
        final_message := REPLACE(final_message, '{{eta_minutes}}', template_variables->>'eta_minutes');
    END IF;
    
    IF template_variables ? 'amount' THEN
        final_message := REPLACE(final_message, '{{amount}}', template_variables->>'amount');
    END IF;
    
    -- Create notification record
    INSERT INTO notifications (
        user_id,
        title,
        body,
        type,
        data
    ) VALUES (
        target_user_id,
        final_title,
        final_message,
        notification_category,
        template_record.action_data || COALESCE(template_variables, '{}')
    ) RETURNING id INTO notification_id;
    
    -- Log delivery attempt
    INSERT INTO notification_delivery_log (
        notification_id,
        user_id,
        category,
        priority,
        delivery_status,
        delivery_method,
        delivered_at,
        failure_reason,
        metadata
    ) VALUES (
        notification_id,
        target_user_id,
        notification_category,
        final_priority,
        delivery_status,
        'push',
        CASE WHEN should_send THEN CURRENT_TIMESTAMP ELSE NULL END,
        failure_reason,
        jsonb_build_object(
            'template_id', template_record.id,
            'should_send', should_send,
            'template_variables', template_variables
        )
    );
    
    RETURN notification_id;
END;
$$ LANGUAGE plpgsql;

-- 9. Function to update notification preferences
CREATE OR REPLACE FUNCTION update_notification_preference(
    target_user_id UUID,
    target_user_type TEXT,
    preference_category TEXT,
    is_enabled BOOLEAN
)
RETURNS BOOLEAN AS $$
BEGIN
    INSERT INTO user_notification_preferences (
        user_id,
        user_type,
        category,
        is_enabled
    ) VALUES (
        target_user_id,
        target_user_type,
        preference_category,
        is_enabled
    )
    ON CONFLICT (user_id, category) DO UPDATE SET
        is_enabled = EXCLUDED.is_enabled,
        updated_at = CURRENT_TIMESTAMP;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 10. Function to update DND settings
CREATE OR REPLACE FUNCTION update_dnd_settings(
    target_user_id UUID,
    dnd_enabled BOOLEAN,
    dnd_start_time TIME DEFAULT NULL,
    dnd_end_time TIME DEFAULT NULL,
    allow_urgent_notifications BOOLEAN DEFAULT TRUE
)
RETURNS BOOLEAN AS $$
BEGIN
    INSERT INTO do_not_disturb_settings (
        user_id,
        is_enabled,
        start_time,
        end_time,
        allow_urgent
    ) VALUES (
        target_user_id,
        dnd_enabled,
        COALESCE(dnd_start_time, '22:00:00'),
        COALESCE(dnd_end_time, '08:00:00'),
        allow_urgent_notifications
    )
    ON CONFLICT (user_id) DO UPDATE SET
        is_enabled = EXCLUDED.is_enabled,
        start_time = COALESCE(EXCLUDED.start_time, do_not_disturb_settings.start_time),
        end_time = COALESCE(EXCLUDED.end_time, do_not_disturb_settings.end_time),
        allow_urgent = EXCLUDED.allow_urgent,
        updated_at = CURRENT_TIMESTAMP;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 11. Function to get notification analytics
CREATE OR REPLACE FUNCTION get_notification_analytics(
    target_user_id UUID DEFAULT NULL,
    date_from TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP - INTERVAL '30 days',
    date_to TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
)
RETURNS TABLE (
    category TEXT,
    total_sent INTEGER,
    total_delivered INTEGER,
    total_opened INTEGER,
    delivery_rate NUMERIC,
    open_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ndl.category,
        COUNT(*) FILTER (WHERE ndl.delivery_status = 'sent')::INTEGER as total_sent,
        COUNT(*) FILTER (WHERE ndl.delivery_status = 'delivered')::INTEGER as total_delivered,
        COUNT(*) FILTER (WHERE ndl.opened_at IS NOT NULL)::INTEGER as total_opened,
        ROUND(
            COALESCE(
                COUNT(*) FILTER (WHERE ndl.delivery_status = 'delivered')::NUMERIC / 
                NULLIF(COUNT(*) FILTER (WHERE ndl.delivery_status = 'sent')::NUMERIC, 0) * 100, 
                0
            ), 2
        ) as delivery_rate,
        ROUND(
            COALESCE(
                COUNT(*) FILTER (WHERE ndl.opened_at IS NOT NULL)::NUMERIC / 
                NULLIF(COUNT(*) FILTER (WHERE ndl.delivery_status = 'delivered')::NUMERIC, 0) * 100, 
                0
            ), 2
        ) as open_rate
    FROM notification_delivery_log ndl
    WHERE (target_user_id IS NULL OR ndl.user_id = target_user_id)
      AND ndl.created_at BETWEEN date_from AND date_to
    GROUP BY ndl.category
    ORDER BY total_sent DESC;
END;
$$ LANGUAGE plpgsql;

-- 12. Enable RLS for new tables
ALTER TABLE notification_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_delivery_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE do_not_disturb_settings ENABLE ROW LEVEL SECURITY;

-- 13. Create RLS policies
-- Templates are readable by all authenticated users
CREATE POLICY "Templates are readable by authenticated users" 
ON notification_templates FOR SELECT 
USING (true);

-- Users can manage their own preferences
CREATE POLICY "Users can manage their own notification preferences" 
ON user_notification_preferences FOR ALL 
USING (user_id = (SELECT id FROM user_profiles WHERE id = auth.uid()))
WITH CHECK (user_id = (SELECT id FROM user_profiles WHERE id = auth.uid()));

-- Users can view their own delivery logs
CREATE POLICY "Users can view their own delivery logs" 
ON notification_delivery_log FOR SELECT 
USING (user_id = (SELECT id FROM user_profiles WHERE id = auth.uid()));

-- Users can manage their own DND settings
CREATE POLICY "Users can manage their own DND settings" 
ON do_not_disturb_settings FOR ALL 
USING (user_id = (SELECT id FROM user_profiles WHERE id = auth.uid()))
WITH CHECK (user_id = (SELECT id FROM user_profiles WHERE id = auth.uid()));

-- 14. Grant permissions
GRANT SELECT ON notification_templates TO authenticated;
GRANT ALL ON user_notification_preferences TO authenticated;
GRANT SELECT ON notification_delivery_log TO authenticated;
GRANT ALL ON do_not_disturb_settings TO authenticated;

GRANT EXECUTE ON FUNCTION get_user_notification_preferences(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION is_user_in_dnd_mode(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION check_notification_rate_limit(UUID, TEXT, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION send_smart_notification(UUID, TEXT, TEXT, JSONB, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION update_notification_preference(UUID, TEXT, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION update_dnd_settings(UUID, BOOLEAN, TIME, TIME, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION get_notification_analytics(UUID, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Smart Notification System setup completed successfully!';
    RAISE NOTICE '📊 Created tables: notification_templates, user_notification_preferences, notification_delivery_log, do_not_disturb_settings';
    RAISE NOTICE '🔧 Created functions: send_smart_notification, update_notification_preference, etc.';
    RAISE NOTICE '🎯 Smart filtering: DND mode, rate limiting, user preferences';
    RAISE NOTICE '📈 Analytics: Delivery tracking, open rates, performance metrics';
    RAISE NOTICE '🔒 RLS policies enabled for data security';
END $$;