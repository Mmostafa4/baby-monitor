import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A gentle, age-based weekly prompt. It is not a developmental test or a
/// promise that every child will show a skill on a particular day.
class WeeklyDevelopmentGuide extends StatelessWidget {
  final DateTime dateOfBirth;

  const WeeklyDevelopmentGuide({
    super.key,
    required this.dateOfBirth,
  });

  static const _weeks = <_WeeklyGuideEntry>[
    _WeeklyGuideEntry(
      'التأقلم مع الأيام الأولى',
      'ركزي على الرضاعة حسب خطة الطبيب، إشارات الجوع، والنوم الآمن. سجّلي الأسئلة التي تريدين مناقشتها مع طبيب الطفل.',
      ['ضعي الطفل على ظهره للنوم وعلى سطح ثابت ومستوٍ.', 'لا تضعي مخدات أو بطانيات رخوة أو ألعابًا في مكان النوم.'],
    ),
    _WeeklyGuideEntry(
      'الصوت والوجه المألوف',
      'تحدثي مع طفلك بهدوء، واحمليه بأمان، وراقبي إشارات الجوع والتعب بدل انتظار البكاء فقط.',
      ['استجيبي لإشاراته وتوقفي إذا بدا عليه الإجهاد.', 'لا تهزي الطفل أبدًا؛ اطلبي مساعدة شخص تثقين به إذا احتجتِ استراحة.'],
    ),
    _WeeklyGuideEntry(
      'ملاحظة الرضاعة والرعاية',
      'استخدمي سجل اليوم لمتابعة ما يحدث فعلًا: الرضعات، الحفاضات، النوم، وأي ملاحظة غير معتادة.',
      ['لا تغيّري الحليب أو تعطي دواءً اعتمادًا على التطبيق.', 'شاركي ملخصًا مع الطبيب عند الحاجة.'],
    ),
    _WeeklyGuideEntry(
      'وقت يقظة هادئ',
      'امنحي طفلك دقائق قصيرة من التواصل الهادئ عندما يكون مستيقظًا ومرتاحًا: وجهك، صوتك، أو قراءة بسيطة.',
      ['خففي الضوء والضوضاء إذا ظهرت إشارات التعب.', 'اجعلي أي نشاط على الأرض وتحت مراقبتك المباشرة.'],
    ),
    _WeeklyGuideEntry(
      'النظر والتواصل',
      'قد يبدأ الطفل في متابعة وجهك أو صوتك لفترات قصيرة. اعتبريها فرصًا للتواصل، لا اختبارًا يجب اجتيازه.',
      ['اقتربي لمسافة مريحة وتحدثي بجمل قصيرة.', 'اتركي وقتًا للراحة بين التفاعلات.'],
    ),
    _WeeklyGuideEntry(
      'حركة آمنة أثناء اليقظة',
      'إذا كان الطبيب لا يرى مانعًا، جرّبي وقتًا قصيرًا على البطن فقط أثناء اليقظة وتحت إشرافك؛ النوم يظل على الظهر.',
      ['ابدئي بدقائق قليلة وعلى سطح آمن.', 'أوقفي النشاط إذا تعب الطفل أو انزعج.'],
    ),
    _WeeklyGuideEntry(
      'الاستجابة للصوت والحركة',
      'استمري في الكلام والغناء الهادئ. قد يختلف انتباه الطفل من يوم لآخر، وهذا وحده لا يثبت وجود مشكلة.',
      ['راقبي ما يريح طفلك وسجّلي النمط بدل تفسير صوت واحد.', 'تجنبي الأصوات العالية المفاجئة.'],
    ),
    _WeeklyGuideEntry(
      'التفاعل الاجتماعي',
      'قد تظهر ابتسامات أو أصوات غير البكاء عند بعض الأطفال في هذه الفترة. استجيبي لها وشاركي طفلك الحديث والابتسامة.',
      ['تحدثي إليه وانتظري استجابته.', 'قارني الطفل بنفسه عبر الوقت، لا بطفل آخر.'],
    ),
    _WeeklyGuideEntry(
      'مراجعة مؤشرات عمر شهرين',
      'تذكر CDC أن كثيرًا من الأطفال بعمر شهرين يبتسمون عند الحديث إليهم، ويصدرون أصواتًا غير البكاء، ويتفاعلون مع الأصوات العالية، ويرفعون الرأس أثناء وقت البطن.',
      ['هذه مؤشرات للملاحظة وليست تشخيصًا.', 'إذا كان لديك قلق أو فقد الطفل مهارة، شاركيه مع طبيب الأطفال.'],
    ),
    _WeeklyGuideEntry(
      'تكرار اللعب والتواصل',
      'كرري الأنشطة القصيرة التي يستمتع بها طفلك: الكلام، قراءة الصور، ومتابعة الوجه أو لعبة بسيطة آمنة.',
      ['اختاري وقتًا يكون فيه الطفل يقظًا ومرتاحًا.', 'لا تتركي لعبة أو جسمًا صغيرًا في متناول الرضيع.'],
    ),
    _WeeklyGuideEntry(
      'إيقاع الطفل الخاص',
      'قد تكون هناك أيام أكثر هدوءًا وأيام أكثر انزعاجًا. استمري في الرعاية الأساسية وسجّلي التغير المفاجئ أو المستمر.',
      ['اطلبي المشورة إذا أثار سلوك الطفل قلقك.', 'تعاملي مع أي علامة خطر من خلال قسم الطوارئ، لا من خلال هذه الصفحة.'],
    ),
    _WeeklyGuideEntry(
      'تحضير مراجعة الشهر الثالث',
      'راجعي سجل الرعاية والأسئلة التي ظهرت خلال الأسابيع الماضية، وخذيها معك إلى الزيارة الطبية أو التطعيمات.',
      ['اكتبي مواعيد الرضعات واللقاحات المهمة.', 'لا تستخدمي قائمة التطور بدل فحص الطبيب.'],
    ),
  ];

  int _ageWeeks() {
    final birth = DateTime(dateOfBirth.year, dateOfBirth.month, dateOfBirth.day);
    final today = DateTime.now();
    final current = DateTime(today.year, today.month, today.day);
    if (current.isBefore(birth)) return 0;
    final weeks = current.difference(birth).inDays ~/ 7;
    return weeks < 0 ? 0 : weeks;
  }

  _WeeklyGuideEntry _entryFor(int week) {
    if (week >= _weeks.length) {
      return const _WeeklyGuideEntry(
        'بعد أسابيع حديثي الولادة',
        'استمري في التفاعل الآمن وتابعي قائمة CDC المناسبة للعمر. كل طفل يتطور بإيقاعه، والطبيب هو المرجع عند القلق.',
        ['استخدمي سجل اليوم لتجهيز أسئلتك.', 'راجعي قسم الطوارئ عند وجود علامة خطر.'],
      );
    }
    return _weeks[week];
  }

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final week = _ageWeeks();
    final entry = _entryFor(week);
    final displayedWeek = week + 1;

    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ExpansionTile(
        leading: const Icon(Icons.calendar_view_week_outlined),
        title: const Text('المتابعة الأسبوعية'),
        subtitle: Text('الأسبوع $displayedWeek تقريبًا • ${entry.title}'),
        childrenPadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 14),
        children: [
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'إرشاد عام حسب العمر، وليس اختبار نمو أو تشخيصًا. قد يختلف توقيت كل مهارة من طفل لآخر.',
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(entry.focus),
          ),
          const SizedBox(height: 8),
          for (final bullet in entry.bullets)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(bullet)),
                ],
              ),
            ),
          const Divider(),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => _open(
                    'https://www.cdc.gov/act-early/milestones/2-months.html',
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('مؤشرات CDC لعمر شهرين'),
                ),
                TextButton.icon(
                  onPressed: () => _open(
                    'https://www.cdc.gov/act-early/milestones/4-months.html',
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('مؤشرات CDC لعمر 4 أشهر'),
                ),
                TextButton.icon(
                  onPressed: () => _open(
                    'https://www.cdc.gov/sudden-infant-death/sleep-safely/index.html',
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('النوم الآمن من CDC'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyGuideEntry {
  final String title;
  final String focus;
  final List<String> bullets;

  const _WeeklyGuideEntry(this.title, this.focus, this.bullets);
}
