    -- =====================================================
    -- RESTORE THREE USERS TO DATABASE
    -- =====================================================
    -- This script restores 3 users back to the database:
    -- 1. Riza Pineda (paengpineda471@gmail.com) - talyer_owner
    -- 2. Mec Aid (mechanicroadaid@gmail.com) - talyer_owner  
    -- 3. Yuji Fuma (yujirofuma28@gmail.com) - mechanic

    -- =====================================================
    -- IMPORTANT: Run this in Supabase SQL Editor
    -- =====================================================

    BEGIN;

    -- =====================================================
    -- STEP 1: CREATE AUTH USERS FIRST
    -- =====================================================
    -- NOTE: These users will need to reset their passwords to login

    -- Create auth user for Riza Pineda
    INSERT INTO auth.users (
        id,
        instance_id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        recovery_sent_at,
        last_sign_in_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        confirmation_token,
        email_change,
        email_change_token_new,
        recovery_token
    )
    VALUES (
        '98543023-1960-4f70-b76a-d700ea70976c',
        '00000000-0000-0000-0000-000000000000',
        'authenticated',
        'authenticated',
        'paengpineda471@gmail.com',
        crypt('temporary_password_123', gen_salt('bf')), -- Temporary password, user needs to reset
        '2025-10-02 17:01:02.824552+00',
        NULL,
        NULL,
        '{"provider": "email", "providers": ["email"]}',
        '{"user_type": "talyer_owner", "shop_id": "5d963bdf-1879-4575-9375-df62b1ff3fe0"}',
        '2025-10-02 17:01:02.824552+00',
        '2025-10-17 23:24:49.25704+00',
        '',
        '',
        '',
        ''
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        updated_at = EXCLUDED.updated_at;

    -- Create auth user for Mec Aid
    INSERT INTO auth.users (
        id,
        instance_id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        recovery_sent_at,
        last_sign_in_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        confirmation_token,
        email_change,
        email_change_token_new,
        recovery_token
    )
    VALUES (
        '19a8b4ca-f5f8-4b85-9147-5128d9651e04',
        '00000000-0000-0000-0000-000000000000',
        'authenticated',
        'authenticated',
        'mechanicroadaid@gmail.com',
        crypt('temporary_password_123', gen_salt('bf')),
        '2025-08-24 13:56:46.517931+00',
        NULL,
        NULL,
        '{"provider": "email", "providers": ["email"]}',
        '{"user_type": "talyer_owner", "shop_id": "cedc2e63-7785-4d61-a8f1-9f4ed8d254da"}',
        '2025-08-24 13:56:46.517931+00',
        '2025-11-09 04:23:39.081117+00',
        '',
        '',
        '',
        ''
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        updated_at = EXCLUDED.updated_at;

    -- Create auth user for Yuji Fuma (Mechanic)
    INSERT INTO auth.users (
        id,
        instance_id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        recovery_sent_at,
        last_sign_in_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        confirmation_token,
        email_change,
        email_change_token_new,
        recovery_token
    )
    VALUES (
        'e4cbf14b-5729-45ef-a124-1f2e05acad8c',
        '00000000-0000-0000-0000-000000000000',
        'authenticated',
        'authenticated',
        'yujirofuma28@gmail.com',
        crypt('temporary_password_123', gen_salt('bf')),
        '2025-10-13 04:27:34.877766+00',
        NULL,
        NULL,
        '{"provider": "email", "providers": ["email"]}',
        '{"user_type": "mechanic", "shop_id": "cedc2e63-7785-4d61-a8f1-9f4ed8d254da", "talyer_owner_id": "19a8b4ca-f5f8-4b85-9147-5128d9651e04"}',
        '2025-10-13 04:27:34.877766+00',
        '2025-10-19 06:27:34.413166+00',
        '',
        '',
        '',
        ''
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        updated_at = EXCLUDED.updated_at;

    -- =====================================================
    -- STEP 2: CREATE SHOPS FIRST (required for user_profiles FK)
    -- =====================================================

    -- Create shop for Riza Pineda
    INSERT INTO public.shops (
        id,
        owner_id,
        shop_name,
        is_active,
        created_at,
        updated_at,
        operating_hours,
        current_status,
        shop_address,
        shop_phone,
        shop_email,
        shop_description,
        latitude,
        longitude,
        service_radius,
        rating,
        total_reviews,
        total_services,
        total_earnings,
        business_hours,
        emergency_contact,
        max_concurrent_jobs,
        current_job_count,
        contact_person
    )
    VALUES (
        '5d963bdf-1879-4575-9375-df62b1ff3fe0',
        '98543023-1960-4f70-b76a-d700ea70976c',
        'Riza Auto Repair Shop',
        true,
        '2025-10-02 17:01:02.824552+00',
        '2025-10-17 23:24:49.25704+00',
        '{}'::jsonb,
        'closed',
        'Baliwag, Bulacan',
        '09945547110',
        'paengpineda471@gmail.com',
        'Professional auto repair services',
        14.93220800,
        120.88070130,
        50.0,
        0.00,
        0,
        0,
        0.00,
        '{"friday": {"open": "08:00", "close": "20:00"}, "monday": {"open": "08:00", "close": "17:00"}, "sunday": {"open": "09:00", "close": "17:00"}, "tuesday": {"open": "08:00", "close": "17:00"}, "saturday": {"open": "09:00", "close": "17:00"}, "thursday": {"open": "08:00", "close": "17:00"}, "wednesday": {"open": "08:00", "close": "17:00"}}'::jsonb,
        '09945547110',
        10,
        0,
        'Riza Pineda'
    )
    ON CONFLICT (id) DO UPDATE SET
        shop_name = EXCLUDED.shop_name,
        updated_at = EXCLUDED.updated_at,
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude;

    -- Create shop for Mec Aid
    INSERT INTO public.shops (
        id,
        owner_id,
        shop_name,
        is_active,
        created_at,
        updated_at,
        operating_hours,
        current_status,
        shop_address,
        shop_phone,
        shop_email,
        shop_description,
        latitude,
        longitude,
        service_radius,
        rating,
        total_reviews,
        total_services,
        total_earnings,
        business_hours,
        emergency_contact,
        max_concurrent_jobs,
        current_job_count,
        contact_person
    )
    VALUES (
        'cedc2e63-7785-4d61-a8f1-9f4ed8d254da',
        '19a8b4ca-f5f8-4b85-9147-5128d9651e04',
        'MecAid Auto Services',
        true,
        '2025-08-24 13:56:46.517931+00',
        '2025-11-09 04:23:39.081117+00',
        '{}'::jsonb,
        'closed',
        'Baliwag, Bulacan',
        '09945547110',
        'mechanicroadaid@gmail.com',
        'Your trusted mechanic partner',
        14.95310170,
        120.89655510,
        50.0,
        0.00,
        0,
        0,
        0.00,
        '{"friday": {"open": "08:00", "close": "17:00"}, "monday": {"open": "08:00", "close": "17:00"}, "sunday": {"open": null, "close": null}, "tuesday": {"open": "08:00", "close": "18:00"}, "saturday": {"open": null, "close": null}, "thursday": {"open": "08:00", "close": "17:00"}, "wednesday": {"open": "08:00", "close": "17:00"}}'::jsonb,
        '09945547110',
        10,
        0,
        'Mec Aid'
    )
    ON CONFLICT (id) DO UPDATE SET
        shop_name = EXCLUDED.shop_name,
        updated_at = EXCLUDED.updated_at,
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude;

    -- =====================================================
    -- STEP 3: CREATE USER PROFILES
    -- =====================================================

    -- =====================================================
    -- 1. RESTORE USER: Riza Pineda (Talyer Owner)
    -- =====================================================

    -- Insert into user_profiles
    INSERT INTO public.user_profiles (
        id,
        first_name,
        last_name,
        email,
        phone_number,
        profile_image_url,
        status,
        user_type,
        created_at,
        updated_at,
        current_latitude,
        current_longitude,
        is_available,
        role,
        admin_permissions,
        last_login_at,
        login_count,
        email_verified_at,
        account_status,
        shop_id,
        first_login_completed,
        password_change_required,
        temp_email,
        email_change_token,
        email_change_expires_at,
        last_password_change,
        failed_login_attempts,
        account_locked_until,
        registration_completed,
        profile_completion_score,
        profile_image_required,
        first_login_password_changed,
        account_verification_status,
        verification_documents,
        business_permit_url,
        drivers_license_url,
        document_verification_status,
        document_verification_notes,
        verified_by,
        verified_at,
        can_login,
        requires_email_verification,
        shop_hours,
        settings,
        timezone,
        preferred_language,
        notification_preferences,
        rating,
        total_reviews
    ) VALUES (
        '98543023-1960-4f70-b76a-d700ea70976c',
        'Riza',
        'Pineda',
        'paengpineda471@gmail.com',
        '09945547110',
        NULL,
        'active',
        'talyer_owner',
        '2025-10-02 17:01:02.824552+00',
        '2025-10-17 23:24:49.25704+00',
        14.93220800,
        120.88070130,
        true,
        'customer',
        '[]'::jsonb,
        NULL,
        0,
        NULL,
        'active',
        '5d963bdf-1879-4575-9375-df62b1ff3fe0',
        false,
        false,
        NULL,
        NULL,
        NULL,
        NULL,
        0,
        NULL,
        false,
        0,
        true,
        false,
        'pending',
        '{}'::jsonb,
        NULL,
        NULL,
        'pending',
        NULL,
        NULL,
        NULL,
        false,
        true,
        '{"friday": {"isOpen": true, "openTime": "08:00", "closeTime": "20:00"}, "monday": {"isOpen": true, "openTime": "08:00", "closeTime": "17:00"}, "sunday": {"isOpen": true, "openTime": "09:00", "closeTime": "17:00"}, "tuesday": {"isOpen": true, "openTime": "08:00", "closeTime": "17:00"}, "saturday": {"isOpen": true, "openTime": "09:00", "closeTime": "17:00"}, "thursday": {"isOpen": true, "openTime": "08:00", "closeTime": "17:00"}, "wednesday": {"isOpen": true, "openTime": "08:00", "closeTime": "17:00"}}'::jsonb,
        '{}'::jsonb,
        'Asia/Manila',
        'en',
        '{"sms": false, "push": true, "email": true}'::jsonb,
        0.00,
        0
    )
    ON CONFLICT (id) DO UPDATE SET
        first_name = EXCLUDED.first_name,
        last_name = EXCLUDED.last_name,
        email = EXCLUDED.email,
        phone_number = EXCLUDED.phone_number,
        updated_at = EXCLUDED.updated_at,
        current_latitude = EXCLUDED.current_latitude,
        current_longitude = EXCLUDED.current_longitude;

    -- =====================================================
    -- 2. RESTORE USER: Mec Aid (Talyer Owner)
    -- =====================================================

    -- Insert into user_profiles
    INSERT INTO public.user_profiles (
        id,
        first_name,
        last_name,
        email,
        phone_number,
        profile_image_url,
        status,
        user_type,
        created_at,
        updated_at,
        current_latitude,
        current_longitude,
        is_available,
        role,
        admin_permissions,
        last_login_at,
        login_count,
        email_verified_at,
        account_status,
        shop_id,
        first_login_completed,
        password_change_required,
        temp_email,
        email_change_token,
        email_change_expires_at,
        last_password_change,
        failed_login_attempts,
        account_locked_until,
        registration_completed,
        profile_completion_score,
        profile_image_required,
        first_login_password_changed,
        account_verification_status,
        verification_documents,
        business_permit_url,
        drivers_license_url,
        document_verification_status,
        document_verification_notes,
        verified_by,
        verified_at,
        can_login,
        requires_email_verification,
        shop_hours,
        settings,
        timezone,
        preferred_language,
        notification_preferences,
        rating,
        total_reviews
    ) VALUES (
        '19a8b4ca-f5f8-4b85-9147-5128d9651e04',
        'Mec',
        'Aid',
        'mechanicroadaid@gmail.com',
        '09945547110',
        'https://olxquclxgtrbyxfxxscj.supabase.co/storage/v1/object/public/profile-images/19a8b4ca-f5f8-4b85-9147-5128d9651e04_profile_1756777595755.jpg',
        'active',
        'talyer_owner',
        '2025-08-24 13:56:46.517931+00',
        '2025-11-09 04:23:39.081117+00',
        14.95310170,
        120.89655510,
        true,
        'customer',
        '[]'::jsonb,
        NULL,
        0,
        NULL,
        'active',
        'cedc2e63-7785-4d61-a8f1-9f4ed8d254da',
        false,
        false,
        NULL,
        NULL,
        NULL,
        '2025-09-02 08:55:45.27607+00',
        0,
        NULL,
        false,
        0,
        true,
        false,
        'pending',
        '{}'::jsonb,
        NULL,
        NULL,
        'pending',
        NULL,
        NULL,
        NULL,
        true,
        true,
        '{"friday": {"isOpen": true, "openTime": "08:00", "closeTime": "17:00"}, "monday": {"isOpen": true, "openTime": "08:00", "closeTime": "17:00"}, "sunday": {"isOpen": false, "openTime": "09:00", "closeTime": "17:00"}, "tuesday": {"isOpen": true, "openTime": "08:00", "closeTime": "18:00"}, "saturday": {"isOpen": false, "openTime": "09:00", "closeTime": "17:00"}, "thursday": {"isOpen": true, "openTime": "08:00", "closeTime": "17:00"}, "wednesday": {"isOpen": true, "openTime": "08:00", "closeTime": "17:00"}}'::jsonb,
        '{}'::jsonb,
        'Asia/Manila',
        'en',
        '{"sms": false, "push": true, "email": true}'::jsonb,
        0.00,
        0
    )
    ON CONFLICT (id) DO UPDATE SET
        first_name = EXCLUDED.first_name,
        last_name = EXCLUDED.last_name,
        email = EXCLUDED.email,
        phone_number = EXCLUDED.phone_number,
        profile_image_url = EXCLUDED.profile_image_url,
        updated_at = EXCLUDED.updated_at,
        current_latitude = EXCLUDED.current_latitude,
        current_longitude = EXCLUDED.current_longitude;

    -- =====================================================
    -- 3. RESTORE USER: Yuji Fuma (Mechanic)
    -- =====================================================

    -- Insert into user_profiles
    INSERT INTO public.user_profiles (
        id,
        first_name,
        last_name,
        email,
        phone_number,
        profile_image_url,
        status,
        user_type,
        created_at,
        updated_at,
        current_latitude,
        current_longitude,
        is_available,
        role,
        admin_permissions,
        last_login_at,
        login_count,
        email_verified_at,
        account_status,
        shop_id,
        first_login_completed,
        password_change_required,
        temp_email,
        email_change_token,
        email_change_expires_at,
        last_password_change,
        failed_login_attempts,
        account_locked_until,
        registration_completed,
        profile_completion_score,
        profile_image_required,
        first_login_password_changed,
        account_verification_status,
        verification_documents,
        business_permit_url,
        drivers_license_url,
        document_verification_status,
        document_verification_notes,
        verified_by,
        verified_at,
        can_login,
        requires_email_verification,
        shop_hours,
        settings,
        timezone,
        preferred_language,
        notification_preferences,
        rating,
        total_reviews
    ) VALUES (
        'e4cbf14b-5729-45ef-a124-1f2e05acad8c',
        'yuji',
        'fuma',
        'yujirofuma28@gmail.com',
        '09123456789',
        'https://olxquclxgtrbyxfxxscj.supabase.co/storage/v1/object/public/profile-images/profile_images/e4cbf14b-5729-45ef-a124-1f2e05acad8c-1760329656593.jpg',
        'active',
        'mechanic',
        '2025-10-13 04:27:34.877766+00',
        '2025-10-19 06:27:34.413166+00',
        14.93215270,
        120.88071560,
        true,
        'mechanic',
        '[]'::jsonb,
        NULL,
        0,
        '2025-10-13 04:27:34.877766+00',
        'active',
        'cedc2e63-7785-4d61-a8f1-9f4ed8d254da',
        false,
        true,
        NULL,
        NULL,
        NULL,
        NULL,
        0,
        NULL,
        false,
        0,
        true,
        false,
        'pending',
        '{}'::jsonb,
        NULL,
        NULL,
        'pending',
        NULL,
        NULL,
        NULL,
        true,
        false,
        '{}'::jsonb,
        '{}'::jsonb,
        'Asia/Manila',
        'en',
        '{"sms": false, "push": true, "email": true}'::jsonb,
        0.00,
        0
    )
    ON CONFLICT (id) DO UPDATE SET
        first_name = EXCLUDED.first_name,
        last_name = EXCLUDED.last_name,
        email = EXCLUDED.email,
        phone_number = EXCLUDED.phone_number,
        profile_image_url = EXCLUDED.profile_image_url,
        updated_at = EXCLUDED.updated_at,
        current_latitude = EXCLUDED.current_latitude,
        current_longitude = EXCLUDED.current_longitude;

    -- =====================================================
    -- RESTORE service_providers for Yuji (Mechanic)
    -- =====================================================

    -- Insert into service_providers for the mechanic
    INSERT INTO public.service_providers (
        id,
        user_id,
        company_name,
        license_number,
        insurance_policy_number,
        rating,
        total_reviews,
        years_experience,
        service_radius,
        is_verified,
        is_available,
        current_latitude,
        current_longitude,
        status,
        created_at,
        updated_at,
        talyer_owner_id,
        shop_id,
        last_online_at,
        response_time_avg_minutes,
        completion_rate_percentage,
        cancellation_rate_percentage
    )
    SELECT 
        gen_random_uuid(),
        'e4cbf14b-5729-45ef-a124-1f2e05acad8c',
        NULL,
        NULL,
        NULL,
        0.00,
        0,
        NULL,
        50.0,
        false,
        true,
        14.93215270,
        120.88071560,
        'offline',
        '2025-10-13 04:27:34.877766+00',
        '2025-10-19 06:27:34.413166+00',
        '19a8b4ca-f5f8-4b85-9147-5128d9651e04', -- Mec Aid as talyer_owner
        'cedc2e63-7785-4d61-a8f1-9f4ed8d254da',
        now(),
        30,
        100.0,
        0.0
    WHERE NOT EXISTS (
        SELECT 1 FROM public.service_providers 
        WHERE user_id = 'e4cbf14b-5729-45ef-a124-1f2e05acad8c'
    );

    -- =====================================================
    -- RESTORE shop_mechanics for Yuji
    -- =====================================================

    -- Insert into shop_mechanics
    INSERT INTO public.shop_mechanics (
        id,
        shop_id,
        mechanic_id,
        role,
        specialties,
        hourly_rate,
        is_active,
        is_available,
        joined_at,
        created_at,
        updated_at
    )
    SELECT
        gen_random_uuid(),
        'cedc2e63-7785-4d61-a8f1-9f4ed8d254da',
        'e4cbf14b-5729-45ef-a124-1f2e05acad8c',
        'mechanic',
        ARRAY['General Repair', 'Engine Diagnostics'],
        NULL,
        true,
        true,
        '2025-10-13 04:27:34.877766+00',
        '2025-10-13 04:27:34.877766+00',
        '2025-10-19 06:27:34.413166+00'
    WHERE NOT EXISTS (
        SELECT 1 FROM public.shop_mechanics 
        WHERE mechanic_id = 'e4cbf14b-5729-45ef-a124-1f2e05acad8c'
        AND shop_id = 'cedc2e63-7785-4d61-a8f1-9f4ed8d254da'
    );

    -- =====================================================
    -- NOTES & VERIFICATION
    -- =====================================================

    -- Check if users were restored successfully
    DO $$
    DECLARE
        riza_shop_count INT;
        mec_shop_count INT;
        riza_count INT;
        mec_count INT;
        yuji_count INT;
        yuji_provider_count INT;
        yuji_shop_mechanic_count INT;
    BEGIN
        SELECT COUNT(*) INTO riza_shop_count FROM public.shops WHERE id = '5d963bdf-1879-4575-9375-df62b1ff3fe0';
        SELECT COUNT(*) INTO mec_shop_count FROM public.shops WHERE id = 'cedc2e63-7785-4d61-a8f1-9f4ed8d254da';
        SELECT COUNT(*) INTO riza_count FROM public.user_profiles WHERE id = '98543023-1960-4f70-b76a-d700ea70976c';
        SELECT COUNT(*) INTO mec_count FROM public.user_profiles WHERE id = '19a8b4ca-f5f8-4b85-9147-5128d9651e04';
        SELECT COUNT(*) INTO yuji_count FROM public.user_profiles WHERE id = 'e4cbf14b-5729-45ef-a124-1f2e05acad8c';
        SELECT COUNT(*) INTO yuji_provider_count FROM public.service_providers WHERE user_id = 'e4cbf14b-5729-45ef-a124-1f2e05acad8c';
        SELECT COUNT(*) INTO yuji_shop_mechanic_count FROM public.shop_mechanics WHERE mechanic_id = 'e4cbf14b-5729-45ef-a124-1f2e05acad8c';
        
        RAISE NOTICE '✅ Restoration Summary:';
        RAISE NOTICE '   📍 Shops Created:';
        RAISE NOTICE '      - Riza Auto Repair Shop: % record(s)', riza_shop_count;
        RAISE NOTICE '      - MecAid Auto Services: % record(s)', mec_shop_count;
        RAISE NOTICE '   👤 Users Created:';
        RAISE NOTICE '      - Riza Pineda (talyer_owner): % record(s)', riza_count;
        RAISE NOTICE '      - Mec Aid (talyer_owner): % record(s)', mec_count;
        RAISE NOTICE '      - Yuji Fuma (mechanic): % record(s)', yuji_count;
        RAISE NOTICE '   🔗 Related Records:';
        RAISE NOTICE '      - Yuji service_provider: % record(s)', yuji_provider_count;
        RAISE NOTICE '      - Yuji shop_mechanics: % record(s)', yuji_shop_mechanic_count;
        
        IF riza_shop_count > 0 AND mec_shop_count > 0 AND riza_count > 0 AND mec_count > 0 AND yuji_count > 0 THEN
            RAISE NOTICE '✅✅✅ All shops and users restored successfully!';
        ELSE
            RAISE WARNING '⚠️ Some shops or users may not have been restored. Check above counts.';
        END IF;
    END $$;

    COMMIT;

    -- =====================================================
    -- VERIFICATION QUERIES
    -- =====================================================

    -- Verify shops exist
    SELECT 
        id,
        shop_name,
        owner_id,
        is_active,
        latitude,
        longitude,
        shop_phone
    FROM public.shops
    WHERE id IN (
        '5d963bdf-1879-4575-9375-df62b1ff3fe0',
        'cedc2e63-7785-4d61-a8f1-9f4ed8d254da'
    )
    ORDER BY shop_name;

    -- Verify all 3 users exist
    SELECT 
        id,
        first_name,
        last_name,
        email,
        user_type,
        account_status,
        can_login,
        shop_id
    FROM public.user_profiles
    WHERE id IN (
        '98543023-1960-4f70-b76a-d700ea70976c',
        '19a8b4ca-f5f8-4b85-9147-5128d9651e04',
        'e4cbf14b-5729-45ef-a124-1f2e05acad8c'
    )
    ORDER BY user_type DESC, email;

    -- Verify mechanic's related records
    SELECT 
        'service_providers' as table_name,
        COUNT(*) as record_count
    FROM public.service_providers
    WHERE user_id = 'e4cbf14b-5729-45ef-a124-1f2e05acad8c'

    UNION ALL

    SELECT 
        'shop_mechanics' as table_name,
        COUNT(*) as record_count
    FROM public.shop_mechanics
    WHERE mechanic_id = 'e4cbf14b-5729-45ef-a124-1f2e05acad8c';

    -- =====================================================
    -- IMPORTANT NOTES:
    -- =====================================================
    -- 1. This script creates COMPLETE restoration including:
    --    ✅ auth.users (3 users)
    --    ✅ shops (2 shops)
    --    ✅ user_profiles (3 profiles)
    --    ✅ service_providers (1 mechanic)
    --    ✅ shop_mechanics (1 mechanic link)
    --
    -- 2. Temporary password set: "temporary_password_123"
    --    - Users MUST reset their passwords to login
    --    - Use Supabase Auth password reset flow
    --
    -- 3. Uses ON CONFLICT to safely handle existing records
    --    - Safe to run multiple times
    --    - Will update existing records if they exist
    --
    -- 4. Shop Structure:
    --    - Riza's Shop: 5d963bdf-1879-4575-9375-df62b1ff3fe0
    --      Owner: Riza Pineda (talyer_owner)
    --    - Mec's Shop: cedc2e63-7785-4d61-a8f1-9f4ed8d254da
    --      Owner: Mec Aid (talyer_owner)
    --      Mechanic: Yuji Fuma
    --
    -- 5. All users restored with their original:
    --    - User IDs
    --    - Locations (lat/long)
    --    - Business hours
    --    - Settings and preferences
    -- =====================================================
