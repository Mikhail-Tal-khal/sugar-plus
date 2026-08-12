import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sugar_plus/config/api_config.dart';
import 'package:sugar_plus/models/glucoscan_result.dart';

class GlucoScanApiException implements Exception {
  final String message;
  GlucoScanApiException(this.message);

  @override
  String toString() => message;
}

class GlucoScanService {
  static Future<GlucoScanResult> analyzeEyeImage(
    File imageFile, {
    String? userId,
  }) async {
    final uri = Uri.parse('${ApiConfig.glucoScanBaseUrl}/api/v1/glucoscan');

    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path))
      ..fields['user_id'] = userId ?? '';

    try {
      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 30),
          );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw GlucoScanApiException(
          'Server error (${response.statusCode}). Please try again.',
        );
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return GlucoScanResult.fromJson(body);
    } on GlucoScanApiException {
      rethrow;
    } catch (e) {
      throw GlucoScanApiException(
        'Could not reach the GlucoScan server. Check your connection and '
        'that the backend URL is configured correctly.\n($e)',
      );
    }
  }
}
