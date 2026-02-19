import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

enum ServicePhase {
  arrival('arrival', 'Mechanic Arrived', Icons.location_on, Color(0xFF4CAF50)),
  inspection('inspection', 'Vehicle Inspection', Icons.search, Color(0xFF2196F3)),
  diagnosis('diagnosis', 'Problem Diagnosis', Icons.build, Color(0xFFFF9800)),
  workInProgress('work_in_progress', 'Work in Progress', Icons.handyman, Color(0xFF9C27B0)),
  testing('testing', 'Testing & Quality Check', Icons.check_circle, Color(0xFF607D8B)),
  completion('completion', 'Service Completed', Icons.done_all, Color(0xFF4CAF50));

  const ServicePhase(this.id, this.title, this.icon, this.color);
  final String id;
  final String title;
  final IconData icon;
  final Color color;
}

class PhotoProgressService {
  static final PhotoProgressService _instance = PhotoProgressService._internal();
  static PhotoProgressService get instance => _instance;
  PhotoProgressService._internal();

  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();
  
  /// Upload progress photo with description
  Future<Map<String, dynamic>?> uploadProgressPhoto({
    required String serviceRequestId,
    required ServicePhase phase,
    required String description,
    required XFile imageFile,
    String? mechanicId,
  }) async {
    try {
      print('📸 Uploading progress photo for service: $serviceRequestId, phase: ${phase.title}');
      
      // Get current user if mechanicId not provided
      mechanicId ??= _supabase.auth.currentUser?.id;
      if (mechanicId == null) {
        throw Exception('No authenticated user');
      }
      
      // Read image file
      final bytes = await imageFile.readAsBytes();
      final fileName = 'progress_${serviceRequestId}_${phase.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'service_progress/$serviceRequestId/$fileName';
      
      // Upload to Supabase Storage
      final uploadResponse = await _supabase.storage
          .from('service-photos')
          .uploadBinary(filePath, bytes, fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ));
      
      // Get public URL
      final publicUrl = _supabase.storage
          .from('service-photos')
          .getPublicUrl(filePath);
      
      // Store progress record in database
      final progressRecord = await _supabase
          .from('service_progress_photos')
          .insert({
            'service_request_id': serviceRequestId,
            'mechanic_id': mechanicId,
            'phase': phase.id,
            'phase_title': phase.title,
            'description': description,
            'photo_url': publicUrl,
            'file_path': filePath,
            'uploaded_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();
      
      // Update service request with current phase
      await _updateServicePhase(serviceRequestId, phase);
      
      // Notify customer about progress update
      await _notifyCustomerProgressUpdate(serviceRequestId, phase, description, publicUrl);
      
      print('✅ Progress photo uploaded successfully: ${phase.title}');
      
      return {
        'id': progressRecord['id'],
        'photo_url': publicUrl,
        'phase': phase.id,
        'phase_title': phase.title,
        'description': description,
        'uploaded_at': progressRecord['uploaded_at'],
      };
      
    } catch (e) {
      print('❌ Error uploading progress photo: $e');
      throw Exception('Failed to upload progress photo: $e');
    }
  }
  
  /// Get all progress photos for a service request
  Future<List<Map<String, dynamic>>> getServiceProgressPhotos(String serviceRequestId) async {
    try {
      final photos = await _supabase
          .from('service_progress_photos')
          .select('''
            *,
            user_profiles!service_progress_photos_mechanic_id_fkey(
              first_name,
              last_name,
              profile_image_url
            )
          ''')
          .eq('service_request_id', serviceRequestId)
          .order('uploaded_at', ascending: true);
      
      return photos.map((photo) => {
        'id': photo['id'],
        'phase': photo['phase'],
        'phase_title': photo['phase_title'],
        'description': photo['description'],
        'photo_url': photo['photo_url'],
        'uploaded_at': photo['uploaded_at'],
        'mechanic_name': '${photo['user_profiles']['first_name']} ${photo['user_profiles']['last_name']}',
        'mechanic_avatar': photo['user_profiles']['profile_image_url'],
      }).toList();
      
    } catch (e) {
      print('❌ Error getting progress photos: $e');
      return [];
    }
  }
  
  /// Take photo using camera
  Future<XFile?> takeProgressPhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      
      return photo;
    } catch (e) {
      print('❌ Error taking photo: $e');
      return null;
    }
  }
  
  /// Pick photo from gallery
  Future<XFile?> pickProgressPhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      
      return photo;
    } catch (e) {
      print('❌ Error picking photo: $e');
      return null;
    }
  }
  
  /// Update service request with current phase
  Future<void> _updateServicePhase(String serviceRequestId, ServicePhase phase) async {
    try {
      await _supabase.from('service_requests').update({
        'current_phase': phase.id,
        'current_phase_title': phase.title,
        'phase_updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', serviceRequestId);
      
      print('📋 Service phase updated to: ${phase.title}');
    } catch (e) {
      print('❌ Error updating service phase: $e');
    }
  }
  
  /// Notify customer about progress update
  Future<void> _notifyCustomerProgressUpdate(
    String serviceRequestId,
    ServicePhase phase,
    String description,
    String photoUrl,
  ) async {
    try {
      // Get customer ID from service request
      final serviceRequest = await _supabase
          .from('service_requests')
          .select('customer_id')
          .eq('id', serviceRequestId)
          .single();
      
      final customerId = serviceRequest['customer_id'];
      
      // Create notification
      await _supabase.from('notifications').insert({
        'user_id': customerId,
        'title': '📸 Service Update: ${phase.title}',
        'message': description,
        'type': 'service_progress',
        'data': {
          'service_request_id': serviceRequestId,
          'phase': phase.id,
          'photo_url': photoUrl,
        },
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      
      // Send real-time message
      await _supabase.from('messages').insert({
        'request_id': serviceRequestId,
        'sender_id': _supabase.auth.currentUser?.id,
        'receiver_id': customerId,
        'message': '📸 ${phase.title}: $description',
        'message_type': 'progress_update',
        'photo_url': photoUrl,
        'sent_at': DateTime.now().toUtc().toIso8601String(),
      });
      
      print('📨 Customer notified about progress update: ${phase.title}');
      
    } catch (e) {
      print('❌ Error notifying customer: $e');
    }
  }
  
  /// Get current service phase
  Future<ServicePhase?> getCurrentServicePhase(String serviceRequestId) async {
    try {
      final response = await _supabase
          .from('service_requests')
          .select('current_phase')
          .eq('id', serviceRequestId)
          .maybeSingle();
      
      if (response != null && response['current_phase'] != null) {
        final phaseId = response['current_phase'] as String;
        return ServicePhase.values.firstWhere(
          (phase) => phase.id == phaseId,
          orElse: () => ServicePhase.arrival,
        );
      }
      
      return null;
    } catch (e) {
      print('❌ Error getting current phase: $e');
      return null;
    }
  }
  
  /// Get next recommended phase
  ServicePhase? getNextPhase(ServicePhase currentPhase) {
    final currentIndex = ServicePhase.values.indexOf(currentPhase);
    if (currentIndex < ServicePhase.values.length - 1) {
      return ServicePhase.values[currentIndex + 1];
    }
    return null;
  }
  
  /// Delete progress photo
  Future<bool> deleteProgressPhoto(String photoId) async {
    try {
      // Get photo details first
      final photo = await _supabase
          .from('service_progress_photos')
          .select('file_path')
          .eq('id', photoId)
          .single();
      
      // Delete from storage
      await _supabase.storage
          .from('service-photos')
          .remove([photo['file_path']]);
      
      // Delete database record
      await _supabase
          .from('service_progress_photos')
          .delete()
          .eq('id', photoId);
      
      print('🗑️ Progress photo deleted successfully');
      return true;
      
    } catch (e) {
      print('❌ Error deleting progress photo: $e');
      return false;
    }
  }
  
  /// Get progress statistics for a service
  Future<Map<String, dynamic>> getServiceProgressStats(String serviceRequestId) async {
    try {
      final photos = await getServiceProgressPhotos(serviceRequestId);
      
      final phasesCovered = photos.map((p) => p['phase']).toSet().length;
      final totalPhases = ServicePhase.values.length;
      final progressPercentage = ((phasesCovered / totalPhases) * 100).round();
      
      return {
        'total_photos': photos.length,
        'phases_covered': phasesCovered,
        'total_phases': totalPhases,
        'progress_percentage': progressPercentage,
        'last_update': photos.isNotEmpty ? photos.last['uploaded_at'] : null,
      };
      
    } catch (e) {
      print('❌ Error getting progress stats: $e');
      return {
        'total_photos': 0,
        'phases_covered': 0,
        'total_phases': ServicePhase.values.length,
        'progress_percentage': 0,
        'last_update': null,
      };
    }
  }
}