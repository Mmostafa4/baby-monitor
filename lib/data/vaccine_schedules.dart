/// Age-based vaccine records for the selected country.
///
/// The Egypt routine schedule was cross-checked against the Egyptian Health
/// Council's child-immunization table (last update shown on the source:
/// 27 February 2025), the Ministry of Health schedule published in 2026,
/// and UNICEF Egypt's routine-program guidance. These are reminders, not a
/// replacement for the child's official vaccine card. Product combinations,
/// catch-up rules, campaigns, and eligibility vary by country and by child.
class VaccineScheduleDose {
  final int ageMonths;
  final String code;
  final String? doseLabel;
  final String? timingNote;
  final int? daysAfterBirth;
  final String? ageLabelOverride;
  final bool conditional;
  final bool isSupplement;

  const VaccineScheduleDose(
    this.ageMonths,
    this.code, {
    this.doseLabel,
    this.timingNote,
    this.daysAfterBirth,
    this.ageLabelOverride,
    this.conditional = false,
    this.isSupplement = false,
  });

  String get id => '$ageMonths-$code';
}

class VaccineInfo {
  final String name;
  final String protectsAgainst;
  final String expectedSideEffects;
  final String rareWarnings;
  final String? sourceUrl;

  const VaccineInfo({
    required this.name,
    required this.protectsAgainst,
    required this.expectedSideEffects,
    required this.rareWarnings,
    this.sourceUrl,
  });
}

class AdditionalVaccineRecommendation {
  final String code;
  final String name;
  final int? firstReviewAgeMonths;
  final String timing;
  final String scheduleNote;
  final String purpose;

  const AdditionalVaccineRecommendation({
    required this.code,
    required this.name,
    required this.firstReviewAgeMonths,
    required this.timing,
    required this.scheduleNote,
    required this.purpose,
  });
}

const Map<String, String> vaccineCountryCodes = {
  'مصر': 'EGY',
  'السعودية': 'SAU',
  'الإمارات': 'ARE',
  'الولايات المتحدة': 'USA',
  'المملكة المتحدة': 'GBR',
  'فرنسا': 'FRA',
  'ألمانيا': 'DEU',
  'الهند': 'IND',
  'الصين': 'CHN',
  'تركيا': 'TUR',
};

const Map<String, List<VaccineScheduleDose>> vaccineSchedules = {
  'مصر': [
    VaccineScheduleDose(
      0,
      'HEPB',
      doseLabel: 'جرعة الميلاد',
      timingNote: 'خلال أول 24 ساعة من الميلاد',
    ),
    VaccineScheduleDose(
      0,
      'OPV',
      doseLabel: 'الجرعة الصفرية',
      timingNote: 'خلال الأسبوع الأول من الميلاد',
    ),
    VaccineScheduleDose(
      0,
      'BCG',
      doseLabel: 'جرعة الميلاد',
      timingNote: 'عند الميلاد أو حسب تعليمات مكتب الصحة',
    ),
    VaccineScheduleDose(2, 'OPV', doseLabel: 'الجرعة الأولى'),
    VaccineScheduleDose(2, 'PENTA', doseLabel: 'الجرعة الأولى'),
    VaccineScheduleDose(2, 'IPV', doseLabel: 'الجرعة الأولى'),
    VaccineScheduleDose(4, 'OPV', doseLabel: 'الجرعة الثانية'),
    VaccineScheduleDose(4, 'PENTA', doseLabel: 'الجرعة الثانية'),
    VaccineScheduleDose(4, 'IPV', doseLabel: 'الجرعة الثانية'),
    VaccineScheduleDose(6, 'OPV', doseLabel: 'الجرعة الثالثة'),
    VaccineScheduleDose(6, 'PENTA', doseLabel: 'الجرعة الثالثة'),
    VaccineScheduleDose(6, 'IPV', doseLabel: 'الجرعة الثالثة'),
    VaccineScheduleDose(
      6,
      'VITAMIN_A_100K',
      doseLabel: 'جرعة فيتامين أ',
      timingNote: 'مكمل غذائي وليس تطعيمًا',
      isSupplement: true,
    ),
    VaccineScheduleDose(9, 'OPV', doseLabel: 'الجرعة الرابعة'),
    VaccineScheduleDose(12, 'OPV', doseLabel: 'الجرعة الخامسة'),
    VaccineScheduleDose(12, 'MMR', doseLabel: 'جرعة السنة'),
    VaccineScheduleDose(
      12,
      'VITAMIN_A_200K',
      doseLabel: 'جرعة فيتامين أ',
      timingNote: 'مكمل غذائي وليس تطعيمًا',
      isSupplement: true,
    ),
    VaccineScheduleDose(18, 'OPV', doseLabel: 'الجرعة المنشطة'),
    VaccineScheduleDose(18, 'MMR', doseLabel: 'الجرعة المنشطة'),
    VaccineScheduleDose(18, 'DTP', doseLabel: 'الجرعة المنشطة'),
    VaccineScheduleDose(
      18,
      'VITAMIN_A_200K',
      doseLabel: 'جرعة فيتامين أ',
      timingNote: 'مكمل غذائي وليس تطعيمًا',
      isSupplement: true,
    ),
  ],
  'السعودية': [
    VaccineScheduleDose(0, 'HEPB'),
    VaccineScheduleDose(2, 'HEXAVALENT'),
    VaccineScheduleDose(2, 'PCV'),
    VaccineScheduleDose(2, 'ROTA'),
    VaccineScheduleDose(4, 'HEXAVALENT'),
    VaccineScheduleDose(4, 'PCV'),
    VaccineScheduleDose(4, 'ROTA'),
    VaccineScheduleDose(6, 'HEXAVALENT'),
    VaccineScheduleDose(6, 'PCV'),
    VaccineScheduleDose(6, 'ROTA'),
    VaccineScheduleDose(6, 'BCG', timingNote: 'ضمن عمر 6–12 شهرًا بحسب الجدول الوطني'),
    VaccineScheduleDose(6, 'INFLUENZA', conditional: true),
    VaccineScheduleDose(6, 'OPV'),
    VaccineScheduleDose(9, 'MEASLES'),
    VaccineScheduleDose(9, 'MEN_ACWY'),
    VaccineScheduleDose(12, 'MMR'),
    VaccineScheduleDose(12, 'MEN_ACWY'),
    VaccineScheduleDose(12, 'PCV'),
    VaccineScheduleDose(12, 'OPV'),
    VaccineScheduleDose(18, 'DTP_HIB'),
    VaccineScheduleDose(18, 'HEPA'),
    VaccineScheduleDose(18, 'MMR'),
    VaccineScheduleDose(18, 'OPV'),
    VaccineScheduleDose(18, 'VARICELLA'),
  ],
  'الإمارات': [
    VaccineScheduleDose(0, 'HEPB'),
    VaccineScheduleDose(0, 'BCG'),
    VaccineScheduleDose(2, 'HEXAVALENT'),
    VaccineScheduleDose(2, 'PCV'),
    VaccineScheduleDose(2, 'ROTA'),
    VaccineScheduleDose(4, 'HEXAVALENT'),
    VaccineScheduleDose(4, 'PCV'),
    VaccineScheduleDose(4, 'ROTA'),
    VaccineScheduleDose(6, 'PENTA'),
    VaccineScheduleDose(6, 'OPV'),
    VaccineScheduleDose(6, 'INFLUENZA', conditional: true),
    VaccineScheduleDose(12, 'MMR'),
    VaccineScheduleDose(12, 'MEN_ACWY'),
    VaccineScheduleDose(12, 'VARICELLA'),
    VaccineScheduleDose(18, 'DTP_HIB_IPV'),
    VaccineScheduleDose(18, 'MMR'),
    VaccineScheduleDose(18, 'PCV'),
    VaccineScheduleDose(18, 'OPV'),
  ],
  'الولايات المتحدة': [
    VaccineScheduleDose(0, 'HEPB'),
    VaccineScheduleDose(1, 'HEPB'),
    VaccineScheduleDose(2, 'US_CORE'),
    VaccineScheduleDose(2, 'PCV'),
    VaccineScheduleDose(2, 'ROTA'),
    VaccineScheduleDose(4, 'US_CORE'),
    VaccineScheduleDose(4, 'PCV'),
    VaccineScheduleDose(4, 'ROTA'),
    VaccineScheduleDose(6, 'US_CORE'),
    VaccineScheduleDose(6, 'PCV'),
    VaccineScheduleDose(6, 'ROTA'),
    VaccineScheduleDose(12, 'HIB'),
    VaccineScheduleDose(12, 'HEPA'),
    VaccineScheduleDose(12, 'MMR'),
    VaccineScheduleDose(12, 'PCV'),
    VaccineScheduleDose(12, 'VARICELLA'),
    VaccineScheduleDose(15, 'DTP'),
    VaccineScheduleDose(18, 'HEPA'),
  ],
  'المملكة المتحدة': [
    VaccineScheduleDose(2, 'HEXAVALENT', daysAfterBirth: 56, ageLabelOverride: '8 أسابيع'),
    VaccineScheduleDose(2, 'ROTA', daysAfterBirth: 56, ageLabelOverride: '8 أسابيع'),
    VaccineScheduleDose(2, 'MEN_B', daysAfterBirth: 56, ageLabelOverride: '8 أسابيع'),
    VaccineScheduleDose(3, 'HEXAVALENT', daysAfterBirth: 84, ageLabelOverride: '12 أسبوعًا'),
    VaccineScheduleDose(3, 'ROTA', daysAfterBirth: 84, ageLabelOverride: '12 أسبوعًا'),
    VaccineScheduleDose(3, 'MEN_B', daysAfterBirth: 84, ageLabelOverride: '12 أسبوعًا'),
    VaccineScheduleDose(4, 'HEXAVALENT', daysAfterBirth: 112, ageLabelOverride: '16 أسبوعًا'),
    VaccineScheduleDose(4, 'PCV', daysAfterBirth: 112, ageLabelOverride: '16 أسبوعًا'),
    VaccineScheduleDose(12, 'MMRV', timingNote: 'التركيبة والموعد يعتمدان على تاريخ الميلاد'),
    VaccineScheduleDose(12, 'PCV'),
    VaccineScheduleDose(12, 'MEN_B'),
    VaccineScheduleDose(18, 'HEXAVALENT', timingNote: 'جرعة مرحلية لبعض مواليد 2024 وما بعده'),
    VaccineScheduleDose(18, 'MMRV', timingNote: 'التركيبة والموعد يعتمدان على تاريخ الميلاد'),
    VaccineScheduleDose(24, 'INFLUENZA', conditional: true),
  ],
  'فرنسا': [
    VaccineScheduleDose(1, 'BCG', conditional: true, timingNote: 'للفئات المعرّضة للخطر فقط'),
    VaccineScheduleDose(2, 'HEXAVALENT'),
    VaccineScheduleDose(2, 'PCV'),
    VaccineScheduleDose(2, 'ROTA'),
    VaccineScheduleDose(3, 'MEN_B'),
    VaccineScheduleDose(3, 'ROTA'),
    VaccineScheduleDose(4, 'HEXAVALENT'),
    VaccineScheduleDose(4, 'PCV'),
    VaccineScheduleDose(4, 'ROTA'),
    VaccineScheduleDose(5, 'MEN_B'),
    VaccineScheduleDose(6, 'MEN_ACWY'),
    VaccineScheduleDose(11, 'HEXAVALENT'),
    VaccineScheduleDose(11, 'PCV'),
    VaccineScheduleDose(12, 'MMR'),
    VaccineScheduleDose(12, 'MEN_ACWY'),
    VaccineScheduleDose(12, 'MEN_B'),
    VaccineScheduleDose(18, 'MMR'),
  ],
  'ألمانيا': [
    VaccineScheduleDose(2, 'HEXAVALENT'),
    VaccineScheduleDose(2, 'PCV'),
    VaccineScheduleDose(2, 'ROTA', timingNote: 'عدد الجرعات يعتمد على المنتج'),
    VaccineScheduleDose(2, 'MEN_B'),
    VaccineScheduleDose(4, 'HEXAVALENT'),
    VaccineScheduleDose(4, 'PCV'),
    VaccineScheduleDose(4, 'ROTA', timingNote: 'عدد الجرعات يعتمد على المنتج'),
    VaccineScheduleDose(4, 'MEN_B'),
    VaccineScheduleDose(11, 'HEXAVALENT'),
    VaccineScheduleDose(11, 'PCV'),
    VaccineScheduleDose(12, 'MEN_B'),
    VaccineScheduleDose(11, 'MMR'),
    VaccineScheduleDose(11, 'VARICELLA'),
    VaccineScheduleDose(15, 'MMR'),
    VaccineScheduleDose(15, 'VARICELLA'),
  ],
  'الهند': [
    VaccineScheduleDose(0, 'BCG'),
    VaccineScheduleDose(0, 'HEPB'),
    VaccineScheduleDose(0, 'OPV'),
    VaccineScheduleDose(1, 'PENTA', daysAfterBirth: 42, ageLabelOverride: '6 أسابيع'),
    VaccineScheduleDose(1, 'PCV', daysAfterBirth: 42, ageLabelOverride: '6 أسابيع'),
    VaccineScheduleDose(1, 'IPV', daysAfterBirth: 42, ageLabelOverride: '6 أسابيع'),
    VaccineScheduleDose(1, 'OPV', daysAfterBirth: 42, ageLabelOverride: '6 أسابيع'),
    VaccineScheduleDose(1, 'ROTA', daysAfterBirth: 42, ageLabelOverride: '6 أسابيع'),
    VaccineScheduleDose(2, 'PENTA', daysAfterBirth: 70, ageLabelOverride: '10 أسابيع'),
    VaccineScheduleDose(2, 'OPV', daysAfterBirth: 70, ageLabelOverride: '10 أسابيع'),
    VaccineScheduleDose(2, 'ROTA', daysAfterBirth: 70, ageLabelOverride: '10 أسابيع'),
    VaccineScheduleDose(3, 'PENTA', daysAfterBirth: 98, ageLabelOverride: '14 أسبوعًا'),
    VaccineScheduleDose(3, 'PCV', daysAfterBirth: 98, ageLabelOverride: '14 أسبوعًا'),
    VaccineScheduleDose(3, 'IPV', daysAfterBirth: 98, ageLabelOverride: '14 أسبوعًا'),
    VaccineScheduleDose(3, 'OPV', daysAfterBirth: 98, ageLabelOverride: '14 أسبوعًا'),
    VaccineScheduleDose(3, 'ROTA', daysAfterBirth: 98, ageLabelOverride: '14 أسبوعًا'),
    VaccineScheduleDose(9, 'MR'),
    VaccineScheduleDose(9, 'PCV'),
    VaccineScheduleDose(9, 'IPV'),
    VaccineScheduleDose(9, 'JE', conditional: true, timingNote: 'في الولايات/المناطق التي توصي به'),
    VaccineScheduleDose(13, 'MR'),
    VaccineScheduleDose(13, 'JE', conditional: true, timingNote: 'في الولايات/المناطق التي توصي به'),
    VaccineScheduleDose(16, 'DTP'),
    VaccineScheduleDose(16, 'OPV'),
    VaccineScheduleDose(19, 'DTP'),
  ],
  'الصين': [
    VaccineScheduleDose(0, 'BCG'),
    VaccineScheduleDose(0, 'HEPB'),
    VaccineScheduleDose(1, 'HEPB'),
    VaccineScheduleDose(2, 'IPV'),
    VaccineScheduleDose(3, 'DTP'),
    VaccineScheduleDose(3, 'IPV'),
    VaccineScheduleDose(4, 'DTP'),
    VaccineScheduleDose(4, 'OPV'),
    VaccineScheduleDose(5, 'DTP'),
    VaccineScheduleDose(6, 'HEPB'),
    VaccineScheduleDose(8, 'MMR'),
    VaccineScheduleDose(8, 'JE', conditional: true, timingNote: 'قد يختلف حسب المنطقة واللقاح المستخدم'),
    VaccineScheduleDose(18, 'DTP'),
    VaccineScheduleDose(18, 'MMR'),
    VaccineScheduleDose(18, 'HEPA'),
    VaccineScheduleDose(24, 'HEPA'),
  ],
  'تركيا': [
    VaccineScheduleDose(0, 'HEPB'),
    VaccineScheduleDose(2, 'BCG'),
    VaccineScheduleDose(2, 'HEXAVALENT'),
    VaccineScheduleDose(2, 'PCV'),
    VaccineScheduleDose(4, 'HEXAVALENT'),
    VaccineScheduleDose(4, 'PCV'),
    VaccineScheduleDose(6, 'HEXAVALENT'),
    VaccineScheduleDose(6, 'OPV'),
    VaccineScheduleDose(6, 'INFLUENZA', conditional: true),
    VaccineScheduleDose(12, 'MMR'),
    VaccineScheduleDose(12, 'PCV'),
    VaccineScheduleDose(12, 'VARICELLA'),
    VaccineScheduleDose(18, 'HEXAVALENT'),
    VaccineScheduleDose(18, 'HEPA'),
    VaccineScheduleDose(18, 'OPV'),
  ],
};

const Map<String, String> vaccineArabicNames = {
  'BCG': 'الدرن (BCG)',
  'HEPB': 'التهاب الكبد الفيروسي B',
  'OPV': 'شلل الأطفال الفموي (OPV)',
  'IPV': 'شلل الأطفال بالحقن (IPV)',
  'DTP': 'الدفتيريا والتيتانوس والسعال الديكي (DTP)',
  'PENTA': 'الخماسي: DTP + Hib + التهاب الكبد B',
  'HEXAVALENT': 'السداسي: DTP + Hib + التهاب الكبد B + IPV',
  'US_CORE': 'حماية DTP + Hib + التهاب الكبد B + IPV (التركيبة حسب مقدم الرعاية)',
  'DTP_HIB': 'DTP + Hib',
  'DTP_HIB_IPV': 'DTP + Hib + IPV',
  'HIB': 'المستدمية النزلية ب (Hib)',
  'PCV': 'المكورات الرئوية (PCV)',
  'ROTA': 'فيروس الروتا',
  'MEASLES': 'الحصبة',
  'MMR': 'الثلاثي الفيروسي: حصبة ونكاف وحصبة ألمانية (MMR)',
  'MR': 'الحصبة والحصبة الألمانية (MR)',
  'MMRV': 'MMRV: حصبة ونكاف وحصبة ألمانية وجديري مائي',
  'MEN_B': 'المكورات السحائية B',
  'MEN_C': 'المكورات السحائية C',
  'MEN_ACWY': 'المكورات السحائية ACWY',
  'HEPA': 'التهاب الكبد الفيروسي A',
  'VARICELLA': 'الجديري المائي',
  'INFLUENZA': 'الإنفلونزا الموسمية',
  'JE': 'التهاب الدماغ الياباني',
  'VITAMIN_A_100K': 'فيتامين أ — 100,000 وحدة (مكمل وليس تطعيمًا)',
  'VITAMIN_A_200K': 'فيتامين أ — 200,000 وحدة (مكمل وليس تطعيمًا)',
};

const Map<String, VaccineInfo> vaccineInformation = {
  'BCG': VaccineInfo(
    name: 'الدرن (BCG)',
    protectsAgainst: 'أشكال الدرن الشديدة، خصوصًا التهاب السحايا الدرني.',
    expectedSideEffects:
        'بعد 2–6 أسابيع قد تظهر حبة أو فقاعة صغيرة ثم قرحة سطحية وقشرة، وقد تترك ندبة صغيرة. قد يحدث تورم بسيط في الغدد تحت الإبط.',
    rareWarnings:
        'قرحة كبيرة أو خراج بالغدد أو علامات عدوى منتشرة، خصوصًا مع نقص المناعة، تستلزم مراجعة الطبيب.',
    sourceUrl: 'https://tbksp.who.int/en/node/2053',
  ),
  'HEPB': VaccineInfo(
    name: 'التهاب الكبد الفيروسي B',
    protectsAgainst: 'التهاب الكبد B ومضاعفاته المزمنة.',
    expectedSideEffects: 'ألم أو احمرار مكان الحقن، حرارة بسيطة، صداع أو إرهاق.',
    rareWarnings: 'حساسية شديدة نادرة جدًا؛ اطلب المساعدة فورًا عند صعوبة التنفس أو تورم الوجه.',
    sourceUrl: 'https://www.cdc.gov/vaccines/hcp/current-vis/hepatitis-b.html',
  ),
  'OPV': VaccineInfo(
    name: 'شلل الأطفال الفموي (سابين/OPV)',
    protectsAgainst: 'شلل الأطفال.',
    expectedSideEffects: 'غالبًا لا تظهر أعراض ملحوظة، وقد تحدث أعراض بسيطة وعابرة.',
    rareWarnings:
        'حساسية شديدة أو ضعف مفاجئ/شلل بعد الجرعة حالة طارئة ونادرة جدًا وتحتاج تقييمًا فوريًا.',
    sourceUrl: 'https://www.who.int/teams/immunization-vaccines-and-biologicals/diseases/poliomyelitis',
  ),
  'IPV': VaccineInfo(
    name: 'شلل الأطفال بالحقن (سولك/IPV)',
    protectsAgainst: 'شلل الأطفال.',
    expectedSideEffects: 'ألم أو احمرار أو تورم موضعي، حرارة بسيطة، عصبية أو نعاس أو قلة شهية.',
    rareWarnings: 'حساسية شديدة نادرة جدًا؛ راقب الطفل بعد التطعيم واطلب المساعدة عند أعراضها.',
    sourceUrl: 'https://www.cdc.gov/vaccines/hcp/current-vis/polio.html',
  ),
  'PENTA': VaccineInfo(
    name: 'التطعيم الخماسي',
    protectsAgainst: 'الدفتيريا والتيتانوس والسعال الديكي والتهاب الكبد B وHib.',
    expectedSideEffects:
        'ألم أو تورم موضعي، حرارة، عصبية، نعاس، قلة شهية أو قيء لمدة قصيرة غالبًا.',
    rareWarnings:
        'تشنج، بكاء متواصل 3 ساعات أو أكثر، حرارة شديدة أو حساسية شديدة: تواصل عاجل مع الطبيب.',
    sourceUrl: 'https://www.cdc.gov/vaccines/hcp/current-vis/childs-first.html',
  ),
  'HEXAVALENT': VaccineInfo(
    name: 'التطعيم السداسي',
    protectsAgainst: 'الدفتيريا والتيتانوس والسعال الديكي وHib والتهاب الكبد B وشلل الأطفال بالحقن.',
    expectedSideEffects:
        'ألم أو تورم موضعي، حرارة، عصبية، نعاس، قلة شهية أو قيء لمدة قصيرة غالبًا.',
    rareWarnings:
        'تشنج أو حساسية شديدة نادرًا؛ لا يُستبدل بالخماسي في جدول مصر إلا بتوجيه طبي.',
    sourceUrl: 'https://www.cdc.gov/vaccines/hcp/current-vis/childs-first.html',
  ),
  'US_CORE': VaccineInfo(
    name: 'تركيبة حماية الرضع',
    protectsAgainst: 'الدفتيريا والتيتانوس والسعال الديكي وHib والتهاب الكبد B وشلل الأطفال حسب المنتج.',
    expectedSideEffects: 'ألم موضعي، حرارة بسيطة، عصبية أو نعاس وقلة شهية.',
    rareWarnings: 'حساسية شديدة أو تشنج نادرًا؛ التركيبة النهائية يحددها مقدم الرعاية.',
    sourceUrl: 'https://www.cdc.gov/vaccines/hcp/current-vis/childs-first.html',
  ),
  'DTP': VaccineInfo(
    name: 'الثلاثي البكتيري (DTP)',
    protectsAgainst: 'الدفتيريا والتيتانوس والسعال الديكي.',
    expectedSideEffects: 'ألم أو تورم مكان الحقن، حرارة، عصبية، نعاس، قلة شهية أو قيء.',
    rareWarnings: 'تشنج أو بكاء متواصل أو حرارة شديدة نادرًا؛ راجع الطبيب فورًا عند حدوثها.',
    sourceUrl: 'https://www.cdc.gov/vaccines/hcp/current-vis/dtap.html',
  ),
  'DTP_HIB': VaccineInfo(
    name: 'DTP + Hib',
    protectsAgainst: 'الدفتيريا والتيتانوس والسعال الديكي وHib.',
    expectedSideEffects: 'ألم أو احمرار أو تورم موضعي، حرارة وعصبية مؤقتة.',
    rareWarnings: 'حساسية شديدة أو تشنج نادرًا؛ التوقيت والتركيبة حسب الطبيب.',
    sourceUrl: 'https://www.cdc.gov/vaccines/hcp/current-vis/childs-first.html',
  ),
  'DTP_HIB_IPV': VaccineInfo(
    name: 'DTP + Hib + IPV',
    protectsAgainst: 'الدفتيريا والتيتانوس والسعال الديكي وHib وشلل الأطفال.',
    expectedSideEffects: 'ألم موضعي، حرارة بسيطة، عصبية أو نعاس وقلة شهية.',
    rareWarnings: 'حساسية شديدة أو تشنج نادرًا؛ التوقيت حسب البرنامج المحلي.',
    sourceUrl: 'https://www.cdc.gov/vaccines/hcp/current-vis/childs-first.html',
  ),
  'HIB': VaccineInfo(
    name: 'المستدمية النزلية ب (Hib)',
    protectsAgainst: 'التهاب السحايا والالتهاب الرئوي وعدوى الدم بسبب Hib.',
    expectedSideEffects: 'احمرار أو سخونة أو تورم مكان الحقن وحرارة بسيطة.',
    rareWarnings: 'حساسية شديدة نادرة جدًا.',
    sourceUrl: 'https://www.cdc.gov/vaccines/hcp/current-vis/hib.html',
  ),
  'MMR': VaccineInfo(
    name: 'الثلاثي الفيروسي (MMR)',
    protectsAgainst: 'الحصبة والنكاف والحصبة الألمانية.',
    expectedSideEffects: 'ألم موضعي، حرارة، طفح خفيف أو تورم بسيط بالغدد.',
    rareWarnings: 'تشنج مرتبط بالحرارة أو نقص صفائح مؤقت نادرًا؛ راجع الطبيب عند نزف أو كدمات غير معتادة.',
    sourceUrl: 'https://www.cdc.gov/vaccines/hcp/current-vis/mmr.html',
  ),
  'MR': VaccineInfo(
    name: 'الحصبة والحصبة الألمانية (MR)',
    protectsAgainst: 'الحصبة والحصبة الألمانية.',
    expectedSideEffects: 'حرارة أو طفح خفيف أو ألم موضعي وتورم بسيط بالغدد.',
    rareWarnings: 'تشنج مرتبط بالحرارة أو حساسية شديدة نادرًا.',
    sourceUrl: 'https://www.cdc.gov/vaccines/hcp/current-vis/mmr.html',
  ),
  'MMRV': VaccineInfo(
    name: 'MMRV: الثلاثي الفيروسي والجديري المائي',
    protectsAgainst: 'الحصبة والنكاف والحصبة الألمانية والجديري المائي.',
    expectedSideEffects: 'ألم أو احمرار موضعي، حرارة أو طفح خفيف.',
    rareWarnings: 'تشنج مرتبط بالحرارة أو حساسية شديدة نادرًا؛ لا يعطى مع نقص مناعة شديد.',
    sourceUrl: 'https://www.cdc.gov/vaccines/hcp/current-vis/mmrv.html',
  ),
  'PCV': VaccineInfo(
    name: 'المكورات الرئوية (PCV)',
    protectsAgainst: 'الالتهاب الرئوي والتهاب السحايا وعدوى الدم وبعض التهابات الأذن.',
    expectedSideEffects: 'ألم أو احمرار أو تورم موضعي، حرارة أو قشعريرة، قلة شهية، عصبية أو نعاس.',
    rareWarnings: 'تشنج مرتبط بالحرارة أو حساسية شديدة نادرًا.',
    sourceUrl: 'https://www.cdc.gov/vaccines/hcp/current-vis/pneumococcal-conjugate.html',
  ),
  'ROTA': VaccineInfo(
    name: 'فيروس الروتا',
    protectsAgainst: 'الإسهال والقيء الشديدين الناتجين عن فيروس الروتا.',
    expectedSideEffects: 'عصبية، إسهال خفيف مؤقت أو قيء بسيط.',
    rareWarnings:
        'انغلاف الأمعاء خطر نادر جدًا. اطلب المساعدة عند ألم بطني شديد متقطع، قيء متكرر، براز دموي أو سحب الطفل رجليه إلى بطنه.',
    sourceUrl: 'https://www.cdc.gov/vaccine-safety/vaccines/rotavirus.html',
  ),
  'INFLUENZA': VaccineInfo(
    name: 'الإنفلونزا الموسمية',
    protectsAgainst: 'الإنفلونزا ومضاعفاتها.',
    expectedSideEffects: 'ألم أو احمرار أو تورم موضعي، حرارة، صداع، إرهاق أو آلام بالجسم.',
    rareWarnings: 'حساسية شديدة نادرة جدًا؛ الطفل الأقل من 6 أشهر يحتاج حماية من المخالطين لا لقاحًا مباشرًا.',
    sourceUrl: 'https://www.cdc.gov/vaccine-safety/vaccines/flu.html',
  ),
  'HEPA': VaccineInfo(
    name: 'التهاب الكبد الفيروسي A',
    protectsAgainst: 'التهاب الكبد A.',
    expectedSideEffects: 'ألم أو احمرار أو تورم موضعي، حرارة بسيطة، صداع، إرهاق أو قلة شهية.',
    rareWarnings: 'حساسية شديدة نادرة جدًا.',
    sourceUrl: 'https://www.cdc.gov/vaccines/hcp/current-vis/hepatitis-a.html',
  ),
  'VARICELLA': VaccineInfo(
    name: 'الجديري المائي',
    protectsAgainst: 'الجديري المائي ومضاعفاته.',
    expectedSideEffects: 'ألم أو احمرار أو طفح بسيط مكان الحقن أو حرارة.',
    rareWarnings: 'تشنج مرتبط بالحرارة أو التهاب رئوي أو عصبي نادر جدًا؛ لا يعطى مع نقص مناعة شديد.',
    sourceUrl: 'https://www.cdc.gov/vaccines/hcp/current-vis/varicella.html',
  ),
  'MEN_B': VaccineInfo(
    name: 'المكورات السحائية B',
    protectsAgainst: 'التهاب السحايا وعدوى الدم بسبب المكورات السحائية B.',
    expectedSideEffects: 'ألم أو احمرار أو تورم موضعي، حرارة، إرهاق، صداع، قشعريرة أو غثيان.',
    rareWarnings: 'حساسية شديدة نادرة جدًا؛ التوقيت يعتمد على عوامل الخطورة والمنتج.',
    sourceUrl: 'https://www.cdc.gov/vaccines/hcp/current-vis/meningococcal-b.html',
  ),
  'MEN_ACWY': VaccineInfo(
    name: 'المكورات السحائية ACWY',
    protectsAgainst: 'التهاب السحايا وعدوى الدم بسبب الأنواع A وC وW وY.',
    expectedSideEffects: 'ألم أو احمرار أو تورم مكان الحقن، حرارة بسيطة، صداع أو إرهاق.',
    rareWarnings: 'حساسية شديدة نادرة جدًا؛ يُحدد الاحتياج حسب عوامل الخطورة أو السفر أو الحملات.',
    sourceUrl: 'https://www.cdc.gov/vaccines/hcp/current-vis/meningococcal-acwy.html',
  ),
  'MEN_C': VaccineInfo(
    name: 'المكورات السحائية C',
    protectsAgainst: 'التهاب السحايا وعدوى الدم بسبب المكورات السحائية C.',
    expectedSideEffects: 'ألم أو احمرار موضعي وحرارة بسيطة أو عصبية.',
    rareWarnings: 'حساسية شديدة نادرة جدًا؛ التوقيت حسب البلد وعوامل الخطورة.',
    sourceUrl: 'https://www.cdc.gov/vaccines/hcp/current-vis/meningococcal-acwy.html',
  ),
  'MEASLES': VaccineInfo(
    name: 'الحصبة',
    protectsAgainst: 'الحصبة.',
    expectedSideEffects: 'حرارة أو طفح خفيف وألم موضعي.',
    rareWarnings: 'تشنج مرتبط بالحرارة أو حساسية شديدة نادرًا.',
    sourceUrl: 'https://www.cdc.gov/vaccines/hcp/current-vis/mmr.html',
  ),
  'JE': VaccineInfo(
    name: 'التهاب الدماغ الياباني',
    protectsAgainst: 'التهاب الدماغ الياباني في المناطق التي ينتشر بها.',
    expectedSideEffects: 'ألم أو احمرار موضعي، حرارة أو صداع أو إرهاق.',
    rareWarnings: 'حساسية شديدة نادرة جدًا؛ ليس تطعيمًا روتينيًا لكل طفل في مصر.',
  ),
  'VITAMIN_A_100K': VaccineInfo(
    name: 'فيتامين أ — 100,000 وحدة (مكمل وليس تطعيمًا)',
    protectsAgainst: 'دعم الوقاية من نقص فيتامين أ ضمن برنامج الرعاية الوقائية.',
    expectedSideEffects: 'قد يحدث غثيان أو قيء أو صداع أو تهيج، خصوصًا إذا تكررت الجرعة.',
    rareWarnings: 'الجرعة الزائدة قد تكون سامة؛ لا تُكرر الجرعة من تلقاء نفسك ولا تجمعيها مع مكمل آخر.',
    sourceUrl: 'https://www.who.int/data/nutrition/nlis/info/vitamin-a-supplementation',
  ),
  'VITAMIN_A_200K': VaccineInfo(
    name: 'فيتامين أ — 200,000 وحدة (مكمل وليس تطعيمًا)',
    protectsAgainst: 'دعم الوقاية من نقص فيتامين أ ضمن برنامج الرعاية الوقائية.',
    expectedSideEffects: 'قد يحدث غثيان أو قيء أو صداع أو تهيج، خصوصًا إذا تكررت الجرعة.',
    rareWarnings: 'الجرعة الزائدة قد تكون سامة؛ لا تُكرر الجرعة من تلقاء نفسك ولا تجمعيها مع مكمل آخر.',
    sourceUrl: 'https://www.who.int/data/nutrition/nlis/info/vitamin-a-supplementation',
  ),
};

/// Additional vaccines are shown as a discussion list, not as Ministry of
/// Health routine appointments. The final product, number of doses, minimum
/// ages, and intervals must be confirmed from the brand leaflet and the
/// child's pediatrician.
const List<AdditionalVaccineRecommendation> egyptAdditionalVaccineRecommendations = [
  AdditionalVaccineRecommendation(
    code: 'PCV',
    name: 'المكورات الرئوية (PCV)',
    firstReviewAgeMonths: 2,
    timing: 'ابدأ مناقشتها عادةً من عمر شهرين',
    scheduleNote: 'عدد الجرعات والمنشطة يختلف حسب عمر البداية والمنتج؛ لا يعتمد التطبيق جدولًا نهائيًا لها.',
    purpose: 'وقاية إضافية من الالتهاب الرئوي والتهاب السحايا وعدوى الدم وبعض التهابات الأذن.',
  ),
  AdditionalVaccineRecommendation(
    code: 'ROTA',
    name: 'فيروس الروتا',
    firstReviewAgeMonths: 2,
    timing: 'تبدأ غالبًا من عمر شهرين، ولا يُفضل تأخير أول جرعة',
    scheduleNote: 'عدد الجرعات وحدود العمر القصوى يتغيران حسب المنتج؛ اسألي الطبيب قبل تجاوز المواعيد.',
    purpose: 'تقليل خطر الإسهال والقيء والجفاف بسبب الروتا.',
  ),
  AdditionalVaccineRecommendation(
    code: 'INFLUENZA',
    name: 'الإنفلونزا الموسمية',
    firstReviewAgeMonths: 6,
    timing: 'من عمر 6 أشهر ثم سنويًا حسب الموسم',
    scheduleNote: 'قد يحتاج الطفل أول موسم إلى جرعتين بفاصل 4 أسابيع على الأقل حسب تاريخه والمنتج.',
    purpose: 'تقليل الإصابة بالإنفلونزا ومضاعفاتها.',
  ),
  AdditionalVaccineRecommendation(
    code: 'HEPA',
    name: 'التهاب الكبد الفيروسي A',
    firstReviewAgeMonths: 12,
    timing: 'تُناقش عادةً بعد عمر سنة',
    scheduleNote: 'عدد الجرعات والفاصل بينهما حسب المنتج وتقييم طبيب الأطفال.',
    purpose: 'الوقاية من التهاب الكبد A.',
  ),
  AdditionalVaccineRecommendation(
    code: 'VARICELLA',
    name: 'الجديري المائي',
    firstReviewAgeMonths: 12,
    timing: 'تُناقش عادةً بعد عمر سنة',
    scheduleNote: 'الجرعات والفاصل بينهما حسب المنتج والبرنامج المحلي؛ ليست ضمن جدول مصر الروتيني المعروض هنا.',
    purpose: 'تقليل خطر الجديري المائي ومضاعفاته.',
  ),
  AdditionalVaccineRecommendation(
    code: 'MEN_ACWY',
    name: 'المكورات السحائية',
    firstReviewAgeMonths: null,
    timing: 'لا يوجد موعد رضيع ثابت في هذا التطبيق',
    scheduleNote: 'تُبحث عند وجود عامل خطورة أو سفر أو حملة أو توصية من الطبيب.',
    purpose: 'الوقاية من بعض أنواع التهاب السحايا وعدوى الدم.',
  ),
];

String whoScheduleUrl(String country) {
  final code = vaccineCountryCodes[country] ?? 'EGY';
  return 'https://immunizationdata.who.int/global/wiise-detail-page/vaccination-schedule-for-country_name?ISO_3_CODE=' + code;
}

const egyptMinistryVaccineUrl = 'https://www.mohp.gov.eg/Articles.aspx';
const egyptHealthCouncilVaccineUrl =
    'https://lms.ehc.gov.eg/lms/mod/book/view.php?chapterid=3425&id=570&lang=ar';
const egyptUnicefVaccineScheduleUrl =
    'https://www.unicef.org/egypt/ar/%D8%A7%D9%84%D8%AA%D8%B7%D8%B9%D9%8A%D9%85%D8%A7%D8%AA';
const egyptNewbornGuidanceUrl = 'https://www.mohp.gov.eg/rr/docs/%D8%B1%D8%B9%D8%A7%D9%8A%D8%A9-%D8%A7%D9%84%D8%B7%D9%81%D9%84-%D9%88%D8%AD%D8%AF%D9%8A%D8%AB%D9%89-%D8%A7%D9%84%D9%88%D9%84%D8%A7%D8%AF%D8%A9.pdf';
const chinaCdcVaccineUrl = 'https://en.chinacdc.cn/health_topics/immunization/202203/t20220302_257317.html';
const germanyStikoVaccineUrl = 'https://www.rki.de/DE/Themen/Infektionskrankheiten/Impfen/Impfkalender/impfkalender-node.html';
const ukNhsVaccineUrl = 'https://www.nhs.uk/vaccinations/nhs-vaccinations-and-when-to-have-them/';
