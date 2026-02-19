import 'package:flutter/material.dart';
import '../services/direct_approval_service.dart';

class QuickApprovalWidget extends StatefulWidget {
  const QuickApprovalWidget({super.key});

  @override
  State<QuickApprovalWidget> createState() => _QuickApprovalWidgetState();
}

class _QuickApprovalWidgetState extends State<QuickApprovalWidget> {
  bool _isProcessing = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    // Auto-run approval on widget creation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runApproval();
    });
  }

  Future<void> _runApproval() async {
    setState(() {
      _isProcessing = true;
      _status = 'Starting approval process...';
    });

    try {
      await DirectApprovalService.approveSpecificUsers();
      
      setState(() {
        _status = '✅ SUCCESS: Users approved as Talyer Owners!\n\n'
                 '📧 Approved users:\n'
                 '• paengpineda471@gmail.com\n'
                 '• rafaelpineda471@gmail.com\n\n'
                 '🎉 They can now access Talyer Owner features!';
      });
      
    } catch (e) {
      setState(() {
        _status = '❌ ERROR: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick User Approval'),
        backgroundColor: const Color.fromARGB(255, 176, 12, 1),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Talyer Owner Approval',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            if (_isProcessing) ...[
              const Center(
                child: CircularProgressIndicator(),
              ),
              const SizedBox(height: 20),
            ],
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                _status.isEmpty ? 'Initializing...' : _status,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            if (!_isProcessing) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _runApproval,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 176, 12, 1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Run Approval Again'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Function to show the approval widget
void showQuickApproval(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const QuickApprovalWidget(),
    ),
  );
}










