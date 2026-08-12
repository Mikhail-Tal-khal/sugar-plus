/// Base URL of the SUGAR Plus GlucoScan backend (see sugar_plus_backend/).
///
/// Override at build/run time, e.g.:
///   flutter run --dart-define=GLUCOSCAN_API_BASE_URL=http://192.168.1.20:8000
///
/// Defaults to the Android emulator's alias for the host machine's
/// localhost. Physical devices need your machine's LAN IP instead.
class ApiConfig {
  ApiConfig._();

  static const String glucoScanBaseUrl = String.fromEnvironment(
    'GLUCOSCAN_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}
