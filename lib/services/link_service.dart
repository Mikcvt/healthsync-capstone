import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens web pages for the app (Terms, Privacy). The only place that calls
/// url_launcher, so screens stay free of plugin calls.
class LinkService {
  static final LinkService _instance = LinkService._();
  factory LinkService() => _instance;
  LinkService._();

  /// Opens [url] in an in-app browser tab (Chrome Custom Tabs on Android): the
  /// page slides up over HealthSync with a close button, so the user never
  /// leaves the app. Falls back to the default browser. Returns false when
  /// nothing could open it, so the caller can show the address instead.
  Future<bool> open(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
        return true;
      }
    } catch (e) {
      debugPrint('LinkService in-app open failed: $e');
    }
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('LinkService external open failed: $e');
      return false;
    }
  }
}
