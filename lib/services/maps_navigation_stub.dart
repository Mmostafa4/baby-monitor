import 'package:url_launcher/url_launcher.dart';

class MapsNavigationHandle {}

MapsNavigationHandle? prepareMapsNavigation() => null;

Future<bool> openMapsNavigation(
  MapsNavigationHandle? handle,
  Uri uri,
) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

void cancelMapsNavigation(MapsNavigationHandle? handle) {}
