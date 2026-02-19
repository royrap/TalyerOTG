import 'package:supabase_flutter/supabase_flutter.dart';

class TalyerVerificationService {
  static final TalyerVerificationService _instance = TalyerVerificationService._internal();
  static TalyerVerificationService get instance => _instance;
  TalyerVerificationService._internal();

  final _supabase = Supabase.instance.client;

  /// Get pending TalYer verification requests
  Future<List<TalyerVerificationRequest>> getPendingVerifications() async {
    try {
      final response = await _supabase
          .from('talyer_verifications')
          .select('''
            *,
            user_profiles!inner(
              id, first_name, last_name, email, phone_number, profile_picture_url
            )
          ''')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return response.map((data) => TalyerVerificationRequest.fromJson(data)).toList();
    } catch (e) {
      print('❌ Error fetching pending verifications: $e');
      return [];
    }
  }

  /// Get verification request by ID
  Future<TalyerVerificationRequest?> getVerificationById(String id) async {
    try {
      final response = await _supabase
          .from('talyer_verifications')
          .select('''
            *,
            user_profiles!inner(
              id, first_name, last_name, email, phone_number, profile_picture_url
            )
          ''')
          .eq('id', id)
          .single();

      return TalyerVerificationRequest.fromJson(response);
    } catch (e) {
      print('❌ Error fetching verification by ID: $e');
      return null;
    }
  }

  /// Get count of pending verifications
  Future<int> getPendingVerificationCount() async {
    try {
      final response = await _supabase
          .from('talyer_verifications')
          .select('id')
          .eq('status', 'pending');

      return response.length;
    } catch (e) {
      print('❌ Error getting pending verification count: $e');
      return 0;
    }
  }

  /// Approve TalYer verification
  Future<bool> approveVerification({
    required String verificationId,
    required String adminId,
    String? adminNotes,
  }) async {
    try {
      print('🔄 Approving TalYer verification: $verificationId');

      // Start transaction
      await _supabase.rpc('begin_transaction');

      try {
        // Update verification status
        await _supabase
            .from('talyer_verifications')
            .update({
              'status': 'approved',
              'reviewed_by': adminId,
              'reviewed_at': DateTime.now().toIso8601String(),
              'admin_notes': adminNotes,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', verificationId);

        // Get the verification to get user ID
        final verification = await getVerificationById(verificationId);
        if (verification == null) {
          throw Exception('Verification not found');
        }

        // Update user profile to set user_type as 'talyer'
        await _supabase
            .from('user_profiles')
            .update({
              'user_type': 'talyer',
              'is_verified': true,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', verification.userId);

        // Log admin activity
        await _logAdminActivity(
          adminId: adminId,
          actionType: 'talyer_approval',
          targetType: 'verification',
          targetId: verificationId,
          actionDetails: {
            'user_id': verification.userId,
            'approval_time': DateTime.now().toIso8601String(),
            'admin_notes': adminNotes,
          },
        );

        // Create notification for user
        await _createNotification(
          userId: verification.userId,
          title: 'TalYer Verification Approved! 🎉',
          message: 'Your TalYer application has been approved. You can now provide roadside assistance services.',
          type: 'verification_approved',
        );

        // Commit transaction
        await _supabase.rpc('commit_transaction');

        print('✅ TalYer verification approved successfully');
        return true;
      } catch (e) {
        // Rollback transaction
        await _supabase.rpc('rollback_transaction');
        throw e;
      }
    } catch (e) {
      print('❌ Error approving verification: $e');
      return false;
    }
  }

  /// Reject TalYer verification
  Future<bool> rejectVerification({
    required String verificationId,
    required String adminId,
    required String rejectionReason,
    String? adminNotes,
  }) async {
    try {
      print('🔄 Rejecting TalYer verification: $verificationId');

      // Get the verification to get user ID
      final verification = await getVerificationById(verificationId);
      if (verification == null) {
        throw Exception('Verification not found');
      }

      // Update verification status
      await _supabase
          .from('talyer_verifications')
          .update({
            'status': 'rejected',
            'reviewed_by': adminId,
            'reviewed_at': DateTime.now().toIso8601String(),
            'rejection_reason': rejectionReason,
            'admin_notes': adminNotes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', verificationId);

      // Log admin activity
      await _logAdminActivity(
        adminId: adminId,
        actionType: 'talyer_rejection',
        targetType: 'verification',
        targetId: verificationId,
        actionDetails: {
          'user_id': verification.userId,
          'rejection_reason': rejectionReason,
          'rejection_time': DateTime.now().toIso8601String(),
          'admin_notes': adminNotes,
        },
      );

      // Create notification for user
      await _createNotification(
        userId: verification.userId,
        title: 'TalYer Verification Update',
        message: 'Your TalYer application requires attention. Reason: $rejectionReason',
        type: 'verification_rejected',
      );

      print('✅ TalYer verification rejected successfully');
      return true;
    } catch (e) {
      print('❌ Error rejecting verification: $e');
      return false;
    }
  }

  /// Request additional information from applicant
  Future<bool> requestAdditionalInfo({
    required String verificationId,
    required String adminId,
    required String requestDetails,
    String? adminNotes,
  }) async {
    try {
      print('🔄 Requesting additional info for verification: $verificationId');

      // Get the verification to get user ID
      final verification = await getVerificationById(verificationId);
      if (verification == null) {
        throw Exception('Verification not found');
      }

      // Update verification status
      await _supabase
          .from('talyer_verifications')
          .update({
            'status': 'additional_info_required',
            'reviewed_by': adminId,
            'reviewed_at': DateTime.now().toIso8601String(),
            'additional_info_request': requestDetails,
            'admin_notes': adminNotes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', verificationId);

      // Log admin activity
      await _logAdminActivity(
        adminId: adminId,
        actionType: 'talyer_info_request',
        targetType: 'verification',
        targetId: verificationId,
        actionDetails: {
          'user_id': verification.userId,
          'request_details': requestDetails,
          'request_time': DateTime.now().toIso8601String(),
          'admin_notes': adminNotes,
        },
      );

      // Create notification for user
      await _createNotification(
        userId: verification.userId,
        title: 'Additional Information Required',
        message: 'Please provide additional information for your TalYer application: $requestDetails',
        type: 'verification_info_request',
      );

      print('✅ Additional information requested successfully');
      return true;
    } catch (e) {
      print('❌ Error requesting additional info: $e');
      return false;
    }
  }

  /// Get verification history for admin
  Future<List<TalyerVerificationRequest>> getVerificationHistory({
    String? status,
    String? reviewedBy,
    int limit = 50,
  }) async {
    try {
      var query = _supabase
          .from('talyer_verifications')
          .select('''
            *,
            user_profiles!inner(
              id, first_name, last_name, email, phone_number, profile_picture_url
            ),
            reviewer:user_profiles!reviewed_by(
              first_name, last_name
            )
          ''');

      if (status != null) {
        query = query.eq('status', status);
      }

      if (reviewedBy != null) {
        query = query.eq('reviewed_by', reviewedBy);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return response.map((data) => TalyerVerificationRequest.fromJson(data)).toList();
    } catch (e) {
      print('❌ Error fetching verification history: $e');
      return [];
    }
  }

  /// Get verification statistics
  Future<VerificationStats> getVerificationStats() async {
    try {
      final totalResponse = await _supabase
          .from('talyer_verifications')
          .select('status');

      final pendingCount = totalResponse.where((v) => v['status'] == 'pending').length;
      final approvedCount = totalResponse.where((v) => v['status'] == 'approved').length;
      final rejectedCount = totalResponse.where((v) => v['status'] == 'rejected').length;
      final infoRequestedCount = totalResponse.where((v) => v['status'] == 'additional_info_required').length;

      return VerificationStats(
        total: totalResponse.length,
        pending: pendingCount,
        approved: approvedCount,
        rejected: rejectedCount,
        infoRequested: infoRequestedCount,
      );
    } catch (e) {
      print('❌ Error getting verification stats: $e');
      return VerificationStats.empty();
    }
  }

  /// Log admin activity
  Future<void> _logAdminActivity({
    required String adminId,
    required String actionType,
    required String targetType,
    required String targetId,
    required Map<String, dynamic> actionDetails,
  }) async {
    try {
      await _supabase.from('admin_activity_logs').insert({
        'admin_id': adminId,
        'action_type': actionType,
        'target_type': targetType,
        'target_id': targetId,
        'action_details': actionDetails,
        'ip_address': 'mobile_app',
        'user_agent': 'RoadAidApp/1.0',
        'session_id': 'admin_${DateTime.now().millisecondsSinceEpoch}',
      });
    } catch (e) {
      print('❌ Error logging admin activity: $e');
    }
  }

  /// Create notification for user
  Future<void> _createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type,
        'is_read': false,
      });
    } catch (e) {
      print('❌ Error creating notification: $e');
    }
  }
}

/// TalYer verification request model
class TalyerVerificationRequest {
  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String? phoneNumber;
  final String? profilePictureUrl;
  final String status;
  final String? businessName;
  final String? businessLicense;
  final String? businessAddress;
  final String? yearsOfExperience;
  final List<String> serviceTypes;
  final List<String> certifications;
  final String? workingHours;
  final String? emergencyAvailability;
  final List<String> documentUrls;
  final String? additionalInfo;
  final String? reviewedBy;
  final String? reviewerFirstName;
  final String? reviewerLastName;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final String? additionalInfoRequest;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  TalyerVerificationRequest({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phoneNumber,
    this.profilePictureUrl,
    required this.status,
    this.businessName,
    this.businessLicense,
    this.businessAddress,
    this.yearsOfExperience,
    required this.serviceTypes,
    required this.certifications,
    this.workingHours,
    this.emergencyAvailability,
    required this.documentUrls,
    this.additionalInfo,
    this.reviewedBy,
    this.reviewerFirstName,
    this.reviewerLastName,
    this.reviewedAt,
    this.rejectionReason,
    this.additionalInfoRequest,
    this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TalyerVerificationRequest.fromJson(Map<String, dynamic> json) {
    final userProfile = json['user_profiles'] as Map<String, dynamic>?;
    final reviewer = json['reviewer'] as Map<String, dynamic>?;
    
    return TalyerVerificationRequest(
      id: json['id'],
      userId: json['user_id'],
      firstName: userProfile?['first_name'] ?? '',
      lastName: userProfile?['last_name'] ?? '',
      email: userProfile?['email'] ?? '',
      phoneNumber: userProfile?['phone_number'],
      profilePictureUrl: userProfile?['profile_picture_url'],
      status: json['status'],
      businessName: json['business_name'],
      businessLicense: json['business_license'],
      businessAddress: json['business_address'],
      yearsOfExperience: json['years_of_experience'],
      serviceTypes: List<String>.from(json['service_types'] ?? []),
      certifications: List<String>.from(json['certifications'] ?? []),
      workingHours: json['working_hours'],
      emergencyAvailability: json['emergency_availability'],
      documentUrls: List<String>.from(json['document_urls'] ?? []),
      additionalInfo: json['additional_info'],
      reviewedBy: json['reviewed_by'],
      reviewerFirstName: reviewer?['first_name'],
      reviewerLastName: reviewer?['last_name'],
      reviewedAt: json['reviewed_at'] != null ? DateTime.parse(json['reviewed_at']) : null,
      rejectionReason: json['rejection_reason'],
      additionalInfoRequest: json['additional_info_request'],
      adminNotes: json['admin_notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  String get fullName => '$firstName $lastName';
  
  String get statusDisplayName {
    switch (status) {
      case 'pending':
        return 'Pending Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'additional_info_required':
        return 'Info Required';
      default:
        return status;
    }
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get needsInfo => status == 'additional_info_required';
}

/// Verification statistics model
class VerificationStats {
  final int total;
  final int pending;
  final int approved;
  final int rejected;
  final int infoRequested;

  VerificationStats({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.infoRequested,
  });

  static VerificationStats empty() {
    return VerificationStats(
      total: 0,
      pending: 0,
      approved: 0,
      rejected: 0,
      infoRequested: 0,
    );
  }
}










