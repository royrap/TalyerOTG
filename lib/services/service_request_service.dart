// Create a new service to handle service request creation

import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'shop_based_request_service.dart';

class ServiceRequestService {
  static final supabase = Supabase.instance.client;

  static Future<Map<String, dynamic>?> createServiceRequest({
    required String vehicleId,
    required String title,
    required String description,
    required String serviceType,
    required double latitude,
    required double longitude,
    required String locationAddress,
    String? priority,
    int? estimatedDuration,
    String? categories,
    List<Map<String, dynamic>>? selectedIssues,
    String? shopId, // Add shop_id parameter - NULL means broadcast to nearby shops
    String? providerId, // Add provider_id parameter (for direct mechanic assignment)
    Map<String, dynamic>? shopData, // Add shop data for additional context
  }) async {
    try {
      print('🔍 Creating service request...');
      
      // Get current user with better error handling
      final user = await AuthService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated. Please log in again.');
      }
      
      print('  - User ID: ${user.id}');
      print('  - Vehicle ID: $vehicleId');
      print('  - Title: $title');
      print('  - Service Type: $serviceType');
      print('  - Priority: ${priority ?? 'normal'}');
      print('  - Location: $latitude, $longitude');
      print('  - Categories: ${categories ?? 'general'}');
      print('  - Shop ID: ${shopId ?? 'NEARBY SHOPS (NULL)'}');
      print('  - Provider ID: ${providerId ?? 'No provider selected'}');
      
      // Validate required parameters
      if (vehicleId.trim().isEmpty) {
        throw Exception('Vehicle ID is required');
      }
      if (title.trim().isEmpty) {
        throw Exception('Service title is required');
      }
      if (description.trim().isEmpty) {
        throw Exception('Service description is required');
      }
      
      // Ensure title length fits DB constraints (varchar(100))
      String safeTitle = title.trim();
      if (safeTitle.length > 100) {
        safeTitle = safeTitle.substring(0, 97) + '...';
      }

      // Determine request targeting
      final isTargetedRequest = shopId != null && shopId.trim().isNotEmpty;
      print('  - Request Type: ${isTargetedRequest ? "SPECIFIC SHOP" : "NEARBY SHOPS"}');

      // If this is a shop-targeted request, use the ShopBasedRequestService which
      // already implements mechanic availability checks and notifications.
      if (isTargetedRequest) {
        final shopResult = await ShopBasedRequestService.instance.createShopBasedRequest(
          customerId: user.id,
          shopId: shopId.trim(),
          vehicleId: vehicleId.trim(),
          categoryId: (categories ?? 'general'),
          title: safeTitle,
          description: description.trim(),
          pickupLatitude: latitude,
          pickupLongitude: longitude,
          pickupAddress: locationAddress.trim(),
          additionalDetails: {
            'estimated_duration': estimatedDuration ?? 30,
            if (selectedIssues != null) 'selected_issues': _cleanSelectedIssues(selectedIssues),
            if (shopData != null) 'shop_data': _cleanShopData(shopData),
          },
        );

        if (shopResult['success'] != true) {
          // Return a clearer message to the caller/UI
          final msg = shopResult['message'] ?? 'No available mechanics in this shop. Please try another shop.';
          throw Exception(msg);
        }

        // Return the created request object for consistency with existing callers
        return shopResult['request'];
      }
      
      // Create comprehensive service request data with proper targeting
      final requestData = {
        'customer_id': user.id,
        'vehicle_id': vehicleId.trim(),
        'title': safeTitle,
        'description': description.trim(),
        'service_type': serviceType.trim(),
        'pickup_latitude': latitude,
        'pickup_longitude': longitude,
        'pickup_address': locationAddress.trim(),
        'status': 'pending',
        'payment_status': 'pending',
        'priority': priority?.trim() ?? 'normal',
        'created_at': DateTime.now().toIso8601String(),
        // CRITICAL: shop_id determines visibility
        // - NULL = all nearby shops see it
        // - Specific ID = only that shop sees it
        if (isTargetedRequest) 'shop_id': shopId.trim(),
  // New routing fields: explicit request type and preferred shop id
  if (isTargetedRequest) 'request_type': 'shop_based',
  if (isTargetedRequest) 'preferred_shop_id': shopId.trim(),
        // Note: We don't set shop_id if null - this allows nearby shops to see it
        if (providerId != null) 'provider_id': providerId.trim(),
        // Add comprehensive additional details
        'additional_details': {
          'request_source': isTargetedRequest ? 'specific_shop' : 'nearby_shops',
          'shop_selected': isTargetedRequest,
          if (shopData != null) ...{
            'shop_data': _cleanShopData(shopData),
            'selected_services': shopData['selectedServices'] ?? [],
            'service_price': shopData['servicePrice'] ?? 0.0,
            'shop_distance': shopData['shopDistance'] ?? 'Unknown',
          },
          'service_categories': categories ?? 'general',
          'estimated_duration': estimatedDuration ?? 30,
          if (selectedIssues != null) 'selected_issues': _cleanSelectedIssues(selectedIssues),
        },
        // Add notes with additional context
        'notes': _buildServiceNotes(selectedIssues, estimatedDuration, categories),
      };
      
      print('  - Request data: $requestData');
      
      final response = await supabase
          .from('service_requests')
          .insert(requestData)
          .select()
          .single();
      
      print('✅ Service request created successfully: ${response['id']}');
      print('   - Targeting: ${isTargetedRequest ? "Specific shop only" : "All nearby shops"}');
      
      // Log to request status history
      await _logStatusHistory(
        response['id'], 
        'pending', 
        isTargetedRequest 
          ? 'Service request sent to specific shop' 
          : 'Service request broadcast to nearby shops'
      );
      
      return response;
      
    } catch (e, stackTrace) {
      print('❌ Error creating service request: $e');
      print('📚 Stack trace: $stackTrace');
      
      // Provide more specific error messages
      String errorMessage = 'Failed to create service request';
      if (e.toString().contains('not authenticated')) {
        errorMessage = 'Please log in to create a service request';
      } else if (e.toString().contains('foreign key')) {
        errorMessage = 'Invalid vehicle or user data. Please try again.';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Permission denied. Please check your account access.';
      } else {
        errorMessage = 'Failed to create service request: ${e.toString()}';
      }
      
      throw Exception(errorMessage);
    }
  }

  static String _buildServiceNotes(List<Map<String, dynamic>>? selectedIssues, int? estimatedDuration, String? categories) {
    final notes = <String>[];
    
    if (selectedIssues != null && selectedIssues.isNotEmpty) {
      notes.add('Selected Services: ${selectedIssues.map((issue) => issue['title']).join(', ')}');
    }
    
    if (estimatedDuration != null) {
      notes.add('Estimated Duration: ${estimatedDuration} minutes');
    }
    
    if (categories != null && categories.isNotEmpty) {
      notes.add('Categories: $categories');
    }
    
    notes.add('Request created via mobile app');
    
    return notes.join('\n');
  }

  // Clean selectedIssues to remove non-serializable objects like IconData
  static List<Map<String, dynamic>> _cleanSelectedIssues(List<Map<String, dynamic>> selectedIssues) {
    return selectedIssues.map((issue) {
      final cleanedIssue = <String, dynamic>{};
      
      issue.forEach((key, value) {
        // Skip IconData and other non-serializable objects
        if (key == 'icon') {
          // Convert IconData to a string representation or skip it
          cleanedIssue['icon_code'] = value.toString();
        } else if (value is String || value is num || value is bool || value is List || value is Map) {
          // Only include serializable types
          cleanedIssue[key] = value;
        } else {
          // For other types, convert to string representation
          cleanedIssue[key] = value.toString();
        }
      });
      
      return cleanedIssue;
    }).toList();
  }

  // Clean shopData to remove non-serializable objects
  static Map<String, dynamic> _cleanShopData(Map<String, dynamic> shopData) {
    final cleanedData = <String, dynamic>{};
    
    shopData.forEach((key, value) {
      if (value is List) {
        // Clean lists recursively
        cleanedData[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return _cleanMapData(item);
          } else if (item is String || item is num || item is bool) {
            return item;
          } else {
            return item.toString();
          }
        }).toList();
      } else if (value is Map<String, dynamic>) {
        // Clean maps recursively
        cleanedData[key] = _cleanMapData(value);
      } else if (value is String || value is num || value is bool) {
        // Include primitive types as-is
        cleanedData[key] = value;
      } else {
        // Convert other types to string
        cleanedData[key] = value.toString();
      }
    });
    
    return cleanedData;
  }

  // Helper method to clean map data recursively
  static Map<String, dynamic> _cleanMapData(Map<String, dynamic> data) {
    final cleanedData = <String, dynamic>{};
    
    data.forEach((key, value) {
      if (key == 'icon') {
        // Convert IconData to string representation
        cleanedData['icon_code'] = value.toString();
      } else if (value is String || value is num || value is bool) {
        cleanedData[key] = value;
      } else if (value is List || value is Map) {
        // For complex types, include as-is (will be handled by outer cleaning)
        cleanedData[key] = value;
      } else {
        // Convert to string for other types
        cleanedData[key] = value.toString();
      }
    });
    
    return cleanedData;
  }

  static Future<void> _logStatusHistory(String requestId, String status, String notes) async {
    try {
      final user = await AuthService.getCurrentUser();
      
      await supabase.from('request_status_history').insert({
        'request_id': requestId,
        'status': status,
        'notes': notes,
        'changed_by': user?.id,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      print('✅ Status history logged: $status');
    } catch (e) {
      print('⚠️ Failed to log status history: $e');
      // Don't throw error as this is not critical for service request creation
    }
  }
  
  static Future<Map<String, dynamic>?> getServiceRequest(String requestId) async {
    try {
      if (requestId.trim().isEmpty) {
        throw Exception('Service request ID is required');
      }
      
      final response = await supabase
          .from('service_requests')
          .select('*')
          .eq('id', requestId.trim())
          .maybeSingle(); // Use maybeSingle to handle case where no record found
      
      return response;
    } catch (e) {
      print('❌ Error getting service request: $e');
      return null;
    }
  }
  
  static Future<bool> cancelServiceRequest(String requestId) async {
    try {
      if (requestId.trim().isEmpty) {
        throw Exception('Service request ID is required');
      }
      
      await supabase
          .from('service_requests')
          .update({
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId.trim());
      
      // Log status change
      await _logStatusHistory(requestId, 'cancelled', 'Service request cancelled by user');
      
      print('✅ Service request cancelled: $requestId');
      return true;
    } catch (e) {
      print('❌ Error cancelling service request: $e');
      return false;
    }
  }
}










