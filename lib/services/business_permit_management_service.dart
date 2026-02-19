import '../services/supabase_service.dart';

class BusinessPermitManagementService {
  static final BusinessPermitManagementService instance = BusinessPermitManagementService._internal();
  BusinessPermitManagementService._internal();

  /// Get all business permits with provider information
  Future<List<Map<String, dynamic>>> getAllBusinessPermits({
    bool? isVerified,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      print('📋 Fetching business permits...');
      
      var query = SupabaseService.client
          .from('business_permits')
          .select('''
            id,
            business_permit_name,
            registered_address,
            nature_of_business,
            business_address,
            receipt_no,
            issued_on,
            issued_at,
            permit_document_url,
            extraction_confidence_score,
            is_verified,
            verification_notes,
            verified_at,
            created_at,
            updated_at,
            service_providers!business_permits_provider_id_fkey (
              id,
              company_name,
              user_profiles!service_providers_user_id_fkey (
                first_name,
                last_name,
                email,
                phone_number
              )
            )
          ''');

      if (isVerified != null) {
        query = query.eq('is_verified', isVerified);
      }

      final result = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      
      print('✅ Retrieved ${result.length} business permits');
      return result;
    } catch (e) {
      print('❌ Error fetching business permits: $e');
      return [];
    }
  }

  /// Get business permit by ID
  Future<Map<String, dynamic>?> getBusinessPermitById(String permitId) async {
    try {
      final result = await SupabaseService.client
          .from('business_permits')
          .select('''
            *,
            service_providers!business_permits_provider_id_fkey (
              id,
              company_name,
              user_profiles!service_providers_user_id_fkey (
                first_name,
                last_name,
                email,
                phone_number
              )
            )
          ''')
          .eq('id', permitId)
          .maybeSingle();

      return result;
    } catch (e) {
      print('❌ Error fetching business permit: $e');
      return null;
    }
  }

  /// Get business permits by provider ID
  Future<List<Map<String, dynamic>>> getBusinessPermitsByProviderId(String providerId) async {
    try {
      final result = await SupabaseService.client
          .from('business_permits')
          .select('*')
          .eq('provider_id', providerId)
          .order('created_at', ascending: false);

      return result;
    } catch (e) {
      print('❌ Error fetching business permits for provider: $e');
      return [];
    }
  }

  /// Update business permit verification status
  Future<bool> updateVerificationStatus({
    required String permitId,
    required bool isVerified,
    String? verificationNotes,
    String? verifiedBy,
  }) async {
    try {
      print('📝 Updating verification status for permit: $permitId');
      
      await SupabaseService.client
          .from('business_permits')
          .update({
            'is_verified': isVerified,
            'verification_notes': verificationNotes,
            'verified_by': verifiedBy,
            'verified_at': isVerified ? DateTime.now().toIso8601String() : null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', permitId);

      print('✅ Business permit verification status updated');
      return true;
    } catch (e) {
      print('❌ Error updating verification status: $e');
      return false;
    }
  }

  /// Get business permits statistics
  Future<Map<String, dynamic>> getBusinessPermitStats() async {
    try {
      print('📊 Calculating business permit statistics...');
      
      // Get all permits to calculate stats
      final allPermits = await SupabaseService.client
          .from('business_permits')
          .select('is_verified, extraction_confidence_score, created_at');
      
      final total = allPermits.length;
      final verified = allPermits.where((p) => p['is_verified'] == true).length;
      final unverified = total - verified;

      // Get high confidence extractions (>= 80%)
      final highConfidence = allPermits.where((p) => 
        (p['extraction_confidence_score'] ?? 0.0) >= 80).length;

      // Get recent permits (last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recent = allPermits.where((p) {
        final createdAt = DateTime.tryParse(p['created_at'] ?? '');
        return createdAt != null && createdAt.isAfter(thirtyDaysAgo);
      }).length;

      final stats = {
        'total_permits': total,
        'verified_permits': verified,
        'unverified_permits': unverified,
        'high_confidence_extractions': highConfidence,
        'recent_permits_30_days': recent,
        'verification_rate': total > 0 ? (verified / total * 100).round() : 0,
        'high_confidence_rate': total > 0 ? (highConfidence / total * 100).round() : 0,
      };

      print('✅ Business permit stats calculated: $stats');
      return stats;
    } catch (e) {
      print('❌ Error calculating business permit stats: $e');
      return {
        'total_permits': 0,
        'verified_permits': 0,
        'unverified_permits': 0,
        'high_confidence_extractions': 0,
        'recent_permits_30_days': 0,
        'verification_rate': 0,
        'high_confidence_rate': 0,
      };
    }
  }

  /// Search business permits by business name or receipt number
  Future<List<Map<String, dynamic>>> searchBusinessPermits(String searchTerm) async {
    try {
      print('🔍 Searching business permits for: $searchTerm');
      
      final result = await SupabaseService.client
          .from('business_permits')
          .select('''
            id,
            business_permit_name,
            registered_address,
            nature_of_business,
            receipt_no,
            issued_on,
            issued_at,
            extraction_confidence_score,
            is_verified,
            created_at,
            service_providers!business_permits_provider_id_fkey (
              company_name,
              user_profiles!service_providers_user_id_fkey (
                first_name,
                last_name,
                email
              )
            )
          ''')
          .or('business_permit_name.ilike.%$searchTerm%,receipt_no.ilike.%$searchTerm%')
          .order('created_at', ascending: false)
          .limit(20);

      print('✅ Found ${result.length} matching business permits');
      return result;
    } catch (e) {
      print('❌ Error searching business permits: $e');
      return [];
    }
  }

  /// Delete business permit (admin only)
  Future<bool> deleteBusinessPermit(String permitId) async {
    try {
      print('🗑️ Deleting business permit: $permitId');
      
      await SupabaseService.client
          .from('business_permits')
          .delete()
          .eq('id', permitId);

      print('✅ Business permit deleted successfully');
      return true;
    } catch (e) {
      print('❌ Error deleting business permit: $e');
      return false;
    }
  }

  /// Get extraction quality metrics
  Future<Map<String, dynamic>> getExtractionQualityMetrics() async {
    try {
      print('📈 Calculating extraction quality metrics...');
      
      // Get all permits to calculate metrics
      final allPermits = await SupabaseService.client
          .from('business_permits')
          .select('extraction_confidence_score');

      if (allPermits.isEmpty) {
        return {
          'average_confidence_score': 0,
          'total_extractions': 0,
          'confidence_distribution': {
            'excellent': 0,
            'good': 0,
            'fair': 0,
            'poor': 0,
          },
        };
      }

      // Calculate average confidence score
      final scores = allPermits
          .map((p) => (p['extraction_confidence_score'] ?? 0.0) as double)
          .toList();
      final avgConfidence = scores.reduce((a, b) => a + b) / scores.length;

      // Calculate confidence distribution
      final buckets = {
        'excellent': 0, // 90-100%
        'good': 0,      // 70-89%
        'fair': 0,      // 50-69%
        'poor': 0,      // 0-49%
      };

      for (final score in scores) {
        if (score >= 90) {
          buckets['excellent'] = (buckets['excellent'] ?? 0) + 1;
        } else if (score >= 70) {
          buckets['good'] = (buckets['good'] ?? 0) + 1;
        } else if (score >= 50) {
          buckets['fair'] = (buckets['fair'] ?? 0) + 1;
        } else {
          buckets['poor'] = (buckets['poor'] ?? 0) + 1;
        }
      }

      final metrics = {
        'average_confidence_score': avgConfidence.round(),
        'total_extractions': allPermits.length,
        'confidence_distribution': buckets,
      };

      print('✅ Extraction quality metrics calculated: $metrics');
      return metrics;
    } catch (e) {
      print('❌ Error calculating extraction metrics: $e');
      return {
        'average_confidence_score': 0,
        'total_extractions': 0,
        'confidence_distribution': {
          'excellent': 0,
          'good': 0,
          'fair': 0,
          'poor': 0,
        },
      };
    }
  }
}










