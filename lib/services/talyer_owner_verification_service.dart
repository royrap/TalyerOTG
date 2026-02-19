import 'package:supabase_flutter/supabase_flutter.dart';

class TalyerOwnerVerificationService {
  static final TalyerOwnerVerificationService _instance = TalyerOwnerVerificationService._internal();
  static TalyerOwnerVerificationService get instance => _instance;
  TalyerOwnerVerificationService._internal();

  final _supabase = Supabase.instance.client;

  /// Get pending TalYer Owner registrations
  Future<List<Map<String, dynamic>>> getPendingRegistrations() async {
    try {
      print('📋 Fetching pending TalYer Owner registrations...');

      final result = await _supabase
          .from('talyer_owner_registrations')
          .select('''
            id,
            user_id,
            business_name,
            business_permit_url,
            valid_id_url,
            id_type,
            business_permit_expiry,
            id_expiry,
            status,
            submission_date,
            notes,
            flagged_reasons,
            user_profiles!talyer_owner_registrations_user_id_fkey(
              first_name,
              last_name,
              email,
              phone_number
            )
          ''')
          .eq('status', 'pending')
          .order('submission_date', ascending: true);

      return result;
    } catch (e) {
      print('❌ Error fetching pending registrations: $e');
      return [];
    }
  }

  /// Get all registrations with optional filters
  Future<List<Map<String, dynamic>>> getAllRegistrations({
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 50,
  }) async {
    try {
      var query = _supabase
          .from('talyer_owner_registrations')
          .select('''
            id,
            user_id,
            business_name,
            business_permit_url,
            valid_id_url,
            id_type,
            business_permit_expiry,
            id_expiry,
            status,
            submission_date,
            approved_at,
            rejected_at,
            approved_by,
            rejected_by,
            notes,
            rejection_reason,
            flagged_reasons,
            user_profiles!talyer_owner_registrations_user_id_fkey(
              first_name,
              last_name,
              email,
              phone_number
            )
          ''');

      if (status != null) query = query.eq('status', status);
      if (fromDate != null) query = query.gte('submission_date', fromDate.toIso8601String());
      if (toDate != null) query = query.lte('submission_date', toDate.toIso8601String());

      final result = await query
          .order('submission_date', ascending: false)
          .limit(limit);

      return result;
    } catch (e) {
      print('❌ Error fetching registrations: $e');
      return [];
    }
  }

  /// Approve TalYer Owner registration
  Future<bool> approveRegistration(String registrationId, String adminId, {String? notes}) async {
    try {
      print('✅ Approving registration: $registrationId');

      // Update registration status
      await _supabase
          .from('talyer_owner_registrations')
          .update({
            'status': 'approved',
            'approved_at': DateTime.now().toIso8601String(),
            'approved_by': adminId,
            'notes': notes,
          })
          .eq('id', registrationId);

      // Get registration details
      final registration = await _supabase
          .from('talyer_owner_registrations')
          .select('user_id, business_name')
          .eq('id', registrationId)
          .single();

      // Update user profile to TalYer Owner
      await _supabase
          .from('user_profiles')
          .update({'user_type': 'talyer_owner'})
          .eq('id', registration['user_id']);

      // Send approval notification
      await _sendApprovalNotification(
        registration['user_id'],
        registration['business_name'],
        approved: true,
        notes: notes,
      );

      // Log admin action
      await _logAdminAction(
        adminId: adminId,
        action: 'approve_talyer_registration',
        targetId: registrationId,
        details: {
          'registration_id': registrationId,
          'user_id': registration['user_id'],
          'business_name': registration['business_name'],
          'notes': notes,
        },
      );

      print('✅ Registration approved successfully');
      return true;
    } catch (e) {
      print('❌ Error approving registration: $e');
      return false;
    }
  }

  /// Reject TalYer Owner registration
  Future<bool> rejectRegistration(
    String registrationId,
    String adminId,
    String rejectionReason, {
    String? notes,
  }) async {
    try {
      print('❌ Rejecting registration: $registrationId');

      // Update registration status
      await _supabase
          .from('talyer_owner_registrations')
          .update({
            'status': 'rejected',
            'rejected_at': DateTime.now().toIso8601String(),
            'rejected_by': adminId,
            'rejection_reason': rejectionReason,
            'notes': notes,
          })
          .eq('id', registrationId);

      // Get registration details
      final registration = await _supabase
          .from('talyer_owner_registrations')
          .select('user_id, business_name')
          .eq('id', registrationId)
          .single();

      // Send rejection notification
      await _sendApprovalNotification(
        registration['user_id'],
        registration['business_name'],
        approved: false,
        rejectionReason: rejectionReason,
        notes: notes,
      );

      // Log admin action
      await _logAdminAction(
        adminId: adminId,
        action: 'reject_talyer_registration',
        targetId: registrationId,
        details: {
          'registration_id': registrationId,
          'user_id': registration['user_id'],
          'business_name': registration['business_name'],
          'rejection_reason': rejectionReason,
          'notes': notes,
        },
      );

      print('❌ Registration rejected successfully');
      return true;
    } catch (e) {
      print('❌ Error rejecting registration: $e');
      return false;
    }
  }

  /// Flag registration for manual review
  Future<bool> flagRegistration(
    String registrationId,
    String adminId,
    List<String> flaggedReasons, {
    String? notes,
  }) async {
    try {
      print('🚩 Flagging registration: $registrationId');

      await _supabase
          .from('talyer_owner_registrations')
          .update({
            'status': 'flagged',
            'flagged_reasons': flaggedReasons,
            'notes': notes,
          })
          .eq('id', registrationId);

      // Log admin action
      await _logAdminAction(
        adminId: adminId,
        action: 'flag_talyer_registration',
        targetId: registrationId,
        details: {
          'registration_id': registrationId,
          'flagged_reasons': flaggedReasons,
          'notes': notes,
        },
      );

      return true;
    } catch (e) {
      print('❌ Error flagging registration: $e');
      return false;
    }
  }

  /// Send approval/rejection notification
  Future<void> _sendApprovalNotification(
    String userId,
    String businessName,
    {required bool approved,
    String? rejectionReason,
    String? notes}) async {
    try {
      final title = approved 
          ? 'Registration Approved!' 
          : 'Registration Rejected';
      
      final body = approved
          ? 'Congratulations! Your TalYer Owner registration for "$businessName" has been approved. You can now start managing mechanics and accepting service requests.'
          : 'Unfortunately, your TalYer Owner registration for "$businessName" has been rejected. Reason: $rejectionReason${notes != null ? '\n\nNotes: $notes' : ''}';

      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'type': approved ? 'registration_approved' : 'registration_rejected',
        'data': {
          'business_name': businessName,
          'approved': approved,
          'rejection_reason': rejectionReason,
          'notes': notes,
        },
      });
    } catch (e) {
      print('❌ Error sending notification: $e');
    }
  }

  /// Log admin actions for audit trail
  Future<void> _logAdminAction({
    required String adminId,
    required String action,
    required String targetId,
    Map<String, dynamic>? details,
  }) async {
    try {
      await _supabase.from('admin_audit_logs').insert({
        'admin_id': adminId,
        'action': action,
        'target_type': 'talyer_registration',
        'target_id': targetId,
        'details': details,
        'timestamp': DateTime.now().toIso8601String(),
        'ip_address': 'mobile_app', // Could be enhanced with actual IP
      });
    } catch (e) {
      print('❌ Error logging admin action: $e');
    }
  }

  /// Get registration statistics
  Future<Map<String, int>> getRegistrationStatistics() async {
    try {
      final allRegistrations = await _supabase
          .from('talyer_owner_registrations')
          .select('status');

      final stats = <String, int>{
        'pending': 0,
        'approved': 0,
        'rejected': 0,
        'flagged': 0,
        'total': allRegistrations.length,
      };

      for (final registration in allRegistrations) {
        final status = registration['status']?.toString() ?? 'unknown';
        stats[status] = (stats[status] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      print('❌ Error getting registration statistics: $e');
      return {
        'pending': 0,
        'approved': 0,
        'rejected': 0,
        'flagged': 0,
        'total': 0,
      };
    }
  }

  /// Auto-flag registrations based on criteria
  Future<List<String>> autoFlagRegistrations() async {
    try {
      final flaggedIds = <String>[];
      
      // Get all pending registrations
      final pendingRegistrations = await _supabase
          .from('talyer_owner_registrations')
          .select('*')
          .eq('status', 'pending');

      for (final registration in pendingRegistrations) {
        final flags = <String>[];
        
        // Check for expired documents
        final permitExpiry = DateTime.tryParse(registration['business_permit_expiry'] ?? '');
        final idExpiry = DateTime.tryParse(registration['id_expiry'] ?? '');
        
        if (permitExpiry != null && permitExpiry.isBefore(DateTime.now())) {
          flags.add('expired_business_permit');
        }
        
        if (idExpiry != null && idExpiry.isBefore(DateTime.now())) {
          flags.add('expired_id');
        }
        
        // Check for missing documents
        if (registration['business_permit_url'] == null || registration['business_permit_url'].isEmpty) {
          flags.add('missing_business_permit');
        }
        
        if (registration['valid_id_url'] == null || registration['valid_id_url'].isEmpty) {
          flags.add('missing_valid_id');
        }
        
        // Check for suspicious patterns (you can add more logic here)
        final businessName = registration['business_name'] as String?;
        if (businessName != null && businessName.length < 3) {
          flags.add('suspicious_business_name');
        }
        
        // If any flags, update the registration
        if (flags.isNotEmpty) {
          await _supabase
              .from('talyer_owner_registrations')
              .update({
                'status': 'flagged',
                'flagged_reasons': flags,
                'notes': 'Auto-flagged by system for review',
              })
              .eq('id', registration['id']);
          
          flaggedIds.add(registration['id']);
        }
      }
      
      return flaggedIds;
    } catch (e) {
      print('❌ Error auto-flagging registrations: $e');
      return [];
    }
  }
}










