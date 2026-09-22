import 'package:flutter/material.dart';

/// A caregiver checklist. It deliberately does not label a cause from audio.
class CryNeedsGuide extends StatelessWidget {
  const CryNeedsGuide({super.key});

  static const List<_CryNeedTip> _tips = [
    _CryNeedTip(
      icon: Icons.restaurant,
      title: 'جوع',
      check:
          'لاحظي إشاراته مثل مصّ اليد، فتح وإغلاق الفم، أو تحريك الرأس بحثًا عن الرضعة. البكاء قد يكون علامة متأخرة للجوع.',
      suggestion:
          'هدّئيه أولًا إذا كان منزعجًا، ثم اعرضي الرضعة المعتادة إذا ظهرت إشارات الجوع وكان موعدها مناسبًا.',
    ),
    _CryNeedTip(
      icon: Icons.air,
      title: 'مغص أو غازات',
      check:
          'راجعي إن كان البكاء يحدث أثناء الرضعة أو بعدها، أو كان الطفل يبدو غير مرتاح. هذه الملاحظات وحدها لا تؤكد المغص.',
      suggestion:
          'جرّبي التجشؤ بلطف مع دعم الرأس والرقبة بالطريقة المناسبة للرضعة. إذا تكرر البكاء أو بدا غير معتاد، استشيري طبيب الطفل.',
    ),
    _CryNeedTip(
      icon: Icons.volume_off,
      title: 'ضيقة أو إرهاق',
      check:
          'راجعي إن كان المكان مزدحمًا بالضوضاء أو الضوء أو الحركة، وهل حان وقت الراحة المعتاد.',
      suggestion:
          'خففي المثيرات حوله ووفري مكانًا هادئًا، ثم لاحظي هل يهدأ. هذا لا يحدد سبب البكاء من الصوت.',
    ),
    _CryNeedTip(
      icon: Icons.favorite,
      title: 'احتياج للقرب والحنان',
      check:
          'بعض الأطفال يحتاجون إلى قرب مقدم الرعاية أو الاطمئنان، وقد يهدؤون عند الحمل أو سماع صوت مألوف.',
      suggestion:
          'جرّبي احتضانه والتحدث إليه بهدوء. لا تهزي الطفل أبدًا؛ وإذا احتجتِ استراحة، ضعيه في مكان آمن واطلبي دعم شخص تثقين به.',
    ),
    _CryNeedTip(
      icon: Icons.accessibility_new,
      title: 'انزعاج جسدي',
      check:
          'افحصي الحفاض، والملابس أو أي شيء يضغط على الجسم، وملاءمة الجو، وانظري إن كانت شعرة أو خيط ملتفًا حول إصبع.',
      suggestion:
          'أزيلي سبب الضغط إن وُجد، وعدّلي الملابس أو البيئة برفق، ثم راقبي حالته.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: ExpansionTile(
          leading: const Icon(Icons.checklist),
          title: const Text('مراجعة احتياجات الطفل'),
          subtitle: const Text('قائمة إرشادية، وليست تحليلًا للصوت'),
          childrenPadding: const EdgeInsetsDirectional.fromSTEB(
            16,
            0,
            16,
            12,
          ),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'لا يحدد التسجيل السبب. راجعي إشارات الطفل وسياق الرضعة والرعاية:',
              ),
            ),
            for (final tip in _tips)
              ExpansionTile(
                leading: Icon(tip.icon),
                title: Text(tip.title),
                childrenPadding: const EdgeInsetsDirectional.fromSTEB(
                  16,
                  0,
                  16,
                  16,
                ),
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'راجعي: ' +
                          tip.check +
                          '\n\nيمكنك تجربة: ' +
                          tip.suggestion,
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
}

class _CryNeedTip {
  final IconData icon;
  final String title;
  final String check;
  final String suggestion;

  const _CryNeedTip({
    required this.icon,
    required this.title,
    required this.check,
    required this.suggestion,
  });
}
