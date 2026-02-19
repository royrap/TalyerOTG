import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class EmailService {
  static final EmailService _instance = EmailService._internal();
  static EmailService get instance => _instance;
  EmailService._internal();

  final _supabase = Supabase.instance.client;

  // Generate temporary password
  String generateTemporaryPassword() {
    const String chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final Random random = Random.secure();
    return List.generate(12, (index) => chars[random.nextInt(chars.length)]).join();
  }

  // Send welcome email to new mechanic
  Future<bool> sendMechanicWelcomeEmail({
    required String mechanicId,
    required String email,
    required String firstName,
    required String lastName,
    required String temporaryPassword,
    required String talyerOwnerName,
  }) async {
    try {
      print('📧 Preparing welcome email for mechanic: $email');

      // Get app download URLs
      final downloadUrls = await _getAppDownloadUrls();
      
      // Get email template from settings
      final emailTemplate = await _getEmailTemplate('email_welcome_mechanic_template');
      final emailSubject = await _getEmailTemplate('email_welcome_mechanic_subject');

      // Replace template variables
      final emailBody = emailTemplate
          .replaceAll('{{first_name}}', firstName)
          .replaceAll('{{last_name}}', lastName)
          .replaceAll('{{email}}', email)
          .replaceAll('{{password}}', temporaryPassword)
          .replaceAll('{{android_url}}', downloadUrls['android'] ?? 'https://play.google.com/store')
          .replaceAll('{{ios_url}}', downloadUrls['ios'] ?? 'https://apps.apple.com')
          .replaceAll('{{web_url}}', downloadUrls['web'] ?? 'https://app.RoadAid.com')
          .replaceAll('{{talyer_owner}}', talyerOwnerName);

      // Store temporary password
      await _storeTemporaryPassword(mechanicId, temporaryPassword);

      // Log email notification
      await _logEmailNotification(
        userId: mechanicId,
        emailType: 'welcome_mechanic',
        recipientEmail: email,
        subject: emailSubject,
        body: emailBody,
        emailData: {
          'temporary_password': temporaryPassword,
          'download_urls': downloadUrls,
          'talyer_owner': talyerOwnerName,
        },
      );

      // Send email using Supabase Edge Functions or external service
      final emailSent = await _sendEmailViaSupabase(
        to: email,
        subject: emailSubject,
        htmlBody: _formatEmailAsHTML(emailBody),
        textBody: emailBody,
      );

      if (emailSent) {
        print('✅ Welcome email sent successfully to $email');
        
        // Update email delivery status
        await _updateEmailDeliveryStatus(mechanicId, 'welcome_mechanic', 'delivered');
        return true;
      } else {
        print('❌ Failed to send welcome email to $email');
        await _updateEmailDeliveryStatus(mechanicId, 'welcome_mechanic', 'failed');
        return false;
      }

    } catch (e) {
      print('❌ Error sending mechanic welcome email: $e');
      try {
        await _updateEmailDeliveryStatus(mechanicId, 'welcome_mechanic', 'failed');
      } catch (updateError) {
        print('⚠️ Could not update email delivery status: $updateError');
      }
      return false;
    }
  }

  // Send welcome email for email change to new address
  Future<bool> sendEmailChangeWelcomeEmail({
    required String userId,
    required String newEmail,
    required String firstName,
    required String lastName,
    required String userType,
  }) async {
    try {
      print('📧 Preparing welcome email for email change: $newEmail');

      // Get app download URLs
      final downloadUrls = await _getAppDownloadUrls();
      
      // Get email template for email change welcome
      final emailTemplate = await _getEmailTemplate('email_change_welcome_template');
      final emailSubject = await _getEmailTemplate('email_change_welcome_subject');

      final fullName = '$firstName $lastName';
      final userTypeDisplay = _formatUserType(userType);

      // Replace template variables
      final emailBody = emailTemplate
          .replaceAll('{{full_name}}', fullName)
          .replaceAll('{{first_name}}', firstName)
          .replaceAll('{{user_type}}', userTypeDisplay)
          .replaceAll('{{email}}', newEmail)
          .replaceAll('{{android_url}}', downloadUrls['android'] ?? 'https://play.google.com/store')
          .replaceAll('{{ios_url}}', downloadUrls['ios'] ?? 'https://apps.apple.com')
          .replaceAll('{{web_url}}', downloadUrls['web'] ?? 'https://app.RoadAid.com');

      // Log email notification
      await _logEmailNotification(
        userId: userId,
        emailType: 'account_verification',
        recipientEmail: newEmail,
        subject: emailSubject,
        body: emailBody,
        emailData: {
          'user_type': userType,
          'download_urls': downloadUrls,
          'is_email_change': true,
        },
      );

      // Send email using Supabase Edge Functions or external service
      final emailSent = await _sendEmailViaSupabase(
        to: newEmail,
        subject: emailSubject,
        htmlBody: _formatEmailAsHTML(emailBody),
        textBody: emailBody,
      );

      if (emailSent) {
        print('✅ Email change welcome email sent successfully to $newEmail');
        
        // Update email delivery status
        await _updateEmailDeliveryStatus(userId, 'account_verification', 'delivered');
        return true;
      } else {
        print('❌ Failed to send email change welcome email to $newEmail');
        await _updateEmailDeliveryStatus(userId, 'account_verification', 'failed');
        return false;
      }

    } catch (e) {
      print('❌ Error sending email change welcome email: $e');
      try {
        await _updateEmailDeliveryStatus(userId, 'account_verification', 'failed');
      } catch (updateError) {
        print('⚠️ Could not update email delivery status: $updateError');
      }
      return false;
    }
  }

  // Check if email is new to the system
  Future<bool> isEmailNewToSystem(String email) async {
    try {
      final cleanEmail = email.toLowerCase().trim();
      
      // Check if email exists in user_profiles
      final profileCheck = await _supabase
          .from('user_profiles')
          .select('id')
          .eq('email', cleanEmail)
          .maybeSingle();

      // Email is new if it doesn't exist in user_profiles
      return profileCheck == null;
    } catch (e) {
      print('⚠️ Error checking if email is new to system: $e');
      // If we can't check, assume it's not new for safety
      return false;
    }
  }

  // Format user type for display
  String _formatUserType(String userType) {
    switch (userType.toLowerCase()) {
      case 'mechanic':
        return 'Mechanic';
      case 'talyer_owner':
        return 'Shop Owner';
      case 'customer':
        return 'Customer';
      case 'admin':
        return 'Administrator';
      default:
        return 'User';
    }
  }

  // Get app download URLs from settings
  Future<Map<String, String>> _getAppDownloadUrls() async {
    try {
      final response = await _supabase.rpc('get_app_download_urls');
      
      if (response != null && response is Map) {
        return Map<String, String>.from(response);
      }
      
      // Fallback URLs
      return {
        'android': 'https://play.google.com/store/apps/details?id=com.RoadAid.mechanic',
        'ios': 'https://apps.apple.com/app/RoadAid-mechanic',
        'web': 'https://app.RoadAid.com',
        'windows': 'https://microsoft.com/store/apps/RoadAid-mechanic',
      };
    } catch (e) {
      print('⚠️ Error getting download URLs, using fallback: $e');
      return {
        'android': 'https://play.google.com/store/apps/details?id=com.RoadAid.mechanic',
        'ios': 'https://apps.apple.com/app/RoadAid-mechanic',
        'web': 'https://app.RoadAid.com',
        'windows': 'https://microsoft.com/store/apps/RoadAid-mechanic',
      };
    }
  }

  // Get email template from settings
  Future<String> _getEmailTemplate(String templateKey) async {
    try {
      final response = await _supabase
          .from('app_settings')
          .select('value')
          .eq('key', templateKey)
          .maybeSingle();

      if (response != null && response['value'] != null) {
        return response['value'];
      }

      // Fallback templates
      switch (templateKey) {
        case 'email_welcome_mechanic_subject':
          return 'Welcome to RoadAid - Your Account Details';
        case 'email_welcome_mechanic_template':
          return '''Hello {{first_name}} {{last_name}},

Welcome to RoadAid! Your mechanic account has been created successfully by {{talyer_owner}}.

Login Details:
Email: {{email}}
Temporary Password: {{password}}

Important: You will be required to change your password on first login for security.

Download the app:
Android: {{android_url}}
iOS: {{ios_url}}
Web: {{web_url}}

If you have any questions, please contact your shop supervisor.

Best regards,
RoadAid Team''';
        case 'email_change_welcome_subject':
          return 'Welcome to RoadAid - Email Updated Successfully!';
        case 'email_change_welcome_template':
          return '''Hello {{full_name}},

Welcome to RoadAid! Your email address has been successfully updated to {{email}}.

We're excited to have you as a {{user_type}} in our community. With RoadAid, you have access to reliable roadside assistance and automotive services at your fingertips.

Get the most out of RoadAid by downloading our apps:

📱 Mobile Apps:
• Android: {{android_url}}
• iOS: {{ios_url}}

💻 Web Application:
• Access from any browser: {{web_url}}

Features available to you:
✓ 24/7 roadside assistance
✓ Trusted mechanic network
✓ Real-time service tracking
✓ Secure payment processing
✓ Service history and receipts

If you have any questions or need assistance, our support team is here to help.

Welcome aboard!
RoadAid Team

---
This email was sent because your email address was updated on your RoadAid account. If you did not make this change, please contact our support team immediately.''';
        default:
          return 'RoadAid System Notification';
      }
    } catch (e) {
      print('⚠️ Error getting email template, using fallback: $e');
      return templateKey.contains('subject') 
          ? 'RoadAid System Notification'
          : 'Welcome to RoadAid! Your account has been created.';
    }
  }

  // Store temporary password for first-time login
  Future<void> _storeTemporaryPassword(String userId, String temporaryPassword) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) throw Exception('No authenticated user');

      // Hash the temporary password (in a real app, use proper bcrypt or similar)
      final passwordHash = temporaryPassword.hashCode.toString();

      await _supabase.from('temporary_passwords').insert({
        'user_id': userId,
        'temporary_password_hash': passwordHash,
        'created_by': currentUser.id,
        'expires_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'is_used': false,
      });

      // Set password change requirement
      await _supabase
          .from('user_profiles')
          .update({
            'password_change_required': true,
            'first_login': true,
          })
          .eq('id', userId);

      print('✅ Temporary password stored for user $userId');
    } catch (e) {
      print('❌ Error storing temporary password: $e');
      throw Exception('Failed to store temporary password: $e');
    }
  }

  // Log email notification
  Future<void> _logEmailNotification({
    required String userId,
    required String emailType,
    required String recipientEmail,
    required String subject,
    required String body,
    Map<String, dynamic>? emailData,
  }) async {
    try {
      await _supabase.from('email_notifications').insert({
        'user_id': userId,
        'email_type': emailType,
        'recipient_email': recipientEmail,
        'subject': subject,
        'body': body,
        'email_data': emailData,
        'delivery_status': 'sent',
      });

      print('✅ Email notification logged for $recipientEmail');
    } catch (e) {
      print('⚠️ Error logging email notification: $e');
      // Don't throw here as it's not critical
    }
  }

  // Update email delivery status
  Future<void> _updateEmailDeliveryStatus(String userId, String emailType, String status) async {
    try {
      await _supabase
          .from('email_notifications')
          .update({'delivery_status': status})
          .eq('user_id', userId)
          .eq('email_type', emailType)
          .order('created_at', ascending: false)
          .limit(1);

      print('✅ Email delivery status updated: $status');
    } catch (e) {
      print('⚠️ Error updating email delivery status: $e');
    }
  }

  // Send email via Supabase Edge Function
  Future<bool> _sendEmailViaSupabase({
    required String to,
    required String subject,
    required String htmlBody,
    required String textBody,
  }) async {
    try {
      // Try to call the Edge Function named 'send-email'.
      // Note: the Supabase project must have this function deployed and
      // configured to forward to an SMTP/transactional provider.
      final response = await _supabase.functions.invoke('send-email', body: {
        'to': to,
        'subject': subject,
        'html': htmlBody,
        'text': textBody,
      });

      // If the function returned a Map-like object, check for error/status fields
      try {
        if (response is Map) {
          final Map respMap = response as Map;
          if (respMap.containsKey('error')) {
            print('❌ send-email function returned error: ${respMap['error']}');
            return false;
          }
          if (respMap.containsKey('status')) {
            final status = respMap['status'];
            if (status == 'ok' || status == 'sent' || status == 200) return true;
          }
        }
      } catch (_) {
        // ignore non-Map responses
      }

      // If we reach here assume success
      return true;
    } catch (e) {
      print('⚠️ Failed to invoke send-email function: $e');
      // Fallback to simulated send so the app flow can continue in dev
      return _simulateEmailSend(to, subject, textBody);
    }
  }

  // Keep a small helper to simulate sending when function is missing
  Future<bool> _simulateEmailSend(String to, String subject, String body) async {
    try {
      print('📧 SIMULATED EMAIL SEND (fallback):');
      print('To: $to');
      print('Subject: $subject');
      print('Body: $body');
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    } catch (e) {
      print('❌ Error during simulated send: $e');
      return false;
    }
  }

  // Format email as HTML
  String _formatEmailAsHTML(String textBody) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>RoadAid</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background-color: #1B5E20; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; background-color: #f9f9f9; }
        .footer { padding: 10px; text-align: center; font-size: 12px; color: #666; }
        .button { display: inline-block; padding: 10px 20px; background-color: #1B5E20; color: white; text-decoration: none; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>RoadAid</h1>
        </div>
        <div class="content">
            <pre style="white-space: pre-wrap; font-family: Arial, sans-serif;">${textBody}</pre>
        </div>
        <div class="footer">
            <p>This is an automated message from RoadAid. Please do not reply to this email.</p>
        </div>
    </div>
</body>
</html>
''';
  }

  // Send password reset email
  Future<bool> sendPasswordResetEmail({
    required String userId,
    required String email,
    required String resetLink,
  }) async {
    try {
      final userProfile = await _supabase
          .from('user_profiles')
          .select('first_name, last_name')
          .eq('id', userId)
          .single();

      final subject = 'RoadAid - Password Reset Request';
      final body = '''Hello ${userProfile['first_name']} ${userProfile['last_name']},

You have requested to reset your password for your RoadAid account.

Click the link below to reset your password:
${resetLink}

If you did not request this password reset, please ignore this email.

This link will expire in 24 hours for security reasons.

Best regards,
RoadAid Team''';

      await _logEmailNotification(
        userId: userId,
        emailType: 'password_reset',
        recipientEmail: email,
        subject: subject,
        body: body,
        emailData: {'reset_link': resetLink},
      );

      final emailSent = await _sendEmailViaSupabase(
        to: email,
        subject: subject,
        htmlBody: _formatEmailAsHTML(body),
        textBody: body,
      );

      if (emailSent) {
        await _updateEmailDeliveryStatus(userId, 'password_reset', 'delivered');
      } else {
        await _updateEmailDeliveryStatus(userId, 'password_reset', 'failed');
      }

      return emailSent;
    } catch (e) {
      print('❌ Error sending password reset email: $e');
      return false;
    }
  }

  // Send profile update notification email
  Future<bool> sendProfileUpdateNotification({
    required String userId,
    required String email,
    required String changes,
  }) async {
    try {
      final userProfile = await _supabase
          .from('user_profiles')
          .select('first_name, last_name')
          .eq('id', userId)
          .single();

      final subject = 'RoadAid - Profile Updated';
      final body = '''Hello ${userProfile['first_name']} ${userProfile['last_name']},

Your RoadAid profile has been updated with the following changes:

${changes}

If you did not make these changes, please contact support immediately.

Best regards,
RoadAid Team''';

      await _logEmailNotification(
        userId: userId,
        emailType: 'profile_update',
        recipientEmail: email,
        subject: subject,
        body: body,
        emailData: {'changes': changes},
      );

      final emailSent = await _sendEmailViaSupabase(
        to: email,
        subject: subject,
        htmlBody: _formatEmailAsHTML(body),
        textBody: body,
      );

      if (emailSent) {
        await _updateEmailDeliveryStatus(userId, 'profile_update', 'delivered');
      } else {
        await _updateEmailDeliveryStatus(userId, 'profile_update', 'failed');
      }

      return emailSent;
    } catch (e) {
      print('❌ Error sending profile update notification: $e');
      return false;
    }
  }

  // Get email history for a user
  Future<List<Map<String, dynamic>>> getEmailHistory(String userId) async {
    try {
      final response = await _supabase
          .from('email_notifications')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting email history: $e');
      return [];
    }
  }

  // Cleanup expired temporary passwords
  Future<int> cleanupExpiredTemporaryPasswords() async {
    try {
      final result = await _supabase.rpc('cleanup_expired_temporary_passwords');
      final deletedCount = result ?? 0;
      print('✅ Cleaned up $deletedCount expired temporary passwords');
      return deletedCount;
    } catch (e) {
      print('⚠️ Error cleaning up expired temporary passwords: $e');
      return 0;
    }
  }

  // Verify temporary password
  Future<bool> verifyTemporaryPassword(String userId, String password) async {
    try {
      final passwordHash = password.hashCode.toString();
      
      final response = await _supabase
          .from('temporary_passwords')
          .select('*')
          .eq('user_id', userId)
          .eq('temporary_password_hash', passwordHash)
          .eq('is_used', false)
          .gt('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('❌ Error verifying temporary password: $e');
      return false;
    }
  }

  // Mark temporary password as used
  Future<void> markTemporaryPasswordAsUsed(String userId) async {
    try {
      await _supabase
          .from('temporary_passwords')
          .update({
            'is_used': true,
            'used_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('is_used', false);

      // Clear password change requirement
      await _supabase
          .from('user_profiles')
          .update({
            'password_change_required': false,
            'first_login': false,
            'last_password_change': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      print('✅ Temporary password marked as used for user $userId');
    } catch (e) {
      print('❌ Error marking temporary password as used: $e');
    }
  }
}










