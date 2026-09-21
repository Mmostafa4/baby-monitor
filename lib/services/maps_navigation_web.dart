import 'dart:html' as html;

class MapsNavigationHandle {
  final html.WindowBase? window;

  const MapsNavigationHandle(this.window);
}

MapsNavigationHandle? prepareMapsNavigation() {
  try {
    // Must run synchronously from the user's button tap. A new tab opened
    // only after awaiting GPS is commonly blocked by mobile browsers.
    return MapsNavigationHandle(html.window.open('about:blank', '_blank'));
  } catch (_) {
    return null;
  }
}

Future<bool> openMapsNavigation(
  MapsNavigationHandle? handle,
  Uri uri,
) async {
  try {
    final target = handle?.window;
    if (target != null) {
      target.location.href = uri.toString();
    } else {
      // Top-level navigation still works when the browser blocks a new tab.
      html.window.location.assign(uri.toString());
    }
    return true;
  } catch (_) {
    return false;
  }
}

void cancelMapsNavigation(MapsNavigationHandle? handle) {
  try {
    handle?.window?.close();
  } catch (_) {
    // There is nothing to close when the browser blocks the reserved tab.
  }
}
