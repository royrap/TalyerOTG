import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

class QREncryptionService {
  static final QREncryptionService _instance = QREncryptionService._internal();
  static QREncryptionService get instance => _instance;
  QREncryptionService._internal();

  // Generate a secure key for encryption (in production, use a proper key management system)
  static const String _secretKey = 'RoadAid_qr_secret_key_2024_secure!'; // 32 chars
  late final Key _key;
  late final Encrypter _encrypter;

  void initialize() {
    _key = Key.fromBase64(base64.encode(_secretKey.codeUnits).substring(0, 44) + '==');
    _encrypter = Encrypter(AES(_key));
  }

  /// Generate encrypted QR data with job information and expiration
  String generateSecureQRData({
    required String requestId,
    required String customerId,
    required String mechanicId,
    required DateTime expiresAt,
  }) {
    try {
      // Create QR payload with all necessary data
      final qrPayload = {
        'rid': requestId,        // Request ID
        'cid': customerId,       // Customer ID  
        'mid': mechanicId,       // Mechanic ID
        'exp': expiresAt.millisecondsSinceEpoch, // Expiration timestamp
        'iat': DateTime.now().millisecondsSinceEpoch, // Issued at timestamp
        'nonce': _generateNonce(), // Random nonce for uniqueness
      };

      final jsonPayload = json.encode(qrPayload);
      print('🔐 QR Payload: $jsonPayload');

      // Encrypt the payload
      final iv = IV.fromSecureRandom(16);
      final encrypted = _encrypter.encrypt(jsonPayload, iv: iv);
      
      // Combine IV and encrypted data for transmission
      final qrData = {
        'data': encrypted.base64,
        'iv': iv.base64,
        'version': 'v1.0', // For future compatibility
      };

      final encryptedQRString = base64.encode(utf8.encode(json.encode(qrData)));
      print('🔐 Generated secure QR data: ${encryptedQRString.substring(0, 20)}...');
      
      return encryptedQRString;
    } catch (e) {
      print('❌ Error generating secure QR data: $e');
      throw Exception('Failed to generate secure QR code');
    }
  }

  /// Decrypt and verify QR code data
  Map<String, dynamic>? decryptAndVerifyQRData(String encryptedQRString) {
    try {
      print('🔍 Decrypting QR data: ${encryptedQRString.substring(0, 20)}...');

      // Decode the base64 QR string
      final decodedBytes = base64.decode(encryptedQRString);
      final decodedString = utf8.decode(decodedBytes);
      final qrContainer = json.decode(decodedString) as Map<String, dynamic>;

      // Extract IV and encrypted data
      final iv = IV.fromBase64(qrContainer['iv']);
      final encrypted = Encrypted.fromBase64(qrContainer['data']);

      // Decrypt the payload
      final decrypted = _encrypter.decrypt(encrypted, iv: iv);
      final qrPayload = json.decode(decrypted) as Map<String, dynamic>;

      print('🔍 Decrypted QR payload: $qrPayload');

      // Verify expiration
      final expirationTime = DateTime.fromMillisecondsSinceEpoch(qrPayload['exp']);
      if (DateTime.now().isAfter(expirationTime)) {
        print('❌ QR code has expired: $expirationTime');
        return null;
      }

      // Verify issued time (not too old, not in future)
      final issuedTime = DateTime.fromMillisecondsSinceEpoch(qrPayload['iat']);
      final now = DateTime.now();
      if (issuedTime.isAfter(now.add(Duration(minutes: 5))) || 
          issuedTime.isBefore(now.subtract(Duration(hours: 24)))) {
        print('❌ QR code has invalid issue time: $issuedTime');
        return null;
      }

      print('✅ QR code decrypted and verified successfully');
      return {
        'requestId': qrPayload['rid'],
        'customerId': qrPayload['cid'],
        'mechanicId': qrPayload['mid'],
        'expiresAt': expirationTime,
        'issuedAt': issuedTime,
        'nonce': qrPayload['nonce'],
      };
    } catch (e) {
      print('❌ Error decrypting QR data: $e');
      return null;
    }
  }

  /// Generate a random nonce for QR uniqueness
  String _generateNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    return base64.encode(bytes);
  }

  /// Generate a hash for audit logging
  String generateQRHash(String qrData) {
    final bytes = utf8.encode(qrData);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
