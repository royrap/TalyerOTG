# Fix: Shop Owner Cannot Add Mechanics

## Problem Identified

The `addMechanic()` method in `talyer_owner_api_service.dart` uses **Supabase Admin API** which requires service role key:

```dart
final authResponse = await _supabase.auth.admin.createUser(
  AdminUserAttributes(
    email: email,
    password: tempPassword,
    emailConfirm: false,
    ...
  ),
);
```

**This fails because:**
- The Flutter app uses `anon/public` key with user authentication
- `auth.admin.*` methods require `service_role` key
- Service role key should NEVER be in client apps (security risk)

## Solution Options

### Option 1: Use Supabase Edge Function (RECOMMENDED)

Create a Supabase Edge Function that runs server-side with service role privileges.

**Steps:**

1. **Create Edge Function** (in Supabase Dashboard → Edge Functions):

```typescript
// supabase/functions/add-mechanic/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const { email, firstName, lastName, phone, profileImageUrl, specialization, yearsExperience } = await req.json()
    
    // Get authorization header
    const authHeader = req.headers.get('Authorization')!
    const token = authHeader.replace('Bearer ', '')
    
    // Create anon client to verify user
    const anonClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    )
    
    const { data: { user } } = await anonClient.auth.getUser(token)
    if (!user) throw new Error('Not authenticated')
    
    // Create admin client with service role
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
    
    // Get shop ID
    const { data: shop } = await adminClient
      .from('shops')
      .select('id, shop_name, latitude, longitude')
      .eq('owner_id', user.id)
      .single()
    
    if (!shop) throw new Error('Shop not found')
    
    // Check if email exists
    const { data: existingUser } = await adminClient
      .from('user_profiles')
      .select('id')
      .eq('email', email)
      .maybeSingle()
    
    if (existingUser) throw new Error('Email already exists')
    
    // Generate temporary password
    const tempPassword = crypto.randomUUID().substring(0, 12)
    
    // Create auth user
    const { data: authData, error: authError } = await adminClient.auth.admin.createUser({
      email: email,
      password: tempPassword,
      email_confirm: false,
      user_metadata: {
        first_name: firstName,
        last_name: lastName,
        user_type: 'mechanic'
      }
    })
    
    if (authError) throw authError
    const mechanicId = authData.user.id
    
    // Create user profile
    await adminClient.from('user_profiles').insert({
      id: mechanicId,
      first_name: firstName,
      last_name: lastName,
      email: email,
      phone_number: phone,
      user_type: 'mechanic',
      profile_image_url: profileImageUrl,
      status: 'active',
      password_change_required: true,
      first_login_completed: false,
      requires_email_verification: true,
      can_login: false,
      shop_id: shop.id,
      current_latitude: shop.latitude,
      current_longitude: shop.longitude
    })
    
    // Create service provider
    await adminClient.from('service_providers').insert({
      user_id: mechanicId,
      company_name: shop.shop_name,
      years_experience: yearsExperience,
      service_radius: 50.0,
      is_verified: true,
      is_available: true,
      current_latitude: shop.latitude,
      current_longitude: shop.longitude,
      status: 'offline',
      rating: 0.00,
      total_reviews: 0,
      talyer_owner_id: user.id,
      shop_id: shop.id
    })
    
    // Create shop mechanics
    await adminClient.from('shop_mechanics').insert({
      shop_id: shop.id,
      mechanic_id: mechanicId,
      role: 'mechanic',
      is_active: true,
      is_available: true,
      specialties: [specialization]
    })
    
    // Store temporary password
    await adminClient.from('temporary_passwords').insert({
      user_id: mechanicId,
      email: email,
      temporary_password: tempPassword,
      password_hash: tempPassword,
      expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
      is_active: true,
      password_type: 'mechanic_invitation',
      created_by: user.id
    })
    
    return new Response(
      JSON.stringify({ 
        success: true, 
        mechanic_id: mechanicId,
        message: 'Mechanic added successfully'
      }),
      { headers: { 'Content-Type': 'application/json' } }
    )
    
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 400, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
```

2. **Update Flutter API Service** (`talyer_owner_api_service.dart`):

Replace the `addMechanic` method:

```dart
Future<void> addMechanic({
  required String email,
  required String firstName,
  required String lastName,
  required String phone,
  required dynamic profileImage,
  required String specialization,
  required int yearsExperience,
}) async {
  final currentUser = _supabase.auth.currentUser;
  if (currentUser == null) {
    throw Exception('Not authenticated');
  }

  // Upload profile image first
  String? profileImageUrl;
  if (profileImage != null) {
    final bytes = await profileImage.readAsBytes();
    final fileExt = profileImage.path.split('.').last;
    final fileName = '${currentUser.id}-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final filePath = 'profile_images/$fileName';

    await _supabase.storage
        .from('profile-images')
        .uploadBinary(filePath, bytes);

    profileImageUrl = _supabase.storage
        .from('profile-images')
        .getPublicUrl(filePath);
  }

  // Call Edge Function
  final response = await _supabase.functions.invoke(
    'add-mechanic',
    body: {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'profileImageUrl': profileImageUrl,
      'specialization': specialization,
      'yearsExperience': yearsExperience,
    },
  );

  if (response.status != 200) {
    final error = response.data?['error'] ?? 'Failed to add mechanic';
    throw Exception(error);
  }
}
```

### Option 2: Use Database RPC Function with Auth Triggers (ALTERNATIVE)

Create invitation records and use Supabase Auth webhooks to complete user creation.

**This is more complex and requires:**
1. Creating invitation records in `mechanic_invitations` table
2. Setting up Supabase Auth webhooks
3. Processing invitations when mechanic clicks email link
4. Completing user creation at that time

### Option 3: Quick Test Fix (NOT FOR PRODUCTION)

**WARNING: This exposes your service role key and is INSECURE!**

Only use this for testing:

```dart
// Initialize separate admin client (DO NOT USE IN PRODUCTION)
final _adminSupabase = SupabaseClient(
  'YOUR_SUPABASE_URL',
  'YOUR_SERVICE_ROLE_KEY', // ⚠️ NEVER expose this in production!
);

// Then use _adminSupabase.auth.admin.createUser() in addMechanic
```

## Recommended Implementation

**Use Option 1 (Edge Function)** because:
- ✅ Secure - service role key stays server-side
- ✅ Complete control over user creation
- ✅ Easy to maintain and debug
- ✅ Can handle image upload and all database operations
- ✅ Proper error handling and validation

## Deploy Steps

1. Install Supabase CLI: `npm install -g supabase`
2. Login: `supabase login`
3. Link project: `supabase link --project-ref YOUR_PROJECT_REF`
4. Create function: Create file `supabase/functions/add-mechanic/index.ts` with code above
5. Deploy: `supabase functions deploy add-mechanic`
6. Set secrets: 
   ```
   supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
   ```
7. Update Flutter code with new implementation
8. Test!

## Testing

```dart
// In Flutter
try {
  await _apiService.addMechanic(
    email: 'test@example.com',
    firstName: 'Test',
    lastName: 'Mechanic',
    phone: '+639123456789',
    profileImage: File('path/to/image.jpg'),
    specialization: 'Engine Repair',
    yearsExperience: 5,
  );
  print('✅ Success!');
} catch (e) {
  print('❌ Error: $e');
}
```
