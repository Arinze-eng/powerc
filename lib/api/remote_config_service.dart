// remote_config_service.dart — pulls the admin-controlled config from the
// backend (GET /api/apk/config) so the admin has live control over the app:
// feature flags, branding, announcement, maintenance, and in-app UPDATE.
//
// This app's CURRENT build number MUST match pubspec.yaml's "+N" (here +9).
// Bump kCurrentBuild whenever you bump the version in pubspec.yaml.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

// Keep in sync with pubspec.yaml `version: x.y.z+BUILD`.
// IMPORTANT: this MUST equal the "+N" build in pubspec.yaml. If it lags behind
// (e.g. the APK is released as +9 but this constant still says 7), the server
// will keep reporting "update available" forever and the update dialog will
// flash on every launch even though the user is already on the latest build.
const int kCurrentBuild = 68;
const String kCurrentVersion = '1.5.0';

class RemoteConfig {
  final Map<String, dynamic> raw;
  RemoteConfig(this.raw);

  Map<String, dynamic> get _branding => (raw['branding'] ?? {}) as Map<String, dynamic>;
  Map<String, dynamic> get _features => (raw['features'] ?? {}) as Map<String, dynamic>;
  Map<String, dynamic> get _announcement => (raw['announcement'] ?? {}) as Map<String, dynamic>;
  Map<String, dynamic> get _maintenance => (raw['maintenance'] ?? {}) as Map<String, dynamic>;
  Map<String, dynamic> get _update => (raw['update'] ?? {}) as Map<String, dynamic>;
  Map<String, dynamic> get _limits => (raw['limits'] ?? {}) as Map<String, dynamic>;

  // Branding
  String get appName => (_branding['app_name'] ?? 'WormGPT Agent').toString();
  String get tagline => (_branding['tagline'] ?? '').toString();
  String get primaryColor => (_branding['primary_color'] ?? '#7c3aed').toString();

  // Announcement
  bool get announcementActive => _announcement['active'] == true;
  String get announcementMessage => (_announcement['message'] ?? '').toString();

  // Maintenance
  bool get maintenanceActive => _maintenance['active'] == true;
  String get maintenanceMessage => (_maintenance['message'] ?? '').toString();

  // Feature flags (default true so a missing key never hides a feature)
  bool feature(String key) => _features[key] != false;
  bool get chat => feature('chat');
  bool get wormgpt => feature('wormgpt');
  bool get agent => feature('agent');
  bool get lemon => feature('lemon');
  bool get tools => feature('tools');
  bool get payments => feature('payments');
  bool get signup => feature('signup');
  bool get imageGen => feature('image_gen');
  bool get fileUpload => feature('file_upload');

  // Limits
  int get freeDailyLimit => (_limits['free_daily_limit'] ?? 20) as int;
  int get maxUploadMb => (_limits['max_upload_mb'] ?? 25) as int;

  // Update
  bool get updateAvailable => _update['available'] == true;
  bool get updateRequired => _update['required'] == true;
  bool get updateForced => _update['forced'] == true;
  String get latestVersion => (_update['latest_version'] ?? '').toString();
  int get latestBuild => (_update['latest_build'] ?? 0) as int;
  String get downloadUrl => (_update['download_url'] ?? '').toString();
  String get updateTitle => (_update['title'] ?? 'Update available').toString();
  String get updateMessage => (_update['message'] ?? '').toString();
  String get changelog => (_update['changelog'] ?? '').toString();
}

class RemoteConfigService extends ChangeNotifier {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  RemoteConfig? config;
  bool loaded = false;
  String? error;

  Future<RemoteConfig?> fetch() async {
    try {
      final uri = ApiConfig.uri(
        '/api/apk/config?build=$kCurrentBuild',
      );
      final r = await http
          .get(uri, headers: {'X-Client-Platform': 'apk', 'X-Client-Build': '$kCurrentBuild'})
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        config = RemoteConfig(data);
        error = null;
      } else {
        error = 'HTTP ${r.statusCode}';
      }
    } catch (e) {
      error = e.toString();
      if (kDebugMode) debugPrint('RemoteConfig fetch failed: $e');
    }
    loaded = true;
    notifyListeners();
    return config;
  }
}
