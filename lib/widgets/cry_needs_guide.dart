import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Practical caregiver observations, not a diagnosis from the cry sound.
class CryNeedsGuide extends StatelessWidget {
  const CryNeedsGuide({super.key});

  static const List<_CryNeedTip> _tips = [
    _CryNeedTip(
      icon: Icons.restaurant,
      title: 'جوع',
      description:
          'راقبي مصّ اليد، فتح وإغلاق الفم، أو تحريك الرأس بحثًا عن الرضعة. البكاء قد يكون علامة متأخرة للجوع؛ راجعي وقت آخر رضعة وإشارات الطفل معًا.',
      action:
          'اهدئي الطفل أولًا إذا كان منزعجًا، ثم اعرضي الرضعة المعتادة إذا ظهرت إشارات الجوع وكان موعدها مناسبًا.',
      youtubeUrl: 'https://www.youtube.com/watch?v=Un7AB7ZBTa0',
    ),
    _CryNeedTip(
      icon: Icons.air,
      title: 'مغص / ألم بطن',
      description:
          'قد يظهر تململ أو ثني للساقين أو بكاء أثناء الرضعة أو بعدها. هذه العلامات لا تثبت المغص ولا تحدد وجود مرض، لذلك راقبي التكرار وباقي حالة الطفل.',
      action:
          'إذا بدا غير مرتاح، احمليه بأمان وراجعي طريقة الرضعة والتجشؤ. عند القيء المتكرر أو الحرارة أو البكاء غير المعتاد، تواصلي مع طبيب الطفل.',
      youtubeUrl:
          'https://www.youtube.com/results?search_query=real+newborn+colic+cry+sound',
    ),
    _CryNeedTip(
      icon: Icons.bubble_chart_outlined,
      title: 'حاجة للتجشؤ',
      description:
          'قد يحدث تململ أو بكاء أثناء الرضعة أو بعدها، وقد يهدأ الطفل بعد حمله في وضع قائم وتجشئته بلطف. ليس كل بكاء بعد الرضعة سببه غازات.',
      action:
          'جرّبي التجشؤ بلطف مع دعم الرأس والرقبة بالطريقة المناسبة للرضعة، وتوقفي إذا بدا الطفل متضايقًا.',
      youtubeUrl:
          'https://www.youtube.com/playlist?list=PLxIdG0gu9NPKllocTIfyuc7P7l_rPVRbp',
    ),
    _CryNeedTip(
      icon: Icons.sentiment_dissatisfied_outlined,
      title: 'انزعاج عام',
      description:
          'راجعي الحفاض، والملابس الضيقة، وحرارة أو برودة المكان، والضوضاء أو الضوء الزائد. قد يكون البكاء متقطعًا ويهدأ بعد إزالة المثير المزعج.',
      action:
          'افحصي الطفل والبيئة بهدوء، خففي المثيرات، ثم راقبي هل تحسن بعد تغيير الحفاض أو الملابس أو المكان.',
      youtubeUrl: 'https://www.youtube.com/watch?v=Z1th785gztQ',
    ),
    _CryNeedTip(
      icon: Icons.bedtime_outlined,
      title: 'تعب / نعاس',
      description:
          'قد تلاحظين التثاؤب أو فرك العينين أو إدارة الوجه أو تململًا وبكاءً متقطعًا. لا يمكن تأكيد التعب من نغمة الصوت وحدها.',
      action:
          'خففي الضوء والضوضاء وابدئي روتين نوم هادئًا. ضعي الطفل للنوم على ظهره فوق سطح ثابت ومستوٍ وخالٍ من الأشياء الرخوة.',
      youtubeUrl: 'https://www.youtube.com/watch?v=qmk8nOcaR0Y',
    ),
  ];

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'أوصاف احتياجات الطفل',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'اختاري أي زر لقراءة الوصف والاستماع إلى مثال صوتي خارجي من YouTube. المثال للتثقيف فقط؛ الصوت وحده لا يثبت السبب.',
              ),
              const SizedBox(height: 12),
              for (final tip in _tips) ...[
                OutlinedButton.icon(
                  onPressed: () => _showTip(context, tip),
                  icon: Icon(tip.icon),
                  label: Text(tip.title),
                  style: OutlinedButton.styleFrom(
                    alignment: AlignmentDirectional.centerStart,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                  ),
                ),
                if (tip != _tips.last) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      );

  Future<void> _showTip(BuildContext context, _CryNeedTip tip) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(tip.icon, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tip.title,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(tip.description),
              const SizedBox(height: 12),
              Text(
                'ماذا يمكنكِ ملاحظته أو فعله؟\n${tip.action}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                'الصوت التالي مثال واقعي منشور على YouTube وليس مرجعًا تشخيصيًا. قد يختلف بكاء كل طفل عن الآخر.',
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  final opened = await launchUrl(
                    Uri.parse(tip.youtubeUrl),
                    mode: LaunchMode.externalApplication,
                  );
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تعذر فتح YouTube على هذا الجهاز.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.ondemand_video_outlined),
                label: const Text('استمعي إلى مثال على YouTube'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CryNeedTip {
  final IconData icon;
  final String title;
  final String description;
  final String action;
  final String youtubeUrl;

  const _CryNeedTip({
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
    required this.youtubeUrl,
  });
}
