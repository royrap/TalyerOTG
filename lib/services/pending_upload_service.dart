import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Small local queue for failed uploads (signup document uploads).
/// Stores local file paths in SharedPreferences and retries them when the
/// user successfully signs in. Keeps the implementation minimal and
/// safe (no service_role keys).
class PendingUploadService {
  static const _prefsKey = 'pending_uploads_v1';

  /// Enqueue a pending upload.
  /// userId: the auth user id to associate the upload with
  /// localPath: device file path returned by image picker
  /// bucket: storage bucket name
  /// field: the talyer_owner_verifications column to update (e.g. 'business_permit_url')
  static Future<void> enqueuePendingUpload({
    required String userId,
    required String localPath,
    required String bucket,
    required String field,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      List items = raw != null ? jsonDecode(raw) as List : [];
      items.add({
        'user_id': userId,
        'local_path': localPath,
        'bucket': bucket,
        'field': field,
        'created_at': DateTime.now().toIso8601String(),
      });
      await prefs.setString(_prefsKey, jsonEncode(items));
      print('✅ Enqueued pending upload for user $userId, file: $localPath');
    } catch (e) {
      print('⚠️ Failed to enqueue pending upload: $e');
    }
  }

  /// Process queued uploads for a specific user. Attempts to upload each
  /// local file and update the verification row with the public URL.
  static Future<void> processQueueForUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final List items = jsonDecode(raw) as List;
      final remaining = <dynamic>[];

      for (final dynamic it in items) {
        final map = Map<String, dynamic>.from(it as Map);
  // Allow items explicitly for this user, or items created while unauthenticated
  // which were enqueued with user_id == 'unknown'. Those should be processed
  // when the real user signs in and processQueueForUser is called with their id.
  final itemUserId = (map['user_id'] as String?) ?? '';
  if (itemUserId != userId && itemUserId != 'unknown') {
          remaining.add(map);
          continue;
        }

        final localPath = map['local_path'] as String?;
        final bucket = map['bucket'] as String?;
        final field = map['field'] as String?;

        if (localPath == null || bucket == null || field == null) {
          // malformed entry -> drop
          continue;
        }

        try {
          final file = File(localPath);
          if (!await file.exists()) {
            print('⚠️ Pending file not found locally: $localPath');
            // drop this item (user probably cleaned app data)
            continue;
          }

          // Use filename based on user id + timestamp to avoid collisions
          final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}_${file.path.split(Platform.pathSeparator).last}';

          print('⏳ Processing pending upload for user $userId -> $localPath -> bucket: $bucket');
          await Supabase.instance.client.storage.from(bucket).upload(fileName, file);
          final publicUrl = Supabase.instance.client.storage.from(bucket).getPublicUrl(fileName);

          // Persist URL into talyer_owner_verifications by user_id
          try {
            await Supabase.instance.client
                .from('talyer_owner_verifications')
                .update({field: publicUrl, 'updated_at': DateTime.now().toUtc().toIso8601String()})
                .eq('user_id', userId);
            print('✅ Pending upload processed and verification row updated for $userId ($field)');
          } catch (e) {
            print('⚠️ Uploaded file but failed to update verification row: $e');
            // keep item in queue to retry later
            remaining.add(map);
          }
        } catch (e) {
          print('⚠️ Failed to process pending upload for user $userId: $e');
          // keep item to retry later
          remaining.add(map);
        }
      }

      if (remaining.isEmpty) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, jsonEncode(remaining));
      }

      // Check if AI verification should be triggered for this user
      await _triggerAIVerificationIfReady(userId);
    } catch (e) {
      print('⚠️ Error processing pending upload queue: $e');
    }
  }

  /// Trigger AI verification if both documents are uploaded for a user
  static Future<void> _triggerAIVerificationIfReady(String userId) async {
    try {
      print('🤖 Checking if AI verification can be triggered for user $userId...');
      
      // Get the verification record to check if both documents are uploaded
      final verification = await Supabase.instance.client
          .from('talyer_owner_verifications')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (verification == null) {
        print('❌ No verification record found for user $userId');
        return;
      }

      final businessPermitUrl = verification['business_permit_url'] as String?;
      final validIdUrl = verification['valid_id_url'] as String?;

      if (businessPermitUrl != null && businessPermitUrl.isNotEmpty &&
          validIdUrl != null && validIdUrl.isNotEmpty) {
        
        print('✅ Both documents uploaded for user $userId, triggering AI verification...');
        
        // Get user profile for AI verification parameters
        final userProfile = await Supabase.instance.client
            .from('user_profiles')
            .select()
            .eq('id', userId)
            .single();

        // Call the AI document processing function using correct parameter names
        final aiResult = await Supabase.instance.client.rpc(
          'process_talyer_owner_documents_ai',
          params: {
            'user_id': userId,
            'id_image_url': validIdUrl,
            'business_permit_url': businessPermitUrl,
            'business_name': verification['business_name'] ?? '',
            'business_address': verification['business_address'] ?? '',
            'contact_person': '${userProfile['first_name']} ${userProfile['last_name']}',
            'phone_number': userProfile['phone_number'] ?? '',
            'email': userProfile['email'] ?? '',
          },
        );

        final bool isApproved = aiResult['auto_approved'] ?? false;
        final String message = aiResult['next_steps'] ?? 'Processing completed';
        final String verificationId = aiResult['verification_record_id']?.toString() ?? '';

        print('🔍 AI Processing Result for user $userId:');
        print('✅ Auto Approved: $isApproved');
        print('📋 Message: $message');
        print('🆔 Verification ID: $verificationId');

        if (isApproved) {
          print('🎉 User $userId documents auto-approved via AI!');
        } else {
          print('📋 User $userId documents require manual review: $message');
        }

      } else {
        print('⏳ Not all documents uploaded yet for user $userId');
        print('   Business permit: ${businessPermitUrl != null ? "✅" : "❌"}');
        print('   Valid ID: ${validIdUrl != null ? "✅" : "❌"}');
      }
    } catch (e) {
      print('❌ Error triggering AI verification for user $userId: $e');
    }
  }
}










