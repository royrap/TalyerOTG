import 'package:flutter/material.dart';
import '../services/photo_progress_service.dart';

class CustomerPhotoProgressView extends StatefulWidget {
  final String serviceRequestId;

  const CustomerPhotoProgressView({
    Key? key,
    required this.serviceRequestId,
  }) : super(key: key);

  @override
  State<CustomerPhotoProgressView> createState() => _CustomerPhotoProgressViewState();
}

class _CustomerPhotoProgressViewState extends State<CustomerPhotoProgressView>
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _progressPhotos = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadProgressPhotos();
  }

  Future<void> _loadProgressPhotos() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final photos = await PhotoProgressService.instance
          .getServiceProgressPhotos(widget.serviceRequestId);
      
      if (mounted) {
        setState(() {
          _progressPhotos = photos;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading progress photos: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.photo_library_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Service Progress Photos',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _isLoading 
                            ? 'Loading...' 
                            : '${_progressPhotos.length} photos',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _progressPhotos.isEmpty
                    ? const Center(
                        child: Text(
                          'No progress photos yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _progressPhotos.length,
                        itemBuilder: (context, index) {
                          final photo = _progressPhotos[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    photo['phase_title'] ?? 'Service Update',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  if (photo['image_url'] != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        photo['image_url'],
                                        height: 200,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          height: 200,
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child: Icon(Icons.broken_image),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (photo['description'] != null) ...[
                                    const SizedBox(height: 8),
                                    Text(photo['description']),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}