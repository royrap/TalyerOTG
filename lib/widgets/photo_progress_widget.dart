import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/photo_progress_service.dart';

class PhotoProgressWidget extends StatefulWidget {
  final String serviceRequestId;
  final VoidCallback? onPhotoUploaded;

  const PhotoProgressWidget({
    Key? key,
    required this.serviceRequestId,
    this.onPhotoUploaded,
  }) : super(key: key);

  @override
  State<PhotoProgressWidget> createState() => _PhotoProgressWidgetState();
}

class _PhotoProgressWidgetState extends State<PhotoProgressWidget>
    with SingleTickerProviderStateMixin {
  ServicePhase? _currentPhase;
  List<ServicePhase> _availablePhases = ServicePhase.values;
  bool _isUploading = false;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _loadCurrentPhase();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentPhase() async {
    final currentPhase = await PhotoProgressService.instance
        .getCurrentServicePhase(widget.serviceRequestId);
    
    if (mounted) {
      setState(() {
        _currentPhase = currentPhase;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.3),
              spreadRadius: 0,
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Progress Updates',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Share photos with your customer',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Progress Phases
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Service Phases',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Phase Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _availablePhases.length,
                    itemBuilder: (context, index) {
                      final phase = _availablePhases[index];
                      final isCurrentPhase = _currentPhase == phase;
                      final isPastPhase = _currentPhase != null && 
                          _availablePhases.indexOf(phase) < _availablePhases.indexOf(_currentPhase!);
                      
                      return _buildPhaseButton(phase, isCurrentPhase, isPastPhase);
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseButton(ServicePhase phase, bool isCurrentPhase, bool isPastPhase) {
    Color backgroundColor;
    Color textColor;
    IconData icon;
    
    if (isCurrentPhase) {
      backgroundColor = Colors.white.withOpacity(0.9);
      textColor = phase.color;
      icon = phase.icon;
    } else if (isPastPhase) {
      backgroundColor = Colors.green.withOpacity(0.3);
      textColor = Colors.white;
      icon = Icons.check;
    } else {
      backgroundColor = Colors.white.withOpacity(0.2);
      textColor = Colors.white70;
      icon = phase.icon;
    }
    
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isUploading ? null : () => _showPhotoOptions(phase),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: textColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  phase.title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhotoOptions(ServicePhase phase) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    phase.icon,
                    size: 40,
                    color: phase.color,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    phase.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Add a photo to show your progress',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            // Options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildOptionButton(
                    icon: Icons.camera_alt,
                    title: 'Take Photo',
                    subtitle: 'Use camera to take a new photo',
                    onTap: () {
                      Navigator.pop(context);
                      _takePhoto(phase);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildOptionButton(
                    icon: Icons.photo_library,
                    title: 'Choose from Gallery',
                    subtitle: 'Select an existing photo',
                    onTap: () {
                      Navigator.pop(context);
                      _pickPhoto(phase);
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.purple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _takePhoto(ServicePhase phase) async {
    final photo = await PhotoProgressService.instance.takeProgressPhoto();
    if (photo != null) {
      _showDescriptionDialog(phase, photo);
    }
  }

  Future<void> _pickPhoto(ServicePhase phase) async {
    final photo = await PhotoProgressService.instance.pickProgressPhoto();
    if (photo != null) {
      _showDescriptionDialog(phase, photo);
    }
  }

  void _showDescriptionDialog(ServicePhase phase, XFile photo) {
    final TextEditingController descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${phase.title} Update'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo Preview
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: FileImage(File(photo.path)),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Description Input
            const Text(
              'Add a description:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                hintText: 'Describe what you\'re doing...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _uploadPhoto(phase, photo, descriptionController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: phase.color,
            ),
            child: const Text('Send Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadPhoto(ServicePhase phase, XFile photo, String description) async {
    setState(() {
      _isUploading = true;
    });
    
    try {
      await PhotoProgressService.instance.uploadProgressPhoto(
        serviceRequestId: widget.serviceRequestId,
        phase: phase,
        description: description.isEmpty ? 'Progress update for ${phase.title}' : description,
        imageFile: photo,
      );
      
      // Update current phase
      setState(() {
        _currentPhase = phase;
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📸 ${phase.title} update sent to customer!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Callback
      widget.onPhotoUploaded?.call();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to send update: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }
}