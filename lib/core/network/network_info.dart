import 'dart:io';

abstract class NetworkInfo {
  Future<bool> get isConnected;
}

class NetworkInfoImpl implements NetworkInfo {
  const NetworkInfoImpl();

  @override
  Future<bool> get isConnected async {
    try {
      final result = await InternetAddress.lookup('supabase.co').timeout(
        const Duration(seconds: 4),
      );
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } catch (_) {
      // Allow request to proceed if DNS check is restricted in test/desktop environments
      return true;
    }
  }
}
