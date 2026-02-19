import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class MobilePayMongoScreen extends StatefulWidget {
  final String checkoutUrl;
  final String invoiceId;
  final String amount;

  const MobilePayMongoScreen({
    Key? key,
    required this.checkoutUrl,
    required this.invoiceId,
    required this.amount,
  }) : super(key: key);

  @override
  State<MobilePayMongoScreen> createState() => _MobilePayMongoScreenState();
}

class _MobilePayMongoScreenState extends State<MobilePayMongoScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (progress == 100) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
            _checkForPaymentCompletion(url);
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _checkForPaymentCompletion(url);
          },
          onWebResourceError: (WebResourceError error) {
            print('❌ WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  void _checkForPaymentCompletion(String url) {
    print('🌐 Navigation to: $url');
    
    // Check if URL indicates payment completion
    if (url.contains('payment/success') || 
        url.contains('localhost:59325') ||
        url.contains('success') ||
        url.contains('completed')) {
      
      print('✅ Payment completed detected, redirecting...');
      
      // Extract service request ID from URL if present
      final uri = Uri.parse(url);
      final serviceRequestId = uri.queryParameters['request_id'] ?? 
                              uri.queryParameters['service_request_id'];
      
      // Close this screen and go to payment success screen
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(
          '/payment/success',
          arguments: {
            'serviceRequestId': serviceRequestId,
            'invoiceId': widget.invoiceId,
            'amount': widget.amount,
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFE53E3E),
        title: const Text(
          'Complete Payment',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _controller.reload();
            },
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser, color: Colors.white),
            onPressed: _openInExternalBrowser,
          ),
        ],
      ),
      body: Column(
        children: [
          // Payment info header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.payment, color: Colors.blue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PayMongo Payment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Amount: ₱${widget.amount}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Loading indicator
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  const Text('Loading payment page...'),
                ],
              ),
            ),
          
          // WebView
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
          
          // Bottom info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.security, color: Colors.green.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Secure payment powered by PayMongo',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openInExternalBrowser() async {
    try {
      final Uri url = Uri.parse(widget.checkoutUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment page opened in browser'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error opening external browser: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open external browser: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
