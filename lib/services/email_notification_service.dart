import '../services/supabase_service.dart';

class EmailNotificationService {
  static final EmailNotificationService instance = EmailNotificationService._internal();
  EmailNotificationService._internal();

  // Email templates
  static const String WELCOME_CUSTOMER_TEMPLATE = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to RoadAid</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f8f9fa;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            border-bottom: 3px solid #e63946;
            padding-bottom: 20px;
            margin-bottom: 30px;
        }
        .logo {
            width: 80px;
            height: 80px;
            margin: 0 auto 15px;
            background: #e63946;
            border-radius: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-size: 24px;
        }
        h2 {
            color: #e63946;
            margin: 0;
            font-size: 28px;
        }
        .account-details {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            margin: 20px 0;
        }
        .account-details ul {
            margin: 0;
            padding-left: 20px;
        }
        .account-details li {
            margin: 8px 0;
            font-weight: 500;
        }
        .download-section {
            text-align: center;
            margin: 25px 0;
            padding: 20px;
            background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
            border-radius: 8px;
        }
        .download-link {
            display: inline-block;
            padding: 12px 25px;
            background: #28a745;
            color: white;
            text-decoration: none;
            border-radius: 6px;
            font-weight: 600;
            margin: 10px 0;
        }
        .confirmation-section {
            text-align: center;
            margin: 30px 0;
            padding: 25px;
            background: linear-gradient(135deg, #fff3cd 0%, #ffeaa7 100%);
            border-radius: 8px;
            border-left: 4px solid #ffc107;
        }
        .confirm-button {
            display: inline-block;
            padding: 15px 30px;
            background: #e63946;
            color: white;
            text-decoration: none;
            border-radius: 6px;
            font-weight: 600;
            font-size: 16px;
            margin: 15px 0;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #dee2e6;
            color: #6c757d;
            font-style: italic;
        }
        .warning {
            background: #fff3cd;
            padding: 15px;
            border-radius: 6px;
            border-left: 4px solid #ffc107;
            margin: 20px 0;
            font-size: 14px;
        }
        hr {
            border: none;
            height: 1px;
            background: #dee2e6;
            margin: 25px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">🚗</div>
            <h2>Welcome to RoadAid 🚗</h2>
        </div>

        <p><strong>Hi {{email}},</strong></p>

        <p>Thank you for signing up to <strong>RoadAid</strong>! 🎉</p>

        <div class="account-details">
            <p><strong>Here are your account details:</strong></p>
            <ul>
                <li><strong>Name:</strong> {{fullName}}</li>
                <li><strong>Email:</strong> {{email}}</li>
                <li><strong>Account Type:</strong> {{userType}}</li>
                <li><strong>Registration Date:</strong> {{registrationDate}}</li>
            </ul>
        </div>

        <div class="download-section">
            <p><strong>📱 Get the RoadAid mobile app for the best experience:</strong></p>
            <a href="{{appDownloadLink}}" class="download-link">📲 Download RoadAid App</a>
            <p><small>Available for Android and iOS devices</small></p>
        </div>

        <hr>

        <div class="confirmation-section">
            <p><strong>🔐 Before you can start, please confirm your account:</strong></p>
            <a href="{{confirmationURL}}" class="confirm-button">✅ Confirm Your Account</a>
            <p><small>This link will expire in 24 hours for security reasons</small></p>
        </div>

        <div class="warning">
            <p><strong>⚠️ Important:</strong> If you didn't sign up for RoadAid, you can safely ignore this email. Your account will not be activated without email confirmation.</p>
        </div>

        <div class="footer">
            <p>🛠️ Need help? Contact our support team</p>
            <p>– The RoadAid Team</p>
            <p><small>This is an automated email. Please do not reply directly to this message.</small></p>
        </div>
    </div>
</body>
</html>
''';

  static const String WELCOME_TALYER_OWNER_TEMPLATE = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to RoadAid - Talyer Owner</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f8f9fa;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            border-bottom: 3px solid #e63946;
            padding-bottom: 20px;
            margin-bottom: 30px;
        }
        .logo {
            width: 80px;
            height: 80px;
            margin: 0 auto 15px;
            background: #e63946;
            border-radius: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-size: 24px;
        }
        h2 {
            color: #e63946;
            margin: 0;
            font-size: 28px;
        }
        .verification-status {
            background: #d1ecf1;
            padding: 20px;
            border-radius: 8px;
            margin: 20px 0;
            border-left: 4px solid #17a2b8;
        }
        .business-details {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            margin: 20px 0;
        }
        .download-section {
            text-align: center;
            margin: 25px 0;
            padding: 20px;
            background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
            border-radius: 8px;
        }
        .download-link {
            display: inline-block;
            padding: 12px 25px;
            background: #28a745;
            color: white;
            text-decoration: none;
            border-radius: 6px;
            font-weight: 600;
            margin: 10px 0;
        }
        .confirmation-section {
            text-align: center;
            margin: 30px 0;
            padding: 25px;
            background: linear-gradient(135deg, #fff3cd 0%, #ffeaa7 100%);
            border-radius: 8px;
            border-left: 4px solid #ffc107;
        }
        .confirm-button {
            display: inline-block;
            padding: 15px 30px;
            background: #e63946;
            color: white;
            text-decoration: none;
            border-radius: 6px;
            font-weight: 600;
            font-size: 16px;
            margin: 15px 0;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #dee2e6;
            color: #6c757d;
            font-style: italic;
        }
        .success {
            color: #155724;
            background: #d4edda;
            padding: 15px;
            border-radius: 6px;
            border-left: 4px solid #28a745;
            margin: 20px 0;
        }
        hr {
            border: none;
            height: 1px;
            background: #dee2e6;
            margin: 25px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">🏪</div>
            <h2>Welcome to RoadAid Business! 🚗</h2>
        </div>

        <p><strong>Hi {{fullName}},</strong></p>

        <p>Congratulations! Your <strong>Talyer Owner</strong> account has been created successfully! 🎉</p>

        <div class="business-details">
            <p><strong>🏢 Business Account Details:</strong></p>
            <ul>
                <li><strong>Business Name:</strong> {{businessName}}</li>
                <li><strong>Owner Name:</strong> {{fullName}}</li>
                <li><strong>Email:</strong> {{email}}</li>
                <li><strong>Phone:</strong> {{phone}}</li>
                <li><strong>Account Type:</strong> Talyer Owner</li>
                <li><strong>Registration Date:</strong> {{registrationDate}}</li>
            </ul>
        </div>

        <div class="verification-status">
            <p><strong>📋 Document Verification Status:</strong></p>
            <p>{{verificationStatus}}</p>
            <p><small>You will receive a separate notification once your documents are reviewed by our team.</small></p>
        </div>

        <div class="download-section">
            <p><strong>📱 Download the RoadAid Business App:</strong></p>
            <a href="{{appDownloadLink}}" class="download-link">📲 Download Business App</a>
            <p><small>Manage your shop, mechanics, and service requests</small></p>
        </div>

        <hr>

        <div class="confirmation-section">
            <p><strong>🔐 Confirm your email to activate your account:</strong></p>
            <a href="{{confirmationURL}}" class="confirm-button">✅ Confirm Your Account</a>
            <p><small>This link will expire in 24 hours for security reasons</small></p>
        </div>

        <div class="success">
            <p><strong>🚀 What's Next?</strong></p>
            <ul>
                <li>Confirm your email address</li>
                <li>Wait for document verification (if applicable)</li>
                <li>Set up your shop profile</li>
                <li>Add your mechanics and services</li>
                <li>Start accepting service requests</li>
            </ul>
        </div>

        <div class="footer">
            <p>🛠️ Need help? Contact our business support team</p>
            <p>– The RoadAid Business Team</p>
            <p><small>This is an automated email. Please do not reply directly to this message.</small></p>
        </div>
    </div>
</body>
</html>
''';

  /// Send welcome email after successful registration
  Future<void> sendWelcomeEmail({
    required String userId,
    required String email,
    required String firstName,
    required String lastName,
    required String userType,
    required String confirmationURL,
    String? businessName,
    String? phone,
    String? verificationStatus,
  }) async {
    try {
      print('📧 Sending welcome email to: $email');
      print('👤 User Type: $userType');

      // Determine email template and subject based on user type
      String template;
      String subject;
      String fullName = '$firstName $lastName';
      
      if (userType == 'talyer_owner') {
        template = WELCOME_TALYER_OWNER_TEMPLATE;
        subject = 'Welcome to RoadAid Business - Talyer Owner Account Created! 🏪';
      } else {
        template = WELCOME_CUSTOMER_TEMPLATE;
        subject = 'Welcome to RoadAid - Account Created! 🚗';
      }

      // Replace template variables
      String emailBody = template
          .replaceAll('{{fullName}}', fullName)
          .replaceAll('{{email}}', email)
          .replaceAll('{{userType}}', _formatUserType(userType))
          .replaceAll('{{confirmationURL}}', confirmationURL)
          .replaceAll('{{appDownloadLink}}', _getAppDownloadLink())
          .replaceAll('{{registrationDate}}', _formatDate(DateTime.now()));

      // Add business-specific variables for talyer owners
      if (userType == 'talyer_owner') {
        emailBody = emailBody
            .replaceAll('{{businessName}}', businessName ?? 'Not provided')
            .replaceAll('{{phone}}', phone ?? 'Not provided')
            .replaceAll('{{verificationStatus}}', verificationStatus ?? 'Pending review');
      }

      // Store email notification in database
      await _storeEmailNotification(
        userId: userId,
        email: email,
        subject: subject,
        body: emailBody,
        emailType: userType == 'talyer_owner' ? 'welcome_talyer_owner' : 'welcome_customer',
      );

      // Send the actual email (this would integrate with your email service)
      await _sendEmailViaProvider(
        to: email,
        subject: subject,
        htmlBody: emailBody,
      );

      print('✅ Welcome email sent successfully to: $email');

    } catch (e) {
      print('❌ Error sending welcome email: $e');
      throw Exception('Failed to send welcome email: $e');
    }
  }

  /// Store email notification in database for tracking
  Future<void> _storeEmailNotification({
    required String userId,
    required String email,
    required String subject,
    required String body,
    required String emailType,
  }) async {
    try {
      await SupabaseService.client
          .from('email_notifications')
          .insert({
            'recipient_user_id': userId,
            'recipient_email': email,
            'email_type': emailType,
            'subject': subject,
            'body': body,
            'delivery_status': 'pending',
            'priority': 'normal',
            'created_at': DateTime.now().toIso8601String(),
          });

      print('📝 Email notification stored in database');
    } catch (e) {
      print('❌ Error storing email notification: $e');
      // Don't throw here, just log the error
    }
  }

  /// Send email via email service provider
  Future<void> _sendEmailViaProvider({
    required String to,
    required String subject,
    required String htmlBody,
  }) async {
    try {
      // This is a placeholder for actual email service integration
      // You would integrate with services like:
      // - SendGrid
      // - Mailgun  
      // - AWS SES
      // - Supabase Edge Functions
      
      print('📤 Sending email via provider...');
      print('📧 To: $to');
      print('📋 Subject: $subject');
      
      // For now, we'll simulate successful sending
      // In production, replace this with actual email service call
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Update delivery status to sent
      await SupabaseService.client
          .from('email_notifications')
          .update({
            'delivery_status': 'sent',
            'sent_at': DateTime.now().toIso8601String(),
          })
          .eq('recipient_email', to)
          .eq('subject', subject);

      print('✅ Email sent successfully via provider');

    } catch (e) {
      print('❌ Error sending email via provider: $e');
      
      // Update delivery status to failed
      await SupabaseService.client
          .from('email_notifications')
          .update({
            'delivery_status': 'failed',
            'error_message': e.toString(),
          })
          .eq('recipient_email', to)
          .eq('subject', subject);
      
      throw Exception('Failed to send email: $e');
    }
  }

  /// Format user type for display
  String _formatUserType(String userType) {
    switch (userType) {
      case 'customer':
        return 'Customer';
      case 'talyer_owner':
        return 'Talyer Owner';
      case 'mechanic':
        return 'Mechanic';
      case 'admin':
        return 'Administrator';
      default:
        return userType;
    }
  }

  /// Get app download link
  String _getAppDownloadLink() {
    // Return the actual app download link
    // This could be dynamic based on user's device/platform
    return 'https://RoadAid-app-download.com';
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Send email verification reminder
  Future<void> sendEmailVerificationReminder({
    required String email,
    required String confirmationURL,
  }) async {
    try {
      const String subject = 'RoadAid - Please Verify Your Email Address 📧';
      const String body = '''
        <p>Hi there!</p>
        <p>You recently signed up for RoadAid but haven't verified your email address yet.</p>
        <p>Please click the link below to verify your email and activate your account:</p>
        <p><a href="{{confirmationURL}}" style="background:#e63946;color:white;padding:10px 20px;text-decoration:none;border-radius:5px;">Verify Email Address</a></p>
        <p>This link will expire in 24 hours.</p>
        <p>If you didn't sign up for RoadAid, please ignore this email.</p>
        <p>– The RoadAid Team</p>
      ''';

      String emailBody = body.replaceAll('{{confirmationURL}}', confirmationURL);

      await _sendEmailViaProvider(
        to: email,
        subject: subject,
        htmlBody: emailBody,
      );

      print('✅ Email verification reminder sent to: $email');

    } catch (e) {
      print('❌ Error sending email verification reminder: $e');
      throw Exception('Failed to send email verification reminder: $e');
    }
  }
}










