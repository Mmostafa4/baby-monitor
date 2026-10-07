import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

Uri hospitalMapUri({double? latitude, double? longitude}) =>
    Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': latitude == null || longitude == null
          ? 'children hospitals near me'
          : 'children hospitals near $latitude,$longitude',
    });

class EmergencyPage extends StatefulWidget {
  const EmergencyPage({super.key});
  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  bool busy = false;
  String message = '';
  Future<void> search() async {
    setState(() {
      busy = true;
      message = '';
    });
    Uri uri = hospitalMapUri();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Location disabled');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Location denied');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 12),
        ),
      );
      uri = hospitalMapUri(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      if (mounted)
        setState(
          () => message = 'تعذر تحديد موقعك. يمكنك فتح البحث العام أو إدخال منطقتك في الخرائط.',
        );
    }
    if (!mounted) return;
    // Same-tab navigation avoids Safari popup blocking after awaiting location.
    try {
      if (!await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_self',
      )) {
        setState(() => message = 'تعذر فتح الخرائط. انسخ رابط البحث أدناه.');
      }
    } catch (_) {
      if (mounted)
        setState(() => message = 'تعذر فتح الخرائط. انسخ رابط البحث أدناه.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'طوارئ',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.red,
        ),
      ),
      const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'اذهب للطوارئ فورًا عند صعوبة التنفس، ازرقاق، تشنج، فقدان وعي، خمول شديد، نزيف، قيء أخضر أو متكرر، جفاف واضح، أو تدهور سريع. لا تنتظر نتيجة التطبيق.',
          ),
        ),
      ),
      FilledButton.icon(
        onPressed: busy ? null : search,
        icon: const Icon(Icons.location_on),
        label: Text(busy ? 'جارٍ تحديد الموقع...' : 'مستشفيات أطفال قريبة'),
      ),
      TextButton(
        onPressed: busy
            ? null
            : () async {
                try {
                  await launchUrl(hospitalMapUri(), webOnlyWindowName: '_self');
                } catch (_) {
                  if (mounted)
                    setState(
                      () => message = 'انسخ الرابط أدناه وافتحه في المتصفح.',
                    );
                }
              },
        child: const Text('فتح الخرائط بدون إذن الموقع'),
      ),
      if (message.isNotEmpty) Text(message),
      SelectableText(hospitalMapUri().toString()),
    ],
  );
}
