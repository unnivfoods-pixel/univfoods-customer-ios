import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

class MapsLauncher {
  static Future<void> launchMaps(double lat, double lng, String label) async {
    final googleUrl =
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final appleUrl = 'https://maps.apple.com/?q=$label&ll=$lat,$lng';

    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        if (await canLaunchUrl(Uri.parse(appleUrl))) {
          await launchUrl(Uri.parse(appleUrl),
              mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(Uri.parse(googleUrl),
              mode: LaunchMode.externalApplication);
        }
      } else {
        if (await canLaunchUrl(Uri.parse(googleUrl))) {
          await launchUrl(Uri.parse(googleUrl),
              mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch maps';
        }
      }
    } catch (e) {
      debugPrint("Maps Launch Error: $e");
    }
  }

  static Future<void> launchNavigation(double lat, double lng) async {
    final url = 'google.navigation:q=$lat,$lng';
    final fallbackUrl =
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(Uri.parse(fallbackUrl),
            mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Navigation Launch Error: $e");
    }
  }
}
