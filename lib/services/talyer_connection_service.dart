import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to handle talyer-customer connections for job assignments
class TalyerConnectionService {
  static final TalyerConnectionService _instance = TalyerConnectionService._internal();
  static TalyerConnectionService get instance => _instance;
  TalyerConnectionService._internal();

  final _supabase = Supabase.instance.client;

  /// Create a connection between customer, talyer owner, and assigned mechanic
  Future<String> createConnection({
    required String serviceRequestId,
    required String customerId,
    required String talyerOwnerId,
    required String providerId,
    Map<String, dynamic>? customerDetails,
    Map<String, dynamic>? talyerDetails,
  }) async {
    try {
      print('🔗 Creating talyer-customer connection...');
      
      final connection = {
        'service_request_id': serviceRequestId,
        'customer_id': customerId,
        'talyer_owner_id': talyerOwnerId,
        'provider_id': providerId,
        'status': 'connected',
        'connection_type': 'service_request',
        'customer_details': customerDetails,
        'talyer_details': talyerDetails,
        'connected_at': DateTime.now().toIso8601String(),
        'last_activity': DateTime.now().toIso8601String(),
      };

      final result = await _supabase
          .from('talyer_customer_connections')
          .insert(connection)
          .select('id')
          .single();

      print('✅ Talyer connection created: ${result['id']}');
      return result['id'];
    } catch (e) {
      print('❌ Error creating talyer connection: $e');
      throw Exception('Failed to create connection: $e');
    }
  }

  /// Update connection when mechanic is assigned
  Future<void> updateMechanicAssignment({
    required String serviceRequestId,
    required String providerId,
  }) async {
    try {
      await _supabase
          .from('talyer_customer_connections')
          .update({
            'provider_id': providerId,
            'status': 'connected',
            'connected_at': DateTime.now().toIso8601String(),
            'last_activity': DateTime.now().toIso8601String(),
          })
          .eq('service_request_id', serviceRequestId);
      
      print('✅ Updated mechanic assignment in talyer connection');
    } catch (e) {
      print('❌ Error updating mechanic assignment: $e');
      throw Exception('Failed to update mechanic assignment: $e');
    }
  }

  /// Get connection details for a service request
  Future<Map<String, dynamic>?> getConnectionByRequestId(String serviceRequestId) async {
    try {
      final result = await _supabase
          .from('talyer_customer_connections')
          .select('''
            *,
            customer:user_profiles!talyer_customer_connections_customer_id_fkey(
              id, first_name, last_name, email, phone_number
            ),
            talyer_owner:user_profiles!talyer_customer_connections_talyer_owner_id_fkey(
              id, first_name, last_name, email, phone_number
            ),
            provider:service_providers!talyer_customer_connections_provider_id_fkey(
              id, company_name, user_id,
              user_profile:user_profiles!service_providers_user_id_fkey(
                first_name, last_name, email, phone_number
              )
            )
          ''')
          .eq('service_request_id', serviceRequestId)
          .maybeSingle();

      return result;
    } catch (e) {
      print('❌ Error getting connection: $e');
      return null;
    }
  }

  /// Complete connection when job is finished
  Future<void> completeConnection(String serviceRequestId) async {
    try {
      await _supabase
          .from('talyer_customer_connections')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
            'last_activity': DateTime.now().toIso8601String(),
          })
          .eq('service_request_id', serviceRequestId);
      
      print('✅ Completed talyer connection');
    } catch (e) {
      print('❌ Error completing connection: $e');
      throw Exception('Failed to complete connection: $e');
    }
  }

  /// Get all connections for a talyer owner
  Future<List<Map<String, dynamic>>> getConnectionsForTalyerOwner(String talyerOwnerId) async {
    try {
      final result = await _supabase
          .from('talyer_customer_connections')
          .select('''
            *,
            service_request:service_requests!talyer_customer_connections_service_request_id_fkey(
              id, title, status, created_at, pickup_address
            ),
            customer:user_profiles!talyer_customer_connections_customer_id_fkey(
              id, first_name, last_name, email, phone_number
            ),
            provider:service_providers!talyer_customer_connections_provider_id_fkey(
              id, company_name, user_id,
              user_profile:user_profiles!service_providers_user_id_fkey(
                first_name, last_name, email
              )
            )
          ''')
          .eq('talyer_owner_id', talyerOwnerId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('❌ Error getting talyer connections: $e');
      return [];
    }
  }

  /// Check if a mechanic is assigned to a request through talyer system
  Future<bool> isMechanicAssignedThroughTalyer({
    required String serviceRequestId,
    required String mechanicProviderId,
  }) async {
    try {
      final connection = await _supabase
          .from('talyer_customer_connections')
          .select('provider_id, talyer_owner_id, status')
          .eq('service_request_id', serviceRequestId)
          .maybeSingle();

      if (connection == null) {
        print('❌ No talyer connection found for request');
        
        // If no connection exists, check if the mechanic is directly assigned to the service request
        final serviceRequest = await _supabase
            .from('service_requests')
            .select('provider_id, customer_id')
            .eq('id', serviceRequestId)
            .single();
        
        if (serviceRequest['provider_id'] == mechanicProviderId) {
          print('✅ Mechanic directly assigned to service request');
          
          // Get the mechanic's talyer owner info
          final mechanicProvider = await _supabase
              .from('service_providers')
              .select('talyer_owner_id, user_id')
              .eq('id', mechanicProviderId)
              .single();
          
          if (mechanicProvider['talyer_owner_id'] != null) {
            print('🏪 Creating missing talyer connection...');
            
            // Create the missing connection record
            await createConnection(
              serviceRequestId: serviceRequestId,
              customerId: serviceRequest['customer_id'],
              talyerOwnerId: mechanicProvider['talyer_owner_id'],
              providerId: mechanicProviderId,
            );
            
            print('✅ Created talyer connection for assigned mechanic');
            return true;
          }
        }
        
        return false;
      }

      // Check direct assignment
      if (connection['provider_id'] == mechanicProviderId) {
        print('✅ Mechanic directly assigned through talyer system');
        return true;
      }

      // Check if mechanic belongs to the same talyer owner
      final mechanicProvider = await _supabase
          .from('service_providers')
          .select('talyer_owner_id')
          .eq('id', mechanicProviderId)
          .single();

      if (mechanicProvider['talyer_owner_id'] == connection['talyer_owner_id'] &&
          connection['status'] == 'connected') {
        print('✅ Mechanic belongs to assigned talyer owner');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Error checking talyer assignment: $e');
      return false;
    }
  }

  /// Debug function to check talyer connections
  Future<Map<String, dynamic>> debugTalyerConnections(String serviceRequestId) async {
    try {
      final debug = <String, dynamic>{};
      
      // Check if connection exists
      final connection = await getConnectionByRequestId(serviceRequestId);
      debug['connection_exists'] = connection != null;
      
      if (connection != null) {
        debug['connection_details'] = {
          'status': connection['status'],
          'customer_id': connection['customer_id'],
          'talyer_owner_id': connection['talyer_owner_id'],
          'provider_id': connection['provider_id'],
          'created_at': connection['created_at'],
          'connected_at': connection['connected_at'],
        };
        
        // Get customer info
        if (connection['customer'] != null) {
          final customer = connection['customer'];
          debug['customer'] = {
            'name': '${customer['first_name']} ${customer['last_name']}',
            'email': customer['email'],
          };
        }
        
        // Get talyer owner info
        if (connection['talyer_owner'] != null) {
          final talyer = connection['talyer_owner'];
          debug['talyer_owner'] = {
            'name': '${talyer['first_name']} ${talyer['last_name']}',
            'email': talyer['email'],
          };
        }
        
        // Get assigned mechanic info
        if (connection['provider'] != null) {
          final provider = connection['provider'];
          final userProfile = provider['user_profile'];
          debug['assigned_mechanic'] = {
            'provider_id': provider['id'],
            'company': provider['company_name'],
            'mechanic_name': userProfile != null 
                ? '${userProfile['first_name']} ${userProfile['last_name']}'
                : 'Unknown',
            'email': userProfile?['email'],
          };
        }
      }
      
      return debug;
    } catch (e) {
      return {
        'error': e.toString(),
        'connection_exists': false,
      };
    }
  }
}










