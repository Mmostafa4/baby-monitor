import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Brand mark: cartoon baby in a diaper sending sound waves to a smiling mother's ear.
class BabyMonitorLogo extends StatelessWidget {
  final double size;
  const BabyMonitorLogo({super.key, this.size = 128});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * .23),
        child: SvgPicture.asset(
          'assets/branding/baby_monitor_logo.svg',
          width: size,
          height: size,
          semanticsLabel: 'Baby Monitor logo',
        ),
      );
}
