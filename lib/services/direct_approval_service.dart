import 'package:supabase_flutter/supabase_flutter.dart';

class DirectApprovalService {
  static Future<void> approveSpecificUsers() async {
    try {
      print('🚀 Starting direct approval process...');
      
      final supabase = Supabase.instance.client;
      
      final emailsToApprove = [
        'paengpineda471@gmail.com',
        'rafaelpineda471@gmail.com',
      ];
      
      for (final email in emailsToApprove) {
        try {
          print('📧 Processing: $email');
          
          // Get user ID from email
          final userResponse = await supabase
              .from('user_profiles')
              .select('user_id')
              .eq('email', email.toLowerCase())
              .maybeSingle();
          
          if (userResponse == null) {
            print('❌ User not found: $email');
            continue;
          }
          
          final userId = userResponse['user_id'];
          
          // Update verification status
          await supabase
              .from('talyer_owner_verifications')
              .update({
                'status': 'approved',
                'verification_score': 100,
                'admin_notes': 'Manually approved by admin - Document verification successful',
                'reviewed_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
                'is_permit_expired': false,
                'is_id_expired': false,
              })
              .eq('user_id', userId);
          
          // Update user type
          await supabase
              .from('user_profiles')
              .update({
                'user_type': 'talyer_owner',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('user_id', userId);
          
          print('✅ Successfully approved: $email');
          
        } catch (e) {
          print('❌ Error processing $email: $e');
        }
      }
      
      print('🎉 Approval process completed!');
      
    } catch (e) {
      print('❌ Critical error: $e');
    }
  }
}
