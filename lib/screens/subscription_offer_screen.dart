import 'package:flutter/material.dart';

/// Subscription UI contract. Real billing must be connected to Google Play
/// Billing and App Store subscriptions; never unlock features from this local
/// value alone.
class SubscriptionOfferScreen extends StatelessWidget {
  final int launchPriceEgp;
  final VoidCallback? onStartPurchase;

  const SubscriptionOfferScreen({
    super.key,
    this.launchPriceEgp = 100,
    this.onStartPurchase,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الاشتراك')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('جرّب Baby Monitor مجانًا لمدة 7 أيام', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('بعد التجربة: اشتراك سنوي بسعر العرض الحالي $launchPriceEgp جنيه مصري. قد يتغير السعر مستقبلًا، وسيظهر السعر النهائي قبل الدفع.'),
              const SizedBox(height: 20),
              const Text('يمكنك الإلغاء من Google Play أو App Store قبل نهاية التجربة لتجنب التجديد التلقائي.'),
              const Spacer(),
              FilledButton(onPressed: onStartPurchase, child: const Text('ابدأ التجربة المجانية')),
              const SizedBox(height: 12),
              const Text('الدفع الحقيقي يحتاج ربط المتجر والتحقق من الإيصال عبر الخادم.', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
