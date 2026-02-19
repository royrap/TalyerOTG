# AUDIT LOGGING SYSTEM IMPLEMENTATION GUIDE

## Overview
Comprehensive audit logging system for RoadAid that tracks all major system actions including service requests, mechanic assignments, payments, profile updates, and more.

## Database Structure

### Main Table: `audit_logs`
```sql
- id (UUID, primary key)
- user_id (UUID, nullable) - who performed the action
- role (VARCHAR) - user role: customer, mechanic, talyer_owner, admin, super_admin, system
- action (TEXT) - description of what was done
- table_name (VARCHAR) - which table was affected
- record_id (UUID) - which specific record was affected
- ip_address (VARCHAR) - user's IP address
- user_agent (TEXT) - browser/app information
- session_id (TEXT) - session tracking
- old_values (JSONB) - previous values for updates
- new_values (JSONB) - new values for updates/inserts
- additional_data (JSONB) - extra context data
- success (BOOLEAN) - whether action succeeded
- error_message (TEXT) - error details if failed
- created_at (TIMESTAMP) - when action occurred
```

## Main Functions

### 1. `log_action()` - Primary logging function
```sql
SELECT log_action(
    p_user_id := 'user-uuid',
    p_role := 'talyer_owner',
    p_action := 'assigned mechanic to service request',
    p_table_name := 'service_requests',
    p_record_id := 'request-uuid',
    p_ip := '192.168.1.1',
    p_additional_data := '{"mechanic_id": "mechanic-uuid"}'::jsonb
);
```

### 2. `log_action_simple()` - Simplified version
```sql
SELECT log_action_simple(
    p_user_id := 'user-uuid',
    p_role := 'customer',
    p_action := 'created service request',
    p_table_name := 'service_requests',
    p_record_id := 'request-uuid'
);
```

## Integration Examples for Flutter App

### 1. Service Request Actions
```dart
// In TalyerOwnerService.dart - when accepting a request
Future<void> acceptServiceRequest(String requestId) async {
  try {
    // Accept the request
    await _supabase.from('service_requests')
        .update({'status': 'accepted', 'accepted_at': DateTime.now().toIso8601String()})
        .eq('id', requestId);
    
    // Log the action
    await _supabase.rpc('log_action_simple', params: {
      'p_user_id': _supabase.auth.currentUser?.id,
      'p_role': 'talyer_owner',
      'p_action': 'accepted service request',
      'p_table_name': 'service_requests',
      'p_record_id': requestId,
    });
    
    print('✅ Service request accepted and logged');
  } catch (e) {
    // Log the failed action
    await _supabase.rpc('log_action', params: {
      'p_user_id': _supabase.auth.currentUser?.id,
      'p_role': 'talyer_owner',
      'p_action': 'attempted to accept service request',
      'p_table_name': 'service_requests',
      'p_record_id': requestId,
      'p_success': false,
      'p_error_message': e.toString(),
    });
    throw e;
  }
}
```

### 2. Mechanic Assignment
```dart
// In assignMechanicToRequest method
Future<void> assignMechanicToRequest(String requestId, String mechanicId) async {
  try {
    // Your existing assignment logic here...
    
    // Log the mechanic assignment
    await _supabase.rpc('log_mechanic_assignment', params: {
      'p_assigner_id': _supabase.auth.currentUser?.id,
      'p_assigner_role': 'talyer_owner',
      'p_mechanic_id': mechanicId,
      'p_request_id': requestId,
    });
    
    print('✅ Mechanic assignment logged');
  } catch (e) {
    // Log the failed assignment
    await _supabase.rpc('log_action', params: {
      'p_user_id': _supabase.auth.currentUser?.id,
      'p_role': 'talyer_owner',
      'p_action': 'failed to assign mechanic',
      'p_table_name': 'service_requests',
      'p_record_id': requestId,
      'p_success': false,
      'p_error_message': e.toString(),
      'p_additional_data': {'attempted_mechanic_id': mechanicId},
    });
    throw e;
  }
}
```

### 3. Payment Actions
```dart
// In PaymentService - when processing payment
Future<void> processPayment(String paymentId, double amount) async {
  try {
    // Your payment processing logic here...
    
    // Log the payment
    await _supabase.rpc('log_payment_action', params: {
      'p_user_id': _supabase.auth.currentUser?.id,
      'p_role': 'customer',
      'p_action': 'completed payment',
      'p_payment_id': paymentId,
      'p_amount': amount,
    });
    
    print('✅ Payment logged');
  } catch (e) {
    // Log failed payment
    await _supabase.rpc('log_payment_action', params: {
      'p_user_id': _supabase.auth.currentUser?.id,
      'p_role': 'customer',
      'p_action': 'payment failed',
      'p_payment_id': paymentId,
      'p_amount': amount,
    });
    throw e;
  }
}
```

### 4. Profile Updates
```dart
// In UserDataService - when updating profile
Future<void> updateProfile(Map<String, dynamic> updates) async {
  try {
    // Get old values first
    final oldProfile = await _supabase
        .from('user_profiles')
        .select()
        .eq('id', _supabase.auth.currentUser?.id)
        .single();
    
    // Update profile
    await _supabase
        .from('user_profiles')
        .update(updates)
        .eq('id', _supabase.auth.currentUser?.id);
    
    // Log the update
    await _supabase.rpc('log_action', params: {
      'p_user_id': _supabase.auth.currentUser?.id,
      'p_role': 'customer', // or determine from profile
      'p_action': 'updated profile information',
      'p_table_name': 'user_profiles',
      'p_record_id': _supabase.auth.currentUser?.id,
      'p_old_values': oldProfile,
      'p_new_values': {...oldProfile, ...updates},
    });
    
    print('✅ Profile update logged');
  } catch (e) {
    // Log failed update
    await _supabase.rpc('log_action', params: {
      'p_user_id': _supabase.auth.currentUser?.id,
      'p_role': 'customer',
      'p_action': 'failed to update profile',
      'p_table_name': 'user_profiles',
      'p_record_id': _supabase.auth.currentUser?.id,
      'p_success': false,
      'p_error_message': e.toString(),
    });
    throw e;
  }
}
```

### 5. Login/Logout Actions
```dart
// In AuthService - when user logs in
Future<void> signIn(String email, String password) async {
  try {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    
    if (response.user != null) {
      // Log successful login
      await _supabase.rpc('log_action_simple', params: {
        'p_user_id': response.user!.id,
        'p_role': 'customer', // determine from user profile
        'p_action': 'user logged in',
      });
    }
  } catch (e) {
    // Log failed login attempt
    await _supabase.rpc('log_action', params: {
      'p_user_id': null,
      'p_role': 'system',
      'p_action': 'failed login attempt',
      'p_success': false,
      'p_error_message': e.toString(),
      'p_additional_data': {'attempted_email': email},
    });
    throw e;
  }
}
```

## Action Types to Log

### Service Request Flow
- `created service request`
- `accepted service request`
- `rejected service request`
- `assigned mechanic to service request`
- `updated service request status`
- `cancelled service request`
- `completed service request`

### Payment Flow
- `initiated payment`
- `completed payment`
- `payment failed`
- `payment refunded`
- `released payment to provider`

### Mechanic Management
- `assigned mechanic to job`
- `mechanic changed status to in_service`
- `mechanic changed status to available`
- `added new mechanic to shop`
- `removed mechanic from shop`

### Profile Management
- `updated profile information`
- `uploaded profile image`
- `updated email address`
- `changed password`
- `updated contact information`

### Authentication
- `user logged in`
- `user logged out`
- `failed login attempt`
- `password reset requested`
- `password reset completed`

### Invoice Management
- `generated invoice`
- `sent invoice to customer`
- `customer accepted invoice`
- `customer rejected invoice`
- `invoice marked as paid`

## Querying Audit Logs

### Recent Activity for a User
```sql
SELECT * FROM recent_user_activity 
WHERE user_id = 'user-uuid' 
ORDER BY created_at DESC 
LIMIT 50;
```

### All Actions for a Service Request
```sql
SELECT * FROM audit_logs 
WHERE table_name = 'service_requests' 
AND record_id = 'request-uuid'
ORDER BY created_at;
```

### Failed Actions Summary
```sql
SELECT action, COUNT(*) as failure_count
FROM audit_logs 
WHERE success = false 
AND created_at >= (now() - interval '7 days')
GROUP BY action
ORDER BY failure_count DESC;
```

### Daily Activity Summary
```sql
SELECT * FROM audit_logs_summary 
WHERE audit_date >= (current_date - interval '30 days')
ORDER BY audit_date DESC, action_count DESC;
```

## Best Practices

1. **Always log major actions** - service requests, payments, assignments
2. **Include context data** - use additional_data for extra information
3. **Log both success and failure** - helps with debugging
4. **Don't log sensitive data** - avoid passwords, tokens in logs
5. **Use specific action descriptions** - "assigned mechanic X to request Y"
6. **Include IP addresses when possible** - for security tracking
7. **Log at the service layer** - not in UI components

## Security Considerations

- Audit logs have RLS enabled - users can only see their own logs
- Admins can see all logs
- No sensitive data should be logged
- IP addresses are stored for security analysis
- Failed login attempts are tracked for security monitoring

## Performance Notes

- Indexes are created on frequently queried columns
- Automatic triggers log table changes
- Views provide summarized data for analytics
- Consider archiving old logs (>1 year) for performance

This audit system provides comprehensive tracking of all major actions in your RoadAid system while maintaining security and performance!
