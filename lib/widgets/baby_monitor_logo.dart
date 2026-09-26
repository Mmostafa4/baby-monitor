import 'package:flutter/material.dart';

/// The cartoon baby artwork used as the app's in-screen brand mark.
class BabyMonitorLogo extends StatelessWidget {
  final double size;
  const BabyMonitorLogo({super.key, this.size = 128});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * .23),
        child: Image.asset(
          'assets/branding/baby_monitor_cartoon_icon_512.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          semanticLabel: 'Baby Monitor logo',
        ),
      );
}
