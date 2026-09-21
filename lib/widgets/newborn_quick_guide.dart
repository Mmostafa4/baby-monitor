import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// General care tips based on public health guidance; not individualized advice.
class NewbornQuickGuide extends StatelessWidget {
  const NewbornQuickGuide({super.key});

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xffedf6ff),
        child: ExpansionTile(
          leading: const Icon(Icons.favorite_outline),
          title: const Text('معلومات عامة لطمأنتك'),
          subtitle: const Text('إرشادات مختصرة ومصادر موثوقة'),
          childrenPadding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 12),
          children: [
            _tip(
              icon: Icons.restaurant_outlined,
              title: 'الرضاعة وملاحظة الإشارات',
              body: 'راقبي إشارات طفلك ووقت آخر رضعة، واتّبعي طريقة التغذية وخطة طبيبه. لا تغيّري الحليب أو تعطي دواء بناءً على تخمين صوتي. إذا واجه صعوبة في الرضاعة، تواصلي مع طبيبه.',
              sourceLabel: 'إرشادات UNICEF Egypt لحديثي الولادة',
              sourceUrl: 'https://www.unicef.org/egypt/ar/newborn-baby-tips',
            ),
            _tip(
              icon: Icons.volunteer_activism_outlined,
              title: 'التهدئة والقرب',
              body: 'قد يساعد الحمل بهدوء، وصوت مألوف، وتقليل الضوضاء والضوء. احتياج الطفل للقرب طبيعي ولا يمكن تأكيده من نغمة البكاء. لا تهزي الطفل أبدًا.',
              sourceLabel: 'UNICEF Parenting: لماذا يبكي الأطفال؟',
              sourceUrl: 'https://www.unicef.org/parenting/child-care/why-babies-cry',
            ),
            _tip(
              icon: Icons.bedtime_outlined,
              title: 'نوم آمن',
              body: 'ضعي الطفل على ظهره في كل مرة ينام فيها، على سطح ثابت ومستوٍ ومخصص للنوم، مع ملاءة مشدودة ومن دون مخدات أو بطانيات رخوة أو ألعاب. مشاركة الغرفة لا تعني مشاركة السرير.',
              sourceLabel: 'CDC: النوم الآمن للرضع',
              sourceUrl: 'https://www.cdc.gov/sudden-infant-death/sleep-safely/index.html',
            ),
            const Padding(
              padding: EdgeInsetsDirectional.fromSTEB(12, 8, 12, 0),
              child: Text(
                'هذه معلومات عامة. إذا لاحظتِ علامة خطر، افتحي قسم «حالات الطوارئ» ولا تنتظري نتيجة التسجيل.',
              ),
            ),
          ],
        ),
      );

  Widget _tip({
    required IconData icon,
    required String title,
    required String body,
    required String sourceLabel,
    required String sourceUrl,
  }) => ExpansionTile(
        leading: Icon(icon),
        title: Text(title),
        childrenPadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(body),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () async {
                await launchUrl(
                  Uri.parse(sourceUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(sourceLabel),
            ),
          ),
        ],
      );
}
