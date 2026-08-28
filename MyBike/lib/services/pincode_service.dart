import 'dart:convert';
import 'dart:io';

/// Result of a successful Indian postal PIN code lookup.
class PincodeLookupResult {
  final String pincode;
  final String state;
  final String city;

  const PincodeLookupResult({
    required this.pincode,
    required this.state,
    required this.city,
  });
}

class PincodeLookupException implements Exception {
  final String message;
  const PincodeLookupException(this.message);

  @override
  String toString() => message;
}

/// Validates and resolves Indian PIN codes via the public India Post API.
class PincodeService {
  static final _pinPattern = RegExp(r'^[1-9][0-9]{5}$');

  static bool isValidFormat(String pincode) =>
      _pinPattern.hasMatch(pincode.trim());

  static Future<PincodeLookupResult> lookup(String pincode) async {
    final code = pincode.trim();
    if (!isValidFormat(code)) {
      throw const PincodeLookupException(
        'Enter a valid 6-digit Indian PIN code.',
      );
    }

    final uri = Uri.parse('https://api.postalpincode.in/pincode/$code');
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != 200) {
        throw const PincodeLookupException(
          'Could not reach the postal service. Check your connection.',
        );
      }
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as List<dynamic>;
      if (json.isEmpty) {
        throw const PincodeLookupException('PIN code not found.');
      }
      final root = json.first as Map<String, dynamic>;
      if (root['Status'] != 'Success') {
        throw PincodeLookupException(
          root['Message'] as String? ?? 'PIN code not found.',
        );
      }
      final offices = root['PostOffice'] as List<dynamic>?;
      if (offices == null || offices.isEmpty) {
        throw const PincodeLookupException('PIN code not found.');
      }
      final office = offices.first as Map<String, dynamic>;
      final state = (office['State'] as String?)?.trim();
      final district = (office['District'] as String?)?.trim();
      if (state == null ||
          state.isEmpty ||
          district == null ||
          district.isEmpty) {
        throw const PincodeLookupException(
          'Could not resolve state and city for this PIN code.',
        );
      }
      return PincodeLookupResult(pincode: code, state: state, city: district);
    } on PincodeLookupException {
      rethrow;
    } on SocketException {
      throw const PincodeLookupException(
        'No internet connection. PIN lookup needs network access.',
      );
    } catch (_) {
      throw const PincodeLookupException(
        'Something went wrong while looking up the PIN code.',
      );
    } finally {
      client.close();
    }
  }
}
