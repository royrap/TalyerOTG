import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';


class MobilePayMongoScreen extends StatefulWidget {
  final String checkoutUrl;
  final String invoiceId;
  final String amount;
  final VoidCallback? onPaymentCompleted;

  const MobilePayMongoScreen({
    Key? key,
    required this.checkoutUrl,
    required this.invoiceId,
    required this.amount,
    this.onPaymentCompleted,
  }) : super(key: key);

  @override
  State<MobilePayMongoScreen> createState() => _MobilePayMongoScreenState();
}

class _MobilePayMongoScreenState extends State<MobilePayMongoScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _webViewSupported = false;

  @override
  void initState() {
    super.initState();
    _checkWebViewSupport();
  }

  void _checkWebViewSupport() {
    // Check if WebView is supported on current platform
    if (kIsWeb) {
      // On web, we'll use url_launcher instead
      _webViewSupported = false;
      setState(() {
        _isLoading = false;
      });
    } else {
      // On mobile platforms, check if WebView platform is initialized
      try {
        if (WebViewPlatform.instance != null) {
          _webViewSupported = true;
          _initializeWebView();
        } else {
          _webViewSupported = false;
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        print('WebView not supported: $e');
        _webViewSupported = false;
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _initializeWebView() {
    if (!_webViewSupported) return;
    
    try {
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
    } catch (e) {
      print('❌ Failed to initialize WebView: $e');
      setState(() {
        _isLoading = false;
        _webViewSupported = false;
      });
    }
  }

  Widget _buildWebFallback() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.payment,
            size: 80,
            color: Colors.blue.shade400,
          ),
          const SizedBox(height: 24),
          const Text(
            'Payment Page',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'WebView is not supported on this platform.\nClick the button below to open the payment page in your browser.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _openInExternalBrowser,
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Open in Browser'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 176, 12, 1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _handleBackPress,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color.fromARGB(255, 176, 12, 1),
              side: const BorderSide(color: Color.fromARGB(255, 176, 12, 1)),
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _checkForPaymentCompletion(String url) {
    print('🌐 Navigation to: $url');
    
    // Check if URL indicates payment completion
    if (url.contains('payment/success') || 
        url.contains('localhost:59325') ||
        url.contains('success') ||
        url.contains('completed')) {
      
      print('✅ Payment completed detected, redirecting...');
      
      // Trigger callback
      widget.onPaymentCompleted?.call();
      
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

  void _handleBackPress() {
    // Trigger callback before going back
    widget.onPaymentCompleted?.call();
    Navigator.of(context).pop();
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
          onPressed: _handleBackPress,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _webViewSupported && _controller != null
                ? () => _controller!.reload()
                : null,
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
          
          // WebView or Fallback
          Expanded(
            child: _webViewSupported && _controller != null
                ? WebViewWidget(controller: _controller!)
                : _buildWebFallback(),
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
