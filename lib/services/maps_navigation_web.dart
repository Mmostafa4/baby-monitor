import 'dart:html' as html;

class MapsNavigationHandle {}

MapsNavigationHandle? prepareMapsNavigation() => null;

Future<bool> openMapsNavigation(
  MapsNavigationHandle? handle,
  Uri uri,
) async {
  try {
    // Navigate the current page to avoid Safari popup blocking or suspending
    // an installed web app while it waits for a location fix.
    html.window.location.assign(uri.toString());
    return true;
  } catch (_) {
    return false;
  }
}

void cancelMapsNavigation(MapsNavigationHandle? handle) {}
