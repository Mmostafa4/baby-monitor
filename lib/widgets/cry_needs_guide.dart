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
      videoNote: 'فيديو يوضح إشارات الجوع قبل البكاء؛ ليس دليلًا صوتيًا يثبت الجوع.',
      youtubeUrl: 'https://www.youtube.com/watch?v=cuHbGAXoMgg',
    ),
    _CryNeedTip(
      icon: Icons.air,
      title: 'مغص / غازات',
      description:
          'قد يحدث بكاء طويل يصعب تهدئته، أو تململ أثناء الرضعة أو بعدها. لا يثبت شكل البكاء أو ثني الساقين وجود مغص أو غازات، لذلك راقبي التكرار وباقي حالة الطفل.',
      action:
          'إذا بدا غير مرتاح، احمليه بأمان وراجعي طريقة الرضعة والتجشؤ. عند القيء المتكرر أو الحرارة أو البكاء غير المعتاد، تواصلي مع طبيب الطفل.',
      videoNote: 'فيديو عام عن بكاء الرضع؛ لا يوجد صوت يثبت تشخيص المغص.',
      youtubeUrl: 'https://www.youtube.com/watch?v=7vpHo45ai_g',
    ),
    _CryNeedTip(
      icon: Icons.bubble_chart_outlined,
      title: 'عدم ارتياح',
      description:
          'قد يكون الحفاض مبتلًا، أو الملابس ضيقة، أو الجو حارًا أو باردًا. افحصي هذه الأمور مع الطفل؛ لا يمكن معرفة السبب من صوت البكاء وحده.',
      action:
          'افحصي الحفاض والملابس وحرارة المكان، ثم راقبي إن كان الطفل يهدأ بعد تغيير ما يزعجه.',
      videoNote: 'فيديو يوضح إشارات أن الطفل يحتاج تغيير شيء حوله، لا سببًا مؤكدًا.',
      youtubeUrl: 'https://www.youtube.com/watch?v=qukpL_uHnNQ',
    ),
    _CryNeedTip(
      icon: Icons.favorite_outline,
      title: 'حاجة للحنان',
      description:
          'قد يحتاج الطفل إلى القرب والاحتواء حتى بعد فحص الرضعة والحفاض. لا توجد نغمة بكاء تثبت أنه يطلب الحضن تحديدًا.',
      action:
          'احمليه بلطف مع دعم الرأس والرقبة، وتحدثي معه بهدوء أو جربي التهدئة المعتادة.',
      videoNote: 'فيديو واقعي عن تهدئة طفل يبكي؛ لا يحدد وحده سبب البكاء.',
      youtubeUrl: 'https://www.youtube.com/watch?v=U7L3ppy_VO0',
    ),
    _CryNeedTip(
      icon: Icons.sentiment_dissatisfied_outlined,
      title: 'تضايق / زيادة مؤثرات',
      description:
          'قد يضايق الطفل الضوء الساطع أو الضوضاء أو كثرة الحركة. راقبي إن كان يدير وجهه بعيدًا أو يزداد تململه في المكان المزدحم.',
      action:
          'خففي الضوء والصوت والحركة، واحملي الطفل بهدوء إذا كان يحتاج ذلك. افحصي أيضًا أسباب عدم الارتياح الأخرى.',
      videoNote: 'فيديو يوضح زيادة المؤثرات ومحاولة تهدئة الطفل، لا بصمة صوتية للتضايق.',
      youtubeUrl: 'https://www.youtube.com/watch?v=XtwbXngTjGs',
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
                'اختاري أي زر لقراءة الوصف وفتح فيديو تعليمي خارجي من برنامج Minnesota WIC. الصوت وحده لا يثبت السبب، وهذه الأزرار منفصلة عن فئات نموذج التحليل.',
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
              Text(tip.videoNote),
              const SizedBox(height: 8),
              const Text(
                'الفيديو من برنامج Minnesota WIC التعليمي على YouTube. قد يختلف بكاء كل طفل عن الآخر؛ لا تستخدمي الصوت للتشخيص.',
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
                label: const Text('شاهدي واستمعي إلى الفيديو'),
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
  final String videoNote;
  final String youtubeUrl;

  const _CryNeedTip({
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
    required this.videoNote,
    required this.youtubeUrl,
  });
}
