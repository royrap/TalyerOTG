import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/service_history_detail.dart';

class ServiceHistoryDetailService {
  static final ServiceHistoryDetailService instance = ServiceHistoryDetailService._internal();
  factory ServiceHistoryDetailService() => instance;
  ServiceHistoryDetailService._internal();

  final _supabase = Supabase.instance.client;

  /// Fetch complete service request details with all related data
  /// Works for both mechanic and customer views
  Future<ServiceHistoryDetail> getServiceRequestDetail(String requestId) async {
    try {
      print('🔍 Fetching service request detail for ID: $requestId');

      // Query with all necessary joins
      final response = await _supabase
          .from('service_requests')
          .select('''
            *,
            assigned_mechanic:user_profiles!service_requests_assigned_mechanic_id_fkey(
              id,
              first_name,
              last_name,
              phone_number,
              email,
              profile_image_url
            ),
            shop:shops!service_requests_shop_id_fkey(
              id,
              shop_name,
              shop_address,
              shop_phone,
              shop_email,
              latitude,
              longitude
            ),
            vehicle:vehicles!service_requests_vehicle_id_fkey(
              id,
              brand_name,
              model_name,
              plate_number,
              year,
              color
            ),
            category:service_categories!service_requests_category_id_fkey(
              id,
              name,
              icon_name
            ),
            invoices(
              id,
              invoice_number,
              subtotal,
              platform_fee,
              total_amount,
              status,
              selected_payment_method,
              paid_at,
              issued_at,
              payment_details,
              mechanic:user_profiles!invoices_mechanic_id_fkey(
                id,
                first_name,
                last_name,
                phone_number,
                email,
                profile_image_url
              )
            ),
            reviews(
              id,
              rating,
              comment,
              created_at
            )
          ''')
          .eq('id', requestId)
          .single();

      print('✅ Service request detail fetched successfully');
      print('   Status: ${response['status']}');
      print('   Has mechanic: ${response['assigned_mechanic'] != null}');
      print('   Has shop: ${response['shop'] != null}');
      print('   Has vehicle: ${response['vehicle'] != null}');
      print('   Has invoice: ${response['invoices'] != null && (response['invoices'] as List).isNotEmpty}');

      return ServiceHistoryDetail.fromJson(response);
    } catch (e) {
      print('❌ Error fetching service request detail: $e');
      rethrow;
    }
  }

  /// Get customer's service history with details
  Future<List<ServiceHistoryDetail>> getCustomerServiceHistory(String customerId) async {
    try {
      print('🔍 Fetching customer service history for: $customerId');

      final response = await _supabase
          .from('service_requests')
          .select('''
            *,
            assigned_mechanic:user_profiles!service_requests_assigned_mechanic_id_fkey(
              id,
              first_name,
              last_name,
              phone_number,
              email,
              profile_image_url
            ),
            shop:shops!service_requests_shop_id_fkey(
              id,
              shop_name,
              shop_address,
              shop_phone,
              shop_email
            ),
            vehicle:vehicles!service_requests_vehicle_id_fkey(
              id,
              brand_name,
              model_name,
              plate_number,
              year,
              color
            ),
            category:service_categories!service_requests_category_id_fkey(
              id,
              name,
              icon_name
            ),
            invoices(
              id,
              invoice_number,
              subtotal,
              platform_fee,
              total_amount,
              status,
              selected_payment_method,
              paid_at,
              payment_details
            ),
            reviews(
              id,
              rating,
              comment,
              created_at
            )
          ''')
          .eq('customer_id', customerId)
          .in_('status', ['completed', 'cancelled'])
          .order('created_at', ascending: false);

      print('✅ Found ${response.length} customer service history records');

      return response.map((json) => ServiceHistoryDetail.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error fetching customer service history: $e');
      rethrow;
    }
  }

  /// Get mechanic's job history with details
  Future<List<ServiceHistoryDetail>> getMechanicJobHistory(String mechanicId) async {
    try {
      print('🔍 Fetching mechanic job history for: $mechanicId');

      final response = await _supabase
          .from('service_requests')
          .select('''
            *,
            assigned_mechanic:user_profiles!service_requests_assigned_mechanic_id_fkey(
              id,
              first_name,
              last_name,
              phone_number,
              email,
              profile_image_url
            ),
            shop:shops!service_requests_shop_id_fkey(
              id,
              shop_name,
              shop_address,
              shop_phone,
              shop_email
            ),
            vehicle:vehicles!service_requests_vehicle_id_fkey(
              id,
              brand_name,
              model_name,
              plate_number,
              year,
              color
            ),
            category:service_categories!service_requests_category_id_fkey(
              id,
              name,
              icon_name
            ),
            customer:user_profiles!service_requests_customer_id_fkey(
              id,
              first_name,
              last_name,
              phone_number,
              email,
              profile_image_url
            ),
            invoices(
              id,
              invoice_number,
              subtotal,
              platform_fee,
              total_amount,
              status,
              selected_payment_method,
              paid_at,
              mechanic_id,
              payment_details
            ),
            reviews(
              id,
              rating,
              comment,
              created_at
            )
          ''')
          .eq('assigned_mechanic_id', mechanicId)
          .in_('status', ['completed', 'cancelled'])
          .order('created_at', ascending: false);

      print('✅ Found ${response.length} mechanic job history records');

      return response.map((json) => ServiceHistoryDetail.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error fetching mechanic job history: $e');
      rethrow;
    }
  }
}
