    -- ADD MECHANIC FEATURE - DATABASE SETUP
    -- This script ensures all necessary columns and policies are in place

    -- =====================================================
    -- 1. ENSURE USER_PROFILES TABLE HAS ALL REQUIRED COLUMNS
    -- =====================================================

    -- Add columns if they don't exist
    DO $$ 
    BEGIN
        -- Password change requirement flag
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                    WHERE table_name='user_profiles' AND column_name='password_change_required') THEN
            ALTER TABLE user_profiles ADD COLUMN password_change_required BOOLEAN DEFAULT FALSE;
        END IF;

        -- First login completion flag
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                    WHERE table_name='user_profiles' AND column_name='first_login_completed') THEN
            ALTER TABLE user_profiles ADD COLUMN first_login_completed BOOLEAN DEFAULT FALSE;
        END IF;

        -- First login password changed flag
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                    WHERE table_name='user_profiles' AND column_name='first_login_password_changed') THEN
            ALTER TABLE user_profiles ADD COLUMN first_login_password_changed BOOLEAN DEFAULT FALSE;
        END IF;

        -- Can login flag (for email verification)
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                    WHERE table_name='user_profiles' AND column_name='can_login') THEN
            ALTER TABLE user_profiles ADD COLUMN can_login BOOLEAN DEFAULT FALSE;
        END IF;

        -- Requires email verification flag
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                    WHERE table_name='user_profiles' AND column_name='requires_email_verification') THEN
            ALTER TABLE user_profiles ADD COLUMN requires_email_verification BOOLEAN DEFAULT TRUE;
        END IF;

        -- Last password change timestamp
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                    WHERE table_name='user_profiles' AND column_name='last_password_change') THEN
            ALTER TABLE user_profiles ADD COLUMN last_password_change TIMESTAMP WITH TIME ZONE;
        END IF;

        -- Shop ID foreign key
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                    WHERE table_name='user_profiles' AND column_name='shop_id') THEN
            ALTER TABLE user_profiles ADD COLUMN shop_id UUID REFERENCES shops(id);
        END IF;
    END $$;

    -- =====================================================
    -- 2. CREATE STORAGE BUCKET FOR PROFILE IMAGES (IF NOT EXISTS)
    -- =====================================================

    -- This should be done via Supabase Dashboard:
    -- 1. Go to Storage > Create Bucket
    -- 2. Name: 'profile-images'
    -- 3. Public: Yes
    -- 4. File Size Limit: 5MB
    -- 5. Allowed MIME Types: image/jpeg, image/png, image/jpg

    -- =====================================================
    -- 3. STORAGE POLICIES FOR PROFILE IMAGES
    -- =====================================================

    -- Drop existing policies if they exist
    DROP POLICY IF EXISTS "Users can upload their own profile images" ON storage.objects;
    DROP POLICY IF EXISTS "Public can view profile images" ON storage.objects;
    DROP POLICY IF EXISTS "Users can update their own profile images" ON storage.objects;
    DROP POLICY IF EXISTS "Users can delete their own profile images" ON storage.objects;

    -- Policy: Allow authenticated users to upload their own profile images
    CREATE POLICY "Users can upload their own profile images"
    ON storage.objects
    FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'profile-images' AND
        (storage.foldername(name))[1] = 'profile_images'
    );

    -- Policy: Allow public read access to profile images
    CREATE POLICY "Public can view profile images"
    ON storage.objects
    FOR SELECT
    TO public
    USING (bucket_id = 'profile-images');

    -- Policy: Allow users to update their own profile images
    CREATE POLICY "Users can update their own profile images"
    ON storage.objects
    FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'profile-images' AND
        (storage.foldername(name))[1] = 'profile_images'
    );

    -- Policy: Allow users to delete their own profile images
    CREATE POLICY "Users can delete their own profile images"
    ON storage.objects
    FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'profile-images' AND
        (storage.foldername(name))[1] = 'profile_images'
    );

    -- =====================================================
    -- 4. USER_PROFILES RLS POLICIES
    -- =====================================================

    -- Drop existing policies if they exist
    DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
    DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
    DROP POLICY IF EXISTS "Talyer owners can view their mechanics" ON user_profiles;

    -- Policy: Users can read their own profile
    CREATE POLICY "Users can view their own profile"
    ON user_profiles
    FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

    -- Policy: Users can update their own profile
    CREATE POLICY "Users can update their own profile"
    ON user_profiles
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

    -- Policy: Talyer owners can view mechanics in their shop
    CREATE POLICY "Talyer owners can view their mechanics"
    ON user_profiles
    FOR SELECT
    TO authenticated
    USING (
        user_type = 'mechanic' AND
        shop_id IN (
            SELECT id FROM shops WHERE owner_id = auth.uid()
        )
    );

    -- =====================================================
    -- 5. TEMPORARY_PASSWORDS TABLE POLICIES
    -- =====================================================

    -- Drop existing policies if they exist
    DROP POLICY IF EXISTS "Users can view their own temporary passwords" ON temporary_passwords;
    DROP POLICY IF EXISTS "Admins can create temporary passwords" ON temporary_passwords;
    DROP POLICY IF EXISTS "Users can update their own temporary passwords" ON temporary_passwords;

    -- Policy: Users can view their own temporary passwords
    CREATE POLICY "Users can view their own temporary passwords"
    ON temporary_passwords
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid() OR email = auth.email());

    -- Policy: Admins and shop owners can create temporary passwords
    CREATE POLICY "Admins can create temporary passwords"
    ON temporary_passwords
    FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() IN (
            SELECT id FROM user_profiles 
            WHERE user_type IN ('admin', 'super_admin', 'talyer_owner')
        )
    );

    -- Policy: Users can update their own temporary passwords (mark as used)
    CREATE POLICY "Users can update their own temporary passwords"
    ON temporary_passwords
    FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- =====================================================
-- 6. EMAIL_NOTIFICATIONS TABLE POLICIES
-- =====================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their emails" ON email_notifications;
DROP POLICY IF EXISTS "Admins can send emails" ON email_notifications;

-- Policy: Users can view emails sent to them
CREATE POLICY "Users can view their emails"
ON email_notifications
FOR SELECT
TO authenticated
USING (recipient_user_id = auth.uid() OR sender_user_id = auth.uid());

-- Policy: Admins and shop owners can send emails
CREATE POLICY "Admins can send emails"
ON email_notifications
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() IN (
        SELECT id FROM user_profiles 
        WHERE user_type IN ('admin', 'super_admin', 'talyer_owner')
    )
);

-- =====================================================
-- 7. ADMIN_ACTIVITY_LOGS TABLE POLICIES
-- =====================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Admins can view activity logs" ON admin_activity_logs;
DROP POLICY IF EXISTS "Admins can create activity logs" ON admin_activity_logs;

-- Policy: Admins can view all logs
CREATE POLICY "Admins can view activity logs"
ON admin_activity_logs
FOR SELECT
TO authenticated
USING (
    auth.uid() IN (
        SELECT id FROM user_profiles 
        WHERE user_type IN ('admin', 'super_admin', 'talyer_owner')
    )
);

-- Policy: Admins can create logs
CREATE POLICY "Admins can create activity logs"
ON admin_activity_logs
FOR INSERT
TO authenticated
WITH CHECK (admin_id = auth.uid());

-- =====================================================
-- 8. ACCOUNT_SECURITY_LOGS TABLE POLICIES
-- =====================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their security logs" ON account_security_logs;
DROP POLICY IF EXISTS "System can create security logs" ON account_security_logs;

-- Policy: Users can view their own security logs
CREATE POLICY "Users can view their security logs"
ON account_security_logs
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Policy: System can create security logs
CREATE POLICY "System can create security logs"
ON account_security_logs
FOR INSERT
TO authenticated
WITH CHECK (true);

-- =====================================================
-- 9. EMAIL_VERIFICATION_TOKENS TABLE POLICIES
-- =====================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own tokens" ON email_verification_tokens;
DROP POLICY IF EXISTS "System can create verification tokens" ON email_verification_tokens;
DROP POLICY IF EXISTS "Users can update their own tokens" ON email_verification_tokens;

-- Policy: Users can view their own tokens
CREATE POLICY "Users can view their own tokens"
ON email_verification_tokens
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Policy: System can create tokens
CREATE POLICY "System can create verification tokens"
ON email_verification_tokens
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy: Users can update their own tokens
CREATE POLICY "Users can update their own tokens"
ON email_verification_tokens
FOR UPDATE
TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

    -- =====================================================
    -- 10. HELPER FUNCTION - CHECK IF MECHANIC BELONGS TO SHOP
    -- =====================================================

    CREATE OR REPLACE FUNCTION is_mechanic_in_shop(mechanic_user_id UUID, shop_owner_id UUID)
    RETURNS BOOLEAN AS $$
    BEGIN
        RETURN EXISTS (
            SELECT 1 FROM shop_mechanics sm
            JOIN shops s ON sm.shop_id = s.id
            WHERE sm.mechanic_id = mechanic_user_id
            AND s.owner_id = shop_owner_id
        );
    END;
    $$ LANGUAGE plpgsql SECURITY DEFINER;

    -- =====================================================
    -- 11. TRIGGER - AUTOMATICALLY SET CAN_LOGIN AFTER EMAIL VERIFICATION
    -- =====================================================

    CREATE OR REPLACE FUNCTION auto_enable_login_on_verification()
    RETURNS TRIGGER AS $$
    BEGIN
        -- When a verification token is used, enable login
        IF NEW.used_at IS NOT NULL AND OLD.used_at IS NULL THEN
            UPDATE user_profiles
            SET can_login = TRUE,
                requires_email_verification = FALSE
            WHERE id = NEW.user_id;
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql SECURITY DEFINER;

    -- Drop trigger if exists
    DROP TRIGGER IF EXISTS trigger_enable_login_on_verification ON email_verification_tokens;

    -- Create trigger
    CREATE TRIGGER trigger_enable_login_on_verification
    AFTER UPDATE ON email_verification_tokens
    FOR EACH ROW
    EXECUTE FUNCTION auto_enable_login_on_verification();

    -- =====================================================
    -- 12. INDEXES FOR PERFORMANCE
    -- =====================================================

    -- Index on user_profiles for mechanic queries
    CREATE INDEX IF NOT EXISTS idx_user_profiles_shop_id ON user_profiles(shop_id);
    CREATE INDEX IF NOT EXISTS idx_user_profiles_user_type ON user_profiles(user_type);
    CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON user_profiles(email);

    -- Index on temporary_passwords
    CREATE INDEX IF NOT EXISTS idx_temporary_passwords_user_id ON temporary_passwords(user_id);
    CREATE INDEX IF NOT EXISTS idx_temporary_passwords_email ON temporary_passwords(email);
    CREATE INDEX IF NOT EXISTS idx_temporary_passwords_active ON temporary_passwords(is_active);

    -- Index on email_verification_tokens
    CREATE INDEX IF NOT EXISTS idx_email_verification_tokens_user_id ON email_verification_tokens(user_id);
    CREATE INDEX IF NOT EXISTS idx_email_verification_tokens_token ON email_verification_tokens(token);

    -- =====================================================
    -- 13. GRANT PERMISSIONS
    -- =====================================================

    -- Grant necessary permissions to authenticated users
    GRANT SELECT, INSERT, UPDATE ON user_profiles TO authenticated;
    GRANT SELECT, INSERT, UPDATE ON temporary_passwords TO authenticated;
    GRANT SELECT, INSERT ON email_notifications TO authenticated;
    GRANT SELECT, INSERT ON admin_activity_logs TO authenticated;
    GRANT SELECT, INSERT ON account_security_logs TO authenticated;
    GRANT SELECT, INSERT, UPDATE ON email_verification_tokens TO authenticated;

    -- =====================================================
    -- VERIFICATION QUERIES
    -- =====================================================

    -- Check if all required columns exist
    SELECT 
        column_name, 
        data_type, 
        column_default
    FROM information_schema.columns 
    WHERE table_name = 'user_profiles' 
    AND column_name IN (
        'password_change_required',
        'first_login_completed',
        'first_login_password_changed',
        'can_login',
        'requires_email_verification',
        'last_password_change',
        'shop_id'
    )
    ORDER BY column_name;

    -- Check RLS policies on user_profiles
    SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
    FROM pg_policies 
    WHERE tablename IN ('user_profiles', 'temporary_passwords', 'email_notifications', 
                        'admin_activity_logs', 'account_security_logs', 'email_verification_tokens')
    ORDER BY tablename, policyname;

    COMMENT ON COLUMN user_profiles.password_change_required IS 'Flag to force password change on next login';
    COMMENT ON COLUMN user_profiles.first_login_completed IS 'Flag indicating if user has completed their first login';
    COMMENT ON COLUMN user_profiles.first_login_password_changed IS 'Flag indicating if user changed password on first login';
    COMMENT ON COLUMN user_profiles.can_login IS 'Flag controlling login access (set after email verification)';
    COMMENT ON COLUMN user_profiles.requires_email_verification IS 'Flag indicating if email verification is required';

    -- =====================================================
    -- END OF SCRIPT
    -- =====================================================

    COMMENT ON SCHEMA public IS 'Add Mechanic Feature - Database setup complete';
