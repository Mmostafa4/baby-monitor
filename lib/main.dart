import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/vaccine_schedules.dart';
import 'models/daily_log_entry.dart';
import 'models/cry_analysis_result.dart';
import 'services/cry_analysis_client.dart';
import 'services/cry_analysis_configuration.dart';
import 'services/cry_recording_service.dart';
import 'services/maps_navigation_stub.dart'
    if (dart.library.html) 'services/maps_navigation_web.dart'
    as maps_navigation;
import 'services/newborn_assistant_service.dart';
import 'widgets/baby_monitor_logo.dart';
import 'widgets/cry_needs_guide.dart';
import 'widgets/newborn_quick_guide.dart';
import 'widgets/weekly_development_guide.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CryAnalysisConfiguration.initialize();
  runApp(const BabyMonitorApp());
}

ThemeData themeForGender(String? gender) {
  final isGirl = gender == 'بنت';
  final isBoy = gender == 'ولد';
  final seedColor = isGirl
      ? const Color(0xffe982aa)
      : isBoy
          ? const Color(0xff78b8e8)
          : const Color(0xff9b8ac5);
  final backgroundColor = isGirl
      ? const Color(0xfffff6fa)
      : isBoy
          ? const Color(0xfff3faff)
          : const Color(0xfffaf8fc);
  final surfaceColor = isGirl
      ? const Color(0xffffeaf2)
      : isBoy
          ? const Color(0xffe7f4ff)
          : const Color(0xfff0ecf7);
  final colorScheme = ColorScheme.fromSeed(seedColor: seedColor);

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: backgroundColor,
    appBarTheme: AppBarTheme(
      backgroundColor: surfaceColor,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surfaceColor,
      indicatorColor: colorScheme.secondaryContainer,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceColor.withAlpha(130),
    ),
  );
}

class BabyMonitorApp extends StatefulWidget {
  const BabyMonitorApp({super.key});

  @override
  State<BabyMonitorApp> createState() => _BabyMonitorAppState();
}

class _BabyMonitorAppState extends State<BabyMonitorApp> {
  final AppStore store = AppStore();
  late final Future<void> startup = store.load();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Baby Monitor',
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: themeForGender(store.activeGender),
        home: FutureBuilder<void>(
          future: startup,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return const Scaffold(
                body: Center(
                    child: Text('تعذر فتح بيانات التطبيق على هذا الجهاز.')),
              );
            }
            final needsProfileSetup =
                store.profile == null || store.profile!.gender == null;
            return needsProfileSetup
                ? ConsentAndProfile(
                    store: store,
                    editMode: store.profile != null,
                    onSaved: () => setState(() {}),
                  )
                : Home(
                    store: store,
                    onLocalDataDeleted: () => setState(() {}),
                  );
          },
        ),
      ),
    );
  }
}

class AppStore extends ChangeNotifier {
  ChildProfile? profile;
  String? draftGender;
  final Set<String> completedVaccineIds = <String>{};
  final Map<String, DailyLogEntry> dailyLogs = <String, DailyLogEntry>{};

  String? get activeGender => draftGender ?? profile?.gender;

  void setDraftGender(String? value) {
    if (draftGender == value) return;
    draftGender = value;
    notifyListeners();
  }

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString('profile');
    if (raw != null) {
      try {
        profile = ChildProfile.fromJson(raw);
      } on FormatException {
        await preferences.remove('profile');
      }
    }
    completedVaccineIds
      ..clear()
      ..addAll(preferences.getStringList('completed_vaccines') ?? const []);

    dailyLogs.clear();
    final rawDailyLogs = preferences.getString('daily_logs');
    if (rawDailyLogs != null) {
      try {
        final decoded = jsonDecode(rawDailyLogs);
        if (decoded is List) {
          for (final value in decoded) {
            try {
              final entry = DailyLogEntry.fromJson(value);
              dailyLogs[entry.dateKey] = entry;
            } on FormatException {
              // Ignore a single damaged entry and keep the rest of the log.
            }
          }
        }
      } on FormatException {
        await preferences.remove('daily_logs');
      }
    }
    notifyListeners();
  }

  Future<void> save(ChildProfile value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('profile', value.toJson());
    profile = value;
    draftGender = null;
    notifyListeners();
  }

  Future<void> saveLocationConsent(bool value) async {
    final current = profile;
    if (current == null) return;
    await save(current.copyWith(locationConsent: value));
  }

  Future<void> setVaccineCompleted(String id, bool completed) async {
    if (completed) {
      completedVaccineIds.add(id);
    } else {
      completedVaccineIds.remove(id);
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'completed_vaccines',
      completedVaccineIds.toList()..sort(),
    );
  }

  Future<void> saveDailyLog(DailyLogEntry entry) async {
    dailyLogs[entry.dateKey] = entry;
    final preferences = await SharedPreferences.getInstance();
    final entries = dailyLogs.values.toList()
      ..sort((left, right) => left.date.compareTo(right.date));
    await preferences.setString(
      'daily_logs',
      jsonEncode(entries.map((value) => value.toJson()).toList()),
    );
  }

  Future<void> deleteDailyLog(String dateKey) async {
    dailyLogs.remove(dateKey);
    final preferences = await SharedPreferences.getInstance();
    final entries = dailyLogs.values.toList()
      ..sort((left, right) => left.date.compareTo(right.date));
    await preferences.setString(
      'daily_logs',
      jsonEncode(entries.map((value) => value.toJson()).toList()),
    );
  }

  Future<void> clearLocalData() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('profile');
    await preferences.remove('completed_vaccines');
    await preferences.remove('daily_logs');
    profile = null;
    draftGender = null;
    completedVaccineIds.clear();
    dailyLogs.clear();
    await CryAnalysisConfiguration.deleteAnonymousUser();
    notifyListeners();
  }
}

class ChildProfile {
  final String baby;
  final String mother;
  final String father;
  final String country;
  final String language;
  final DateTime dob;
  final String? gender;
  final bool locationConsent;

  const ChildProfile({
    required this.baby,
    required this.mother,
    required this.father,
    required this.country,
    required this.language,
    required this.dob,
    this.gender,
    this.locationConsent = false,
  });

  ChildProfile copyWith({String? gender, bool? locationConsent}) => ChildProfile(
        baby: baby,
        mother: mother,
        father: father,
        country: country,
        language: language,
        dob: dob,
        gender: gender ?? this.gender,
        locationConsent: locationConsent ?? this.locationConsent,
      );

  String toJson() => jsonEncode({
        'baby': baby,
        'mother': mother,
        'father': father,
        'country': country,
        'language': language,
        'dob': dob.toIso8601String(),
        'gender': gender,
        'locationConsent': locationConsent,
      });

  factory ChildProfile.fromJson(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        final baby = decoded['baby'];
        final mother = decoded['mother'];
        final father = decoded['father'];
        final country = decoded['country'];
        final language = decoded['language'];
        final dob = decoded['dob'];
        final savedGender = decoded['gender'];
        final locationConsent = decoded['locationConsent'];

        if (baby is String &&
            mother is String &&
            father is String &&
            country is String &&
            language is String &&
            dob is String) {
          return ChildProfile(
            baby: baby,
            mother: mother,
            father: father,
            country: country,
            language: language,
            dob: DateTime.parse(dob),
            gender: savedGender is String &&
                    (savedGender == 'بنت' || savedGender == 'ولد')
                ? savedGender
                : null,
            locationConsent: locationConsent == true,
          );
        }
      }
    } on FormatException {
      // Older profiles used a pipe-delimited local format.
    }

    final legacy = value.split('|');
    if (legacy.length != 6) {
      throw const FormatException('Invalid child profile.');
    }
    final dob = DateTime.tryParse(legacy[5]);
    if (dob == null) throw const FormatException('Invalid child profile date.');

    return ChildProfile(
      baby: legacy[0],
      mother: legacy[1],
      father: legacy[2],
      country: legacy[3],
      language: legacy[4],
      dob: dob,
    );
  }
}

const List<String> countries = [
  'مصر',
  'السعودية',
  'الإمارات',
  'الولايات المتحدة',
  'المملكة المتحدة',
  'فرنسا',
  'ألمانيا',
  'الهند',
  'الصين',
  'تركيا',
];

class ConsentAndProfile extends StatefulWidget {
  final AppStore store;
  final VoidCallback onSaved;
  final bool editMode;

  const ConsentAndProfile({
    super.key,
    required this.store,
    required this.onSaved,
    this.editMode = false,
  });

  @override
  State<ConsentAndProfile> createState() => _ConsentAndProfileState();
}

class _ConsentAndProfileState extends State<ConsentAndProfile> {
  final GlobalKey<FormState> form = GlobalKey<FormState>();
  final TextEditingController baby = TextEditingController();
  final TextEditingController mother = TextEditingController();
  final TextEditingController father = TextEditingController();

  String country = 'مصر';
  String? gender;
  DateTime dob = DateTime.now();
  bool acceptedMedicalNotice = false;
  bool locationConsent = false;
  bool saving = false;
  String? locationNotice;

  @override
  void initState() {
    super.initState();
    final existing = widget.editMode ? widget.store.profile : null;
    if (existing == null) return;
    baby.text = existing.baby;
    mother.text = existing.mother;
    father.text = existing.father;
    country = existing.country;
    gender = existing.gender;
    dob = existing.dob;
    locationConsent = existing.locationConsent;
    acceptedMedicalNotice = true;
  }

  @override
  void dispose() {
    baby.dispose();
    mother.dispose();
    father.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (saving || !acceptedMedicalNotice || !form.currentState!.validate()) {
      return;
    }

    setState(() {
      saving = true;
      locationNotice = null;
    });

    final previousProfile = widget.store.profile;
    if (locationConsent && previousProfile?.locationConsent != true) {
      try {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          locationNotice =
              'لم يُمنح إذن الموقع من الجهاز. يمكنك تغييره لاحقًا من صفحة الطوارئ.';
        }
      } catch (_) {
        locationNotice =
            'تعذر طلب إذن الموقع الآن. يمكنك تغييره لاحقًا من صفحة الطوارئ.';
      }
    }

    await widget.store.save(
      ChildProfile(
        baby: baby.text.trim(),
        mother: mother.text.trim(),
        father: father.text.trim(),
        country: country,
        language: 'العربية',
        dob: dob,
        gender: gender!,
        locationConsent: locationConsent,
      ),
    );

    if (!mounted) return;
    if (locationNotice != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(locationNotice!)),
      );
    }
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Center(child: BabyMonitorLogo(size: 132)),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Baby Monitor',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                ),
                const Center(
                  child: Text('متابعة محلية ومعلومات إرشادية لرعاية طفلك'),
                ),
                const SizedBox(height: 22),
                DropdownButtonFormField<String>(
                  value: country,
                  items: countries
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => country = value!),
                  decoration: const InputDecoration(
                    labelText: 'الدولة',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.language),
                    title: Text('لغة التطبيق'),
                    subtitle: Text('العربية هي اللغة المتاحة حاليًا.'),
                  ),
                ),
                const SizedBox(height: 12),
                _textField(baby, 'اسم الطفل'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    value: gender,
                    items: const [
                      DropdownMenuItem(value: 'بنت', child: Text('بنت')),
                      DropdownMenuItem(value: 'ولد', child: Text('ولد')),
                    ],
                    onChanged: (value) {
                      setState(() => gender = value);
                      widget.store.setDraftGender(value);
                    },
                    validator: (value) =>
                        value == null ? 'اختاري جنس المولود' : null,
                    decoration: const InputDecoration(
                      labelText: 'جنس المولود',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                _textField(mother, 'اسم الأم'),
                _textField(father, 'اسم الأب'),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تاريخ ميلاد الطفل'),
                  subtitle: Text(DateFormat('yyyy-MM-dd').format(dob)),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: dob,
                      firstDate: DateTime(2015),
                      lastDate: DateTime.now(),
                    );
                    if (selected != null) setState(() => dob = selected);
                  },
                ),
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'التطبيق أداة مساعدة عامة، ولا يقدم تشخيصًا أو علاجًا. قد لا تناسب بعض المعلومات حالة كل طفل؛ راجعي طبيب الأطفال للقرارات الصحية، واتصلي بالطوارئ المحلية عند ظهور علامة طارئة.',
                    ),
                  ),
                ),
                CheckboxListTile(
                  value: acceptedMedicalNotice,
                  onChanged: (value) =>
                      setState(() => acceptedMedicalNotice = value ?? false),
                  title: const Text('قرأت التنبيه وأوافق على المتابعة'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                Card(
                  child: CheckboxListTile(
                    value: locationConsent,
                    onChanged: (value) =>
                        setState(() => locationConsent = value ?? false),
                    title: const Text(
                        'أوافق على استخدام موقعي عند طلب مستشفى قريب'),
                    subtitle: const Text(
                      'سيطلب الجهاز إذن GPS الآن. لا يحفظ التطبيق إحداثياتك أو يرسلها إلى خادمه؛ تُشارك مع الخرائط فقط لعرض المستشفى القريب.',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: saving ? null : _saveProfile,
                  child: Text(
                    saving
                        ? 'جارٍ الحفظ...'
                        : widget.editMode
                            ? 'حفظ التغييرات'
                            : 'ابدأ',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _textField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class Home extends StatefulWidget {
  final AppStore store;
  final VoidCallback onLocalDataDeleted;

  const Home({
    super.key,
    required this.store,
    required this.onLocalDataDeleted,
  });

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  final GlobalKey<_CryPageState> cryPageKey = GlobalKey<_CryPageState>();

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (settingsContext) => AppSettingsScreen(
          store: widget.store,
          onEditProfile: () async {
            await Navigator.of(settingsContext).push<void>(
              MaterialPageRoute<void>(
                builder: (profileContext) => ConsentAndProfile(
                  store: widget.store,
                  editMode: true,
                  onSaved: () => Navigator.of(profileContext).pop(),
                ),
              ),
            );
          },
          onLocalDataDeleted: widget.onLocalDataDeleted,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.store.profile!;
    final pages = [
      CryPage(key: cryPageKey),
      Reassure(store: widget.store),
      Vaccines(store: widget.store),
      Emergency(store: widget.store),
      const NewbornAssistant(),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Baby Monitor • ' + profile.baby),
          leading: const Padding(
            padding: EdgeInsets.all(7),
            child: BabyMonitorLogo(size: 42),
          ),
          actions: [
            IconButton(
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'الإعدادات والخصوصية',
            ),
          ],
        ),
        body: IndexedStack(index: tab, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (index) {
            if (tab == 0 && index != 0) {
              unawaited(cryPageKey.currentState?.discardCaptureAndPreview());
            }
            setState(() => tab = index);
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.mic), label: 'الصوت'),
            NavigationDestination(icon: Icon(Icons.favorite), label: 'اطمئن'),
            NavigationDestination(
                icon: Icon(Icons.vaccines), label: 'التطعيمات'),
            NavigationDestination(
                icon: Icon(Icons.warning_amber), label: 'الطوارئ'),
            NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline), label: 'اسألي'),
          ],
        ),
      ),
    );
  }
}

class AppSettingsScreen extends StatefulWidget {
  final AppStore store;
  final Future<void> Function() onEditProfile;
  final VoidCallback onLocalDataDeleted;

  const AppSettingsScreen({
    super.key,
    required this.store,
    required this.onEditProfile,
    required this.onLocalDataDeleted,
  });

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool editingProfile = false;
  bool deletingData = false;

  Future<void> _editProfile() async {
    if (editingProfile) return;
    setState(() => editingProfile = true);
    try {
      await widget.onEditProfile();
    } finally {
      if (mounted) setState(() => editingProfile = false);
    }
  }

  Future<void> _deleteLocalData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف كل البيانات المحلية؟'),
        content: const Text(
          'سيُحذف ملف الطفل وسجلات الرعاية وعلامات التطعيم المحفوظة على هذا الجهاز. لا يمكن التراجع عن الحذف.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف البيانات'),
          ),
        ],
      ),
    );
    if (confirmed != true || deletingData) return;

    setState(() => deletingData = true);
    try {
      await widget.store.clearLocalData();
      if (!mounted) return;
      widget.onLocalDataDeleted();
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (mounted) setState(() => deletingData = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حذف البيانات. حاولي مرة أخرى.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.store.profile;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الإعدادات والخصوصية')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.child_care),
                title: const Text('ملف الطفل'),
                subtitle: Text(
                  profile == null
                      ? 'لا يوجد ملف محفوظ'
                      : profile.baby + ' • ' + profile.country,
                ),
                trailing: editingProfile
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_outlined),
                onTap: editingProfile ? null : _editProfile,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'البيانات والخصوصية',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ملف الطفل وسجلات اليوم وعلامات التطعيم تُحفظ على هذا الجهاز.',
                    ),
                    SizedBox(height: 8),
                    Text(
                      'يبقى التسجيل على الجهاز ما لم تختاري تحليله. عند تفعيل التحليل التجريبي، لن يُرسل الصوت إلى خادم خارجي إلا بعد موافقة منفصلة لكل تسجيل؛ لا تُرسل بيانات الملف الشخصي.',
                    ),
                    SizedBox(height: 8),
                    Text(
                      'يمكنك حذف كل بيانات التطبيق المحلية من هنا. حذف التطبيق من الجهاز يزيل البيانات المحلية أيضًا.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: deletingData ? null : _deleteLocalData,
              icon: deletingData
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever_outlined),
              label: const Text('حذف كل البيانات المحلية'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CryPage extends StatefulWidget {
  const CryPage({super.key});

  @override
  State<CryPage> createState() => _CryPageState();
}

class _CryPageState extends State<CryPage> with WidgetsBindingObserver {
  final CryRecordingService recorder = CryRecordingService();
  final AudioPlayer player = AudioPlayer();
  StreamSubscription<void>? playerCompleteSubscription;
  Uint8List? audioPreview;
  Timer? timer;
  int seconds = 0;
  bool recording = false;
  bool busy = false;
  bool analyzing = false;
  bool playing = false;
  String message = '';
  CryAnalysisResult? analysisResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    playerCompleteSubscription = player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => playing = false);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        !busy &&
        (recording || recorder.hasPendingCleanup)) {
      unawaited(discardCaptureAndPreview());
    }
  }

  Future<void> start() async {
    if (recording || busy || analyzing) return;
    await player.stop();
    _clearPreview();
    setState(() {
      busy = true;
      message = '';
      analysisResult = null;
    });

    try {
      await recorder.start();
      if (!mounted) {
        await recorder.cancel();
        return;
      }

      setState(() {
        recording = true;
        seconds = 0;
      });

      timer = Timer.periodic(const Duration(seconds: 1), (currentTimer) {
        if (seconds >= 9) {
          currentTimer.cancel();
          unawaited(finish());
        } else if (mounted) {
          setState(() => seconds++);
        }
      });
    } on CryRecordingException catch (error) {
      await _cancelQuietly();
      if (mounted) setState(() => message = error.message);
    } catch (_) {
      await _cancelQuietly();
      if (mounted) {
        setState(() {
          message =
              'تعذر بدء التسجيل. اسمحي بالميكروفون من إعدادات الجهاز أو المتصفح ثم حاولي مجددًا.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> finish() async {
    if (!recording || busy) return;
    timer?.cancel();
    setState(() => busy = true);

    try {
      final bytes = await recorder.stopAndGetWav();
      final streamError = recorder.streamError;
      if (mounted) {
        setState(() {
          recording = false;
          busy = false;
          seconds = bytes != null && streamError == null ? 10 : 0;
          if (bytes != null && streamError == null) {
            audioPreview = bytes;
            message = 'تم تسجيل ' +
                (bytes.length / 1024).toStringAsFixed(1) +
                ' كيلوبايت. يمكنك الاستماع أو حذفه. لن يُرسل للتحليل إلا بعد موافقتك.';
          } else {
            audioPreview = null;
            message =
                'لم يصل صوت إلى المسجل. تحققي من إذن الميكروفون. في نسخة الويب افتحي التطبيق عبر HTTPS ثم أعيدي المحاولة.';
          }
        });
      }
    } on CryRecordingException catch (error) {
      if (mounted) {
        setState(() {
          recording = false;
          busy = false;
          seconds = 0;
          message = error.message;
        });
      }
    } catch (_) {
      await _cancelQuietly();
      if (mounted) {
        setState(() {
          recording = false;
          busy = false;
          seconds = 0;
          message =
              'تعذر إكمال التسجيل. تحققي من إذن الميكروفون وحاولي مرة أخرى.';
        });
      }
    }
  }

  Future<void> cancelRecording() async {
    timer?.cancel();
    setState(() => busy = true);
    try {
      await recorder.cancel();
      if (mounted) {
        setState(() {
          recording = false;
          busy = false;
          seconds = 0;
          _clearPreview();
          message = 'تم إيقاف التسجيل وحذفه من الذاكرة.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          recording = false;
          busy = false;
          message = error is CryRecordingException
              ? error.message
              : 'تعذر إيقاف التسجيل. حاولي مرة أخرى.';
        });
      }
    }
  }

  Future<void> _cancelQuietly() async {
    try {
      await recorder.cancel();
    } catch (_) {
      // Keep the original recording error visible and retry cleanup on dispose.
    }
  }

  Future<void> _playPreview() async {
    final bytes = audioPreview;
    if (bytes == null) return;
    try {
      if (playing) {
        await player.pause();
        if (mounted) setState(() => playing = false);
      } else {
        await player.play(BytesSource(bytes, mimeType: 'audio/wav'));
        if (mounted) setState(() => playing = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          message =
              'تعذر تشغيل التسجيل على هذا المتصفح. يمكنك حذفه وإعادة المحاولة.';
          playing = false;
        });
      }
    }
  }

  Future<void> _analyzePreview() async {
    final bytes = audioPreview;
    if (bytes == null || busy || analyzing) return;

    final client = CryAnalysisConfiguration.createClient();
    if (client == null) {
      setState(() => message = CryAnalysisConfiguration.unavailableMessage);
      return;
    }

    final consent = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إرسال التسجيل للتحليل التجريبي؟'),
        content: const SingleChildScrollView(
          child: Text(
            'سيُرسل هذا المقطع الصوتي الذي مدته 10 ثوانٍ فقط عبر HTTPS إلى خادم التحليل. يعالجه الخادم في الذاكرة ولا يحفظه كملف أو في قاعدة بيانات. لا يُرسل اسم الطفل أو عمره أو ملفه. يُستخدم تسجيل دخول مجهول لإصدار رمز مؤقت، ولا يُرسل أي صوت قبل هذه الموافقة.\n\n'
            'النموذج تجريبي وقد يخطئ. لا يميّز احتياج الطفل للحنان أو مستوى الضيق، ولا يشخّص المغص أو المرض أو حالات الطوارئ. لا تعتمدي على النتيجة بدل ملاحظة الطفل أو طلب الرعاية عند القلق.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('لا، أبقِه على الجهاز'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('أوافق على الإرسال هذه المرة'),
          ),
        ],
      ),
    );
    if (consent != true || !mounted) return;

    await player.stop();
    setState(() {
      analyzing = true;
      playing = false;
      message = 'جارٍ تحليل المقطع على خادم التجربة...';
    });

    try {
      final result = await client.analyze(bytes);
      if (mounted) {
        setState(() {
          analysisResult = result;
          message = '';
        });
      }
    } on CryAnalysisException catch (error) {
      if (mounted) setState(() => message = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => message = 'تعذر إكمال التحليل. حُذف التسجيل من ذاكرة التطبيق.',
        );
      }
    } finally {
      bytes.fillRange(0, bytes.length, 0);
      if (identical(audioPreview, bytes)) audioPreview = null;
      if (mounted) {
        setState(() {
          analyzing = false;
          playing = false;
          seconds = 0;
        });
      }
    }
  }

  Future<void> _deletePreview() async {
    await player.stop();
    _clearPreview();
    if (mounted) {
      setState(() {
        playing = false;
        seconds = 0;
        analysisResult = null;
        message = 'تم حذف التسجيل من الذاكرة.';
      });
    }
  }

  Future<void> discardCaptureAndPreview() async {
    if (analyzing) return;
    timer?.cancel();
    final hadRecording = recording || recorder.hasPendingCleanup;
    try {
      if (hadRecording) await recorder.cancel();
      await player.stop();
      _clearPreview();
      if (mounted) {
        setState(() {
          recording = false;
          playing = false;
          seconds = 0;
          message = hadRecording ? 'تم حذف التسجيل عند مغادرة الصفحة.' : '';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          recording = false;
          playing = false;
          message =
              'تعذر حذف الصوت عند مغادرة الصفحة. عودي إلى الصوت واستخدمي حذف التسجيل.';
        });
      }
    }
  }

  void _clearPreview() {
    final bytes = audioPreview;
    if (bytes != null) bytes.fillRange(0, bytes.length, 0);
    audioPreview = null;
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    final bytes = audioPreview;
    if (bytes != null) bytes.fillRange(0, bytes.length, 0);
    unawaited(playerCompleteSubscription?.cancel());
    unawaited(player.dispose());
    unawaited(recorder.dispose().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 14),
        const Center(child: BabyMonitorLogo(size: 150)),
        const SizedBox(height: 14),
        const Center(
          child: Text(
            'تسجيل صوت الطفل',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            recording
                ? 'جارٍ التسجيل: ' + (10 - seconds).toString() + ' ثوانٍ'
                : seconds == 10
                    ? 'اكتمل التقاط الصوت'
                    : 'التقطي حتى 10 ثوانٍ من الصوت من الميكروفون.',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        if (recording) LinearProgressIndicator(value: seconds / 10),
        const SizedBox(height: 10),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إرشادات استخدام التسجيل',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(
                  '1) قرّبي الهاتف من الطفل مع بقاءه في مكان آمن.\n'
                  '2) اضغطي «ابدأ التسجيل» واتركيه حتى 10 ثوانٍ.\n'
                  '3) إذا لم يلتقط التطبيق صوتًا واضحًا، سيطلب إعادة التسجيل ولن يعرض نتيجة.\n'
                  '4) بعد اكتمال التسجيل يمكنكِ الاستماع إليه أو طلب التحليل التجريبي.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: FilledButton.icon(
            onPressed: busy || recording || analyzing ? null : start,
            icon: const Icon(Icons.mic),
            label: Text(busy ? 'جارٍ تجهيز الميكروفون...' : 'ابدأ التسجيل'),
          ),
        ),
        if (audioPreview != null) ...[
          const SizedBox(height: 8),
          Center(
            child: OutlinedButton.icon(
              onPressed: busy || analyzing ? null : _playPreview,
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              label: Text(playing ? 'إيقاف الاستماع' : 'استمع للتسجيل'),
            ),
          ),
          Center(
            child: TextButton.icon(
              onPressed: busy || analyzing ? null : _deletePreview,
              icon: const Icon(Icons.delete_outline),
              label: const Text('حذف التسجيل الآن'),
            ),
          ),
        ],
        if (recording || recorder.hasPendingCleanup)
          Center(
            child: TextButton.icon(
              onPressed: busy ? null : cancelRecording,
              icon: const Icon(Icons.delete_outline),
              label: const Text('إيقاف وحذف الصوت'),
            ),
          ),
        if (audioPreview != null) ...[
          const SizedBox(height: 4),
          Center(
            child: FilledButton.tonalIcon(
              onPressed: busy || analyzing ? null : _analyzePreview,
              icon: analyzing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(analyzing ? 'جارٍ التحليل...' : 'حلّل بمساعدة تجريبية'),
            ),
          ),
          if (!CryAnalysisConfiguration.isReady)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                CryAnalysisConfiguration.unavailableMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
        if (analysisResult case final result?) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'أقرب فئة رجّحها النموذج التجريبي',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _categoryLabel(result.category),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(result.advice),
                  const SizedBox(height: 10),
                  Text(
                    'درجة ترجيح النموذج: ${result.scorePercent}%',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'هذه الدرجة ناتجة من ترتيب النموذج وغير معايرة؛ ليست احتمالًا طبيًا أو نسبة دقة مؤكدة. لا يتعرّف النموذج على طلب الحنان أو الضيق كسبب مستقل، وقد يخطئ مع أي صوت أو طفل.',
                  ),
                ],
              ),
            ),
          ),
        ],
        if (message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Text(message, textAlign: TextAlign.center),
          ),
        const SizedBox(height: 12),
        const CryNeedsGuide(),
        const SizedBox(height: 10),
        const Text(
          'إذا كنت قلقة على تنفس الطفل أو صحته، اطلبي الرعاية الطبية ولا تعتمدي على التسجيل.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'hungry':
        return 'جوع محتمل';
      case 'belly_pain':
        return 'ألم بطن محتمل — لا يثبت المغص';
      case 'burping':
        return 'حاجة للتجشؤ محتملة';
      case 'discomfort':
        return 'انزعاج عام محتمل';
      case 'tiredness':
        return 'تعب أو نعاس محتمل';
      default:
        return 'غير واضح';
    }
  }
}

class Reassure extends StatefulWidget {
  final AppStore store;

  const Reassure({super.key, required this.store});

  @override
  State<Reassure> createState() => _ReassureState();
}

class _ReassureState extends State<Reassure> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController cryingHours = TextEditingController();
  final TextEditingController feedingCount = TextEditingController();
  final TextEditingController wetDiapers = TextEditingController();
  final TextEditingController sleepHours = TextEditingController();
  final TextEditingController temperature = TextEditingController();
  final TextEditingController notes = TextEditingController();

  late DateTime selectedDate;
  bool saving = false;
  String? message;

  @override
  void initState() {
    super.initState();
    selectedDate = dateOnly(DateTime.now());
    _populateForm();
  }

  @override
  void dispose() {
    cryingHours.dispose();
    feedingCount.dispose();
    wetDiapers.dispose();
    sleepHours.dispose();
    temperature.dispose();
    notes.dispose();
    super.dispose();
  }

  void _populateForm() {
    final entry = widget.store.dailyLogs[DailyLogEntry.keyFor(selectedDate)];
    cryingHours.text = entry?.cryingHours?.toString() ?? '';
    feedingCount.text = entry?.feedingCount?.toString() ?? '';
    wetDiapers.text = entry?.wetDiapers?.toString() ?? '';
    sleepHours.text = entry?.sleepHours?.toString() ?? '';
    temperature.text = entry?.temperatureCelsius?.toString() ?? '';
    notes.text = entry?.notes ?? '';
  }

  Future<void> _chooseDate() async {
    final profile = widget.store.profile!;
    final today = dateOnly(DateTime.now());
    final chosen = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: dateOnly(profile.dob),
      lastDate: today,
    );
    if (chosen == null || !mounted) return;
    setState(() {
      selectedDate = dateOnly(chosen);
      message = null;
      _populateForm();
    });
  }

  void _moveDate(int days) {
    final profile = widget.store.profile!;
    final candidate = selectedDate.add(Duration(days: days));
    if (candidate.isBefore(dateOnly(profile.dob)) ||
        candidate.isAfter(dateOnly(DateTime.now()))) {
      return;
    }
    setState(() {
      selectedDate = candidate;
      message = null;
      _populateForm();
    });
  }

  String _normalizeNumber(String value) {
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    const persianDigits = '۰۱۲۳۴۵۶۷۸۹';
    var normalized = value.trim();
    for (var index = 0; index < 10; index++) {
      normalized = normalized
          .replaceAll(arabicDigits[index], index.toString())
          .replaceAll(persianDigits[index], index.toString());
    }
    return normalized.replaceAll('٫', '.').replaceAll(',', '.');
  }

  String? _validateCount(String? value, int maxValue) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = int.tryParse(_normalizeNumber(value));
    if (parsed == null || parsed < 0 || parsed > maxValue) {
      return 'أدخلي عددًا صحيحًا من 0 إلى $maxValue';
    }
    return null;
  }

  String? _validateTemperature(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = double.tryParse(_normalizeNumber(value));
    if (parsed == null || parsed < 30 || parsed > 45) {
      return 'أدخلي درجة حرارة بين 30 و45°م';
    }
    return null;
  }

  int? _readCount(TextEditingController controller) {
    final value = _normalizeNumber(controller.text);
    return value.isEmpty ? null : int.tryParse(value);
  }

  double? _readTemperature() {
    final value = _normalizeNumber(temperature.text);
    return value.isEmpty ? null : double.tryParse(value);
  }

  DailyLogEntry _entryFromForm() => DailyLogEntry(
        date: selectedDate,
        cryingHours: _readCount(cryingHours),
        feedingCount: _readCount(feedingCount),
        wetDiapers: _readCount(wetDiapers),
        sleepHours: _readCount(sleepHours),
        temperatureCelsius: _readTemperature(),
        notes: notes.text.trim(),
      );

  bool _hasValues() =>
      cryingHours.text.trim().isNotEmpty ||
      feedingCount.text.trim().isNotEmpty ||
      wetDiapers.text.trim().isNotEmpty ||
      sleepHours.text.trim().isNotEmpty ||
      temperature.text.trim().isNotEmpty ||
      notes.text.trim().isNotEmpty;

  Future<void> _saveEntry() async {
    if (saving || !formKey.currentState!.validate()) return;
    if (!_hasValues()) {
      setState(() => message = 'أضيفي قيمة واحدة على الأقل قبل الحفظ.');
      return;
    }

    setState(() {
      saving = true;
      message = null;
    });
    try {
      await widget.store.saveDailyLog(_entryFromForm());
      if (mounted) setState(() => message = 'تم حفظ سجل اليوم على هذا الجهاز.');
    } catch (_) {
      if (mounted) setState(() => message = 'تعذر حفظ السجل. حاولي مرة أخرى.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _copySummary() async {
    if (!formKey.currentState!.validate()) return;
    if (!_hasValues()) {
      setState(() => message = 'أضيفي قيمة واحدة على الأقل لنسخ الملخص.');
      return;
    }
    final entry = _entryFromForm();
    final profile = widget.store.profile!;
    final lines = <String>[
      'Baby Monitor • ' + profile.baby,
      'التاريخ: ' + DateFormat('yyyy-MM-dd').format(entry.date),
      if (entry.cryingHours != null)
        'ساعات البكاء: ' + entry.cryingHours.toString(),
      if (entry.feedingCount != null)
        'عدد الرضعات: ' + entry.feedingCount.toString(),
      if (entry.wetDiapers != null)
        'الحفاضات المبللة: ' + entry.wetDiapers.toString(),
      if (entry.sleepHours != null)
        'ساعات النوم: ' + entry.sleepHours.toString(),
      if (entry.temperatureCelsius != null)
        'درجة الحرارة: ' + entry.temperatureCelsius.toString() + '°م',
      if (entry.notes.trim().isNotEmpty) 'ملاحظات: ' + entry.notes.trim(),
          ];
    try {
      await Clipboard.setData(ClipboardData(text: lines.join('\n')));
      if (mounted) {
        setState(() => message = 'نُسخ الملخص. راجعيه قبل مشاركته.');
      }
    } catch (_) {
      if (mounted) setState(() => message = 'تعذر نسخ الملخص.');
    }
  }

  Future<void> _deleteEntry(DailyLogEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف سجل اليوم؟'),
        content: Text(
          'سيُحذف سجل ' +
              DateFormat('yyyy-MM-dd').format(entry.date) +
              ' من هذا الجهاز.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.store.deleteDailyLog(entry.dateKey);
      if (!mounted) return;
      setState(() {
        if (entry.dateKey == DailyLogEntry.keyFor(selectedDate)) {
          _populateForm();
        }
        message = 'تم حذف السجل.';
      });
    } catch (_) {
      if (mounted) setState(() => message = 'تعذر حذف السجل. حاولي مرة أخرى.');
    }
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    bool decimal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  String _entrySummary(DailyLogEntry entry) {
    final parts = <String>[];
    if (entry.cryingHours != null) {
      parts.add('بكاء: ' + entry.cryingHours.toString() + ' س');
    }
    if (entry.feedingCount != null) {
      parts.add('رضعات: ' + entry.feedingCount.toString());
    }
    if (entry.wetDiapers != null) {
      parts.add('حفاضات: ' + entry.wetDiapers.toString());
    }
    if (entry.sleepHours != null) {
      parts.add('نوم: ' + entry.sleepHours.toString() + ' س');
    }
    if (entry.temperatureCelsius != null) {
      parts.add('حرارة: ' + entry.temperatureCelsius.toString() + '°م');
    }
    if (parts.isEmpty && entry.notes.trim().isEmpty) return 'ملاحظات فقط';
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.store.profile!;
    final today = dateOnly(DateTime.now());
    final isToday =
        DailyLogEntry.keyFor(selectedDate) == DailyLogEntry.keyFor(today);
    final history = widget.store.dailyLogs.values.toList()
      ..sort((left, right) => right.date.compareTo(left.date));

    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'اطمئن',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const Text(
            'سجّلي مؤشرات الرعاية اليومية وشاركيها مع طبيب الأطفال عند الحاجة. تبقى السجلات على هذا الجهاز.',
          ),
          const SizedBox(height: 12),
          const NewbornQuickGuide(),
          const SizedBox(height: 12),
          WeeklyDevelopmentGuide(dateOfBirth: profile.dob),
          const SizedBox(height: 12),
          Card(
            child: Row(
              children: [
                IconButton(
                  tooltip: 'اليوم السابق',
                  onPressed: selectedDate.isAfter(dateOnly(profile.dob))
                      ? () => _moveDate(-1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _chooseDate,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      (isToday ? 'اليوم • ' : '') +
                          DateFormat('yyyy-MM-dd').format(selectedDate),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'اليوم التالي',
                  onPressed: !isToday && selectedDate.isBefore(today)
                      ? () => _moveDate(1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _numberField(
            controller: cryingHours,
            label: 'ساعات البكاء (0–24)',
            validator: (value) => _validateCount(value, 24),
          ),
          _numberField(
            controller: feedingCount,
            label: 'عدد الرضعات',
            validator: (value) => _validateCount(value, 40),
          ),
          _numberField(
            controller: wetDiapers,
            label: 'عدد الحفاضات المبللة',
            validator: (value) => _validateCount(value, 40),
          ),
          _numberField(
            controller: sleepHours,
            label: 'ساعات النوم (0–24)',
            validator: (value) => _validateCount(value, 24),
          ),
          _numberField(
            controller: temperature,
            label: 'درجة الحرارة (°م، اختياري)',
            validator: _validateTemperature,
            decimal: true,
          ),
          TextFormField(
            controller: notes,
            minLines: 2,
            maxLines: 5,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'ملاحظات',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: saving ? null : _saveEntry,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(saving ? 'جارٍ الحفظ...' : 'حفظ سجل اليوم'),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _copySummary,
            icon: const Icon(Icons.copy_outlined),
            label: const Text('نسخ ملخص اليوم لمشاركته'),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: message!.startsWith('تم')
                    ? Colors.green.shade800
                    : Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'السجلات المحفوظة (' + history.length.toString() + ')',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (history.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('ستظهر هنا الأيام التي تحفظين سجلًا لها.'),
              ),
            ),
          for (final entry in history.take(30))
            Card(
              child: ListTile(
                onTap: () {
                  setState(() {
                    selectedDate = entry.date;
                    message = null;
                    _populateForm();
                  });
                },
                title: Text(DateFormat('yyyy-MM-dd').format(entry.date)),
                subtitle: Text(
                  entry.notes.trim().isEmpty
                      ? _entrySummary(entry)
                      : _entrySummary(entry) + ' • ' + entry.notes.trim(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'حذف السجل',
                  onPressed: () => _deleteEntry(entry),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class Vaccines extends StatefulWidget {
  final AppStore store;

  const Vaccines({super.key, required this.store});

  @override
  State<Vaccines> createState() => _VaccinesState();
}

class _VaccinesState extends State<Vaccines> {
  Future<void> _openSource(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showVaccineInfo(BuildContext context, String code) {
    final info = vaccineInformation[code];
    if (info == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.name,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ما الذي يقي منه؟',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(info.protectsAgainst),
                const SizedBox(height: 14),
                const Text(
                  'الآثار الجانبية المتوقعة',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(info.expectedSideEffects),
                const SizedBox(height: 14),
                const Text(
                  'تنبيه مهم',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(info.rareWarnings),
                const SizedBox(height: 16),
                if (info.sourceUrl != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _openSource(info.sourceUrl!);
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('فتح مصدر معلومات السلامة'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _additionalVaccineSection(ChildProfile profile) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.add_circle_outline),
        title: const Text(
          'تطعيمات إضافية للمناقشة مع الطبيب',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'ليست مواعيد وزارة ثابتة؛ الجرعات والفواصل تعتمد على المنتج وحالة الطفل.',
        ),
        children: [
          for (final recommendation in egyptAdditionalVaccineRecommendations)
            ListTile(
              leading: const Icon(Icons.vaccines_outlined),
              title: Text(recommendation.name),
              subtitle: Text(
                recommendation.firstReviewAgeMonths == null
                    ? recommendation.timing + ' • ' + recommendation.scheduleNote
                    : recommendation.timing +
                        ' • أول موعد للمراجعة: ' +
                        DateFormat('yyyy-MM-dd').format(
                          vaccineDueDate(
                            profile.dob,
                            VaccineScheduleDose(
                              recommendation.firstReviewAgeMonths!,
                              recommendation.code,
                            ),
                          ),
                        ) +
                        ' • ' +
                        recommendation.scheduleNote,
              ),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: 'الآثار الجانبية',
                onPressed: () =>
                    _showVaccineInfo(context, recommendation.code),
                icon: const Icon(Icons.info_outline),
              ),
              onTap: () => _showVaccineInfo(context, recommendation.code),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.store.profile!;
    final doses =
        vaccineSchedules[profile.country] ?? const <VaccineScheduleDose>[];
    final grouped = <int, List<VaccineScheduleDose>>{};
    for (final dose in doses) {
      grouped
          .putIfAbsent(dose.ageMonths, () => <VaccineScheduleDose>[])
          .add(dose);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'التطعيمات • ' + profile.country,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'المواعيد محسوبة من تاريخ الميلاد المسجل: ' +
              DateFormat('yyyy-MM-dd').format(profile.dob),
        ),
        const SizedBox(height: 12),
        Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'هذه مواعيد إرشادية من جدول الدولة المبلّغ إلى WHO/UNICEF؛ قد توجد جرعات إضافية أو بدائل أو شروط عمرية. اعتمدي كارت التطعيم ومركز الصحة المحلي، ولا تغيّري موعدًا أو تفوّتي جرعة بناءً على التطبيق وحده.',
            ),
          ),
        ),
        if (profile.country == 'مصر')
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'تمت مراجعة جدول مصر الأساسي: جرعة كبدى B خلال أول 24 ساعة، الدرن وسابين عند الميلاد، الخماسي وسابين وسولك عند 2 و4 و6 أشهر، سابين عند 9 و12 و18 شهرًا، وMMR عند 12 و18 شهرًا، مع فيتامين أ عند 6 و12 و18 شهرًا. الجرعات الإضافية تظهر في قسم منفصل للمراجعة الطبية.',
              ),
            ),
          ),
        for (final month in grouped.keys.toList()..sort())
          _vaccineAgeGroup(
            month,
            grouped[month]!,
            profile,
          ),
        if (profile.country == 'مصر') ...[
          const SizedBox(height: 8),
          _additionalVaccineSection(profile),
          const SizedBox(height: 8),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'بعد التطعيم: اطلبوا مساعدة عاجلة عند صعوبة التنفس، تورم الوجه أو اللسان، تشنج، خمول شديد، حرارة عالية أو مستمرة، أو بكاء حاد لا يهدأ. لا تعطي دواءً أو جرعة إضافية من تلقاء نفسك.',
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        const Text(
          'آخر مراجعة داخل التطبيق: 22 سبتمبر 2026. راجعي كارت التطعيم ومكتب الصحة قبل كل موعد.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: () => _openSource(whoScheduleUrl(profile.country)),
          icon: const Icon(Icons.open_in_new),
          label: const Text('مصدر جدول WHO/UNICEF للدولة'),
        ),
        if (profile.country == 'مصر')
          OutlinedButton.icon(
            onPressed: () => _openSource(egyptMinistryVaccineUrl),
            icon: const Icon(Icons.open_in_new),
            label: const Text('وزارة الصحة المصرية: جدول تطعيمات الأطفال'),
          ),
        if (profile.country == 'مصر')
          OutlinedButton.icon(
            onPressed: () => _openSource(egyptHealthCouncilVaccineUrl),
            icon: const Icon(Icons.open_in_new),
            label: const Text('المجلس الصحي المصري: جدول الجرعات والآثار'),
          ),
        if (profile.country == 'مصر')
          OutlinedButton.icon(
            onPressed: () => _openSource(egyptUnicefVaccineScheduleUrl),
            icon: const Icon(Icons.open_in_new),
            label: const Text('يونيسف مصر: الجدول الروتيني والحملات'),
          ),
        if (profile.country == 'مصر')
          OutlinedButton.icon(
            onPressed: () => _openSource(egyptNewbornGuidanceUrl),
            icon: const Icon(Icons.open_in_new),
            label: const Text('وزارة الصحة: دليل رعاية حديثي الولادة'),
          ),
        if (profile.country == 'الصين')
          OutlinedButton.icon(
            onPressed: () => _openSource(chinaCdcVaccineUrl),
            icon: const Icon(Icons.open_in_new),
            label: const Text('المركز الصيني لمكافحة الأمراض: جدول 2021'),
          ),
        if (profile.country == 'ألمانيا')
          OutlinedButton.icon(
            onPressed: () => _openSource(germanyStikoVaccineUrl),
            icon: const Icon(Icons.open_in_new),
            label: const Text('معهد روبرت كوخ STIKO: جدول 2026'),
          ),
        if (profile.country == 'المملكة المتحدة')
          OutlinedButton.icon(
            onPressed: () => _openSource(ukNhsVaccineUrl),
            icon: const Icon(Icons.open_in_new),
            label: const Text('مصدر NHS البريطاني'),
          ),
        if (profile.country == 'فرنسا')
          OutlinedButton.icon(
            onPressed: () => _openSource(
              'https://www.service-public.gouv.fr/particuliers/vosdroits/F724',
            ),
            icon: const Icon(Icons.open_in_new),
            label: const Text('مصدر فرنسا الرسمي: تقويم التطعيمات'),
          ),
        if (profile.country == 'الولايات المتحدة')
          OutlinedButton.icon(
            onPressed: () => _openSource(
              'https://www.cdc.gov/vaccines/hcp/imz-schedules/child-adolescent-age.html',
            ),
            icon: const Icon(Icons.open_in_new),
            label: const Text('مصدر CDC الأمريكي'),
          ),
      ],
    );
  }

  Widget _vaccineAgeGroup(
    int month,
    List<VaccineScheduleDose> doses,
    ChildProfile profile,
  ) {
    final title = doses.first.ageLabelOverride ??
        (month == 0
            ? 'عند الولادة'
            : month == 1
                ? 'عمر شهر'
                : month == 2
                    ? 'عمر شهرين'
                    : month == 12
                        ? 'عمر سنة'
                        : month == 18
                            ? 'عمر سنة ونصف'
                            : month == 24
                                ? 'عمر سنتين'
                                : 'عمر ' + month.toString() + ' شهرًا');
    final firstDueDate = vaccineDueDate(profile.dob, doses.first);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: month == 0,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          DateFormat('yyyy-MM-dd').format(firstDueDate),
        ),
        children: [
          for (final dose in doses)
            Builder(builder: (context) {
              final id = profile.country +
                  ':' +
                  profile.dob.toIso8601String() +
                  ':' +
                  dose.id;
              final done = widget.store.completedVaccineIds.contains(id);
              final dueDate = vaccineDueDate(profile.dob, dose);
              final overdue =
                  dateOnly(dueDate).isBefore(dateOnly(DateTime.now()));
              final info = vaccineInformation[dose.code];
              final name =
                  info?.name ?? vaccineArabicNames[dose.code] ?? dose.code;
              final conditionalNote =
                  dose.conditional && dose.timingNote == null
                      ? 'قد يعتمد على الموسم أو الحالة الصحية • '
                      : '';
              final doseLabel = dose.doseLabel == null
                  ? ''
                  : dose.doseLabel! + ' • ';
              final dueDateLabel =
                  'الموعد المتوقع: ' + DateFormat('yyyy-MM-dd').format(dueDate);
              final statusLabel = done
                  ? 'سُجّلت كجرعة أُعطيت'
                  : overdue
                      ? 'موعدها مرّ — راجعي مركز التطعيم'
                      : 'لم يحن الموعد بعد';

              return CheckboxListTile(
                value: done,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) async {
                  await widget.store.setVaccineCompleted(id, value ?? false);
                  if (mounted) setState(() {});
                },
                title: Text(name),
                subtitle: Text(
                  (dose.isSupplement ? 'مكمل غذائي • ' : '') +
                      doseLabel +
                      conditionalNote +
                      (dose.timingNote == null ? '' : dose.timingNote! + ' • ') +
                      dueDateLabel + ' • ' + statusLabel,
                ),
                secondary: IconButton(
                  tooltip: 'الآثار الجانبية المحتملة',
                  onPressed: () => _showVaccineInfo(context, dose.code),
                  icon: Icon(
                    dose.isSupplement
                        ? Icons.medication_outlined
                        : dose.conditional
                            ? Icons.info_outline
                            : Icons.vaccines_outlined,
                    color: dose.conditional ? Colors.orange : null,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

DateTime addMonthsClamped(DateTime date, int months) {
  final firstOfMonth = DateTime(date.year, date.month + months, 1);
  final lastDay = DateTime(firstOfMonth.year, firstOfMonth.month + 1, 0).day;
  return DateTime(
    firstOfMonth.year,
    firstOfMonth.month,
    date.day > lastDay ? lastDay : date.day,
  );
}

DateTime vaccineDueDate(DateTime dob, VaccineScheduleDose dose) {
  if (dose.daysAfterBirth != null) {
    return dateOnly(dob.add(Duration(days: dose.daysAfterBirth!)));
  }
  return addMonthsClamped(dob, dose.ageMonths);
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

class _NearbyCareOption {
  final String label;
  final String searchTerm;
  final IconData icon;

  const _NearbyCareOption({
    required this.label,
    required this.searchTerm,
    required this.icon,
  });
}

const _nearbyCareOptions = [
  _NearbyCareOption(
    label: 'مستشفيات أطفال قريبة',
    searchTerm: 'مستشفى أطفال',
    icon: Icons.local_hospital_outlined,
  ),
  _NearbyCareOption(
    label: 'عيادات أطفال قريبة',
    searchTerm: 'عيادة أطفال',
    icon: Icons.medical_services_outlined,
  ),
  _NearbyCareOption(
    label: 'أطباء أطفال قريبون',
    searchTerm: 'طبيب أطفال',
    icon: Icons.person_search_outlined,
  ),
];

class Emergency extends StatefulWidget {
  final AppStore store;

  const Emergency({super.key, required this.store});

  @override
  State<Emergency> createState() => _EmergencyState();
}

class _EmergencyState extends State<Emergency> {
  bool locating = false;
  bool locationResolved = false;
  String locationStatus = 'لم يُحدّد الموقع بعد.';

  static const List<_EmergencyItem> items = [
    _EmergencyItem(
      'صعوبة أو توقف التنفس',
      'تنفس مجهد أو سريع جدًا، انكماش الصدر، أنين، أو توقفات مقلقة.',
      'اطلبي الإسعاف أو اذهبي للطوارئ فورًا.',
    ),
    _EmergencyItem(
      'ازرقاق الشفاه أو الوجه',
      'اللون الأزرق أو الرمادي في الشفاه أو اللسان أو الوجه يحتاج تقييمًا عاجلًا.',
      'لا تنتظري تحسّن اللون من تلقاء نفسه.',
    ),
    _EmergencyItem(
      'حرارة 38° أو أعلى قبل عمر 3 أشهر',
      'الحمى عند رضيع صغير قد تكون علامة عدوى خطيرة حتى لو بدا هادئًا.',
      'توجهي للتقييم الطبي العاجل اليوم؛ لا تعطي دواءً اعتمادًا على التطبيق.',
    ),
    _EmergencyItem(
      'حرارة منخفضة جدًا عند حديث الولادة',
      'درجة أقل من 35.5°م أو برودة شديدة مع ضعف الرضاعة أو الخمول علامة خطر.',
      'اطلبي رعاية طبية عاجلة ولا تنتظري في المنزل.',
    ),
    _EmergencyItem(
      'تشنج أو فقدان استجابة',
      'تشنج، إغماء، ارتخاء مفاجئ، أو عدم استجابة الطفل للصوت واللمس.',
      'اتصلي بالطوارئ فورًا، ولا تضعي شيئًا في فمه.',
    ),
    _EmergencyItem(
      'عدم القدرة على الرضاعة',
      'رفض متكرر للرضاعة أو ضعف واضح في المص، خصوصًا مع قلة الحركة.',
      'يحتاج الطفل إلى تقييم عاجل، خاصة في الأسابيع الأولى.',
    ),
    _EmergencyItem(
      'خمول شديد أو صعوبة الإيقاظ',
      'قلة الحركة، نعاس غير معتاد، أو عدم القدرة على إيقاظه للرضاعة.',
      'اذهبي للطوارئ فورًا، ولا تنتظري موعدًا عاديًا.',
    ),
    _EmergencyItem(
      'علامات جفاف واضحة',
      'حفاضات أقل بكثير من المعتاد مع جفاف الفم أو ضعف الرضاعة أو خمول.',
      'اطلبي المشورة الطبية بسرعة؛ إن كان الطفل ضعيفًا أو لا يستجيب فهذه طوارئ.',
    ),
    _EmergencyItem(
      'قيء أخضر أو دموي',
      'القيء الأخضر أو الدموي، أو القيء المتكرر مع عدم الاحتفاظ بالرضعات.',
      'توجهي للطوارئ فورًا، ولا تحاولي علاج السبب منزليًا.',
    ),
    _EmergencyItem(
      'نزيف شديد أو إصابة أو طفح بنفسجي',
      'نزيف لا يتوقف، إصابة قوية، أو طفح أرجواني لا يبهت عند الضغط.',
      'اتصلي بخدمات الطوارئ فورًا.',
    ),
  ];

  Future<void> _changeLocationConsent(bool value) async {
    if (value) {
      try {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          setState(() {
            locationResolved = false;
            locationStatus =
                'موافقة التطبيق مسجلة، لكن إذن الموقع من الجهاز غير ممنوح.';
          });
        } else {
          setState(() {
            locationResolved = false;
            locationStatus =
                'الإذن متاح. اختاري مستشفى أو عيادة أو طبيب أطفال قريب.';
          });
        }
      } catch (_) {
        setState(() {
          locationResolved = false;
          locationStatus =
              'تعذّر طلب إذن الجهاز. افتحي إعدادات الجهاز أو المتصفح للموقع ثم حاولي مجددًا.';
        });
      }
    } else {
      setState(() {
        locationResolved = false;
        locationStatus = 'أوقفتِ موافقة التطبيق على استخدام الموقع.';
      });
    }
    await widget.store.saveLocationConsent(value);
    if (mounted) setState(() {});
  }

  Uri _nearbyCareSearchUri(
    _NearbyCareOption option, {
    String? coordinates,
  }) {
    final query = coordinates == null
        ? '${option.searchTerm} near me'
        : '${option.searchTerm} near $coordinates';
    return Uri.https(
      'www.google.com',
      '/maps/search/',
      {'api': '1', 'query': query},
    );
  }

  Future<void> _findNearbyCare(_NearbyCareOption option) async {
    final profile = widget.store.profile!;
    if (!profile.locationConsent) {
      setState(() {
        locationResolved = false;
        locationStatus = 'وافقي أولًا على استخدام الموقع من المفتاح أعلاه.';
      });
      return;
    }

    // Safari on iPhone may suspend a PWA after opening a blank tab.
    // Web navigation uses the current page after GPS resolves instead.
    final mapLaunch = maps_navigation.prepareMapsNavigation();
    var mapOpened = false;

    Future<bool> openNearbyCareSearch({String? coordinates}) =>
        maps_navigation.openMapsNavigation(
          mapLaunch,
          _nearbyCareSearchUri(option, coordinates: coordinates),
        );

    setState(() {
      locating = true;
      locationResolved = false;
      locationStatus = 'جارٍ طلب موقعك من الجهاز...';
    });

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        mapOpened = await openNearbyCareSearch();
        if (mounted) {
          setState(() {
            locationStatus = mapOpened
                ? 'إذن GPS غير متاح؛ فتحت الخرائط للبحث عن ${option.label}.'
                : 'إذن الموقع غير متاح. اسمحي بالموقع من إعدادات الجهاز أو المتصفح ثم حاولي مجددًا.';
          });
        }
        return;
      }

      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        mapOpened = await openNearbyCareSearch();
        if (mounted) {
          setState(() {
            locationStatus = mapOpened
                ? 'خدمة GPS متوقفة؛ فتحت الخرائط للبحث عن ${option.label}.'
                : 'خدمة الموقع متوقفة. فعّليها ثم حاولي مرة أخرى.';
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );

      if (!mounted) return;
      setState(() {
        locationResolved = true;
        locationStatus = 'تم تحديد الموقع. جارٍ فتح خرائط ${option.label}...';
      });

      final coordinates =
          position.latitude.toString() + ',' + position.longitude.toString();
      mapOpened = await openNearbyCareSearch(coordinates: coordinates);
      if (!mapOpened) {
        mapOpened = await openNearbyCareSearch();
      }
      if (mounted) {
        setState(() {
          locationStatus = mapOpened
              ? 'تم فتح خرائط البحث عن ${option.label}.'
              : 'تم تحديد الموقع، لكن تعذر فتح الخرائط على هذا الجهاز.';
        });
      }
    } catch (_) {
      mapOpened = await openNearbyCareSearch();
      if (mounted) {
        setState(() {
          locationResolved = false;
          locationStatus = mapOpened
              ? 'تعذر قراءة GPS بدقة؛ فتحت الخرائط للبحث عن ${option.label}.'
              : 'تعذر تحديد الموقع وفتح الخرائط. تحققي من الإذن واتصال الجهاز ثم حاولي مجددًا.';
        });
      }
    } finally {
      if (!mapOpened) maps_navigation.cancelMapsNavigation(mapLaunch);
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> _openSource(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.store.profile!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'الطوارئ',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'إذا كان الطفل لا يتنفس، ازرقّ، تشنج، أو لا يستجيب: اتصلي بخدمات الطوارئ المحلية فورًا. لا تنتظري رد التطبيق.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      locationResolved
                          ? Icons.check_circle
                          : Icons.location_on_outlined,
                      color: locationResolved ? Colors.green : Colors.blueGrey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        locationStatus,
                        style: TextStyle(
                          color:
                              locationResolved ? Colors.green.shade800 : null,
                        ),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: profile.locationConsent,
                  onChanged: locating ? null : _changeLocationConsent,
                  title: const Text('السماح باستخدام GPS عند الطلب'),
                  subtitle: const Text(
                    'لا يُحفظ الموقع في التطبيق؛ يُشارك مع الخرائط فقط عند الضغط على البحث.',
                  ),
                ),
                const Text(
                  'اختاري نوع الخدمة التي تريدين البحث عنها في موقعك الحالي:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                for (final option in _nearbyCareOptions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: locating
                            ? null
                            : () => _findNearbyCare(option),
                        icon: locating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(option.icon),
                        label: Text(
                          locating
                              ? 'جارٍ تحديد الموقع...'
                              : 'ابحث عن ${option.label}',
                        ),
                      ),
                    ),
                  ),
                const Text(
                  'النتائج تأتي من Google Maps وقد تحتاجين إلى التأكد من التخصص وساعات العمل قبل الذهاب.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'علامات تستدعي رعاية عاجلة',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        for (var index = 0; index < items.length; index++)
          Card(
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red.shade900,
                child: Text((index + 1).toString()),
              ),
              title: Text(
                items[index].title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(items[index].description),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    items[index].action,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'مصادر الإرشادات الطبية',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        TextButton.icon(
          onPressed: () => _openSource(
            'https://www.who.int/europe/news-room/fact-sheets/item/newborn-health',
          ),
          icon: const Icon(Icons.open_in_new),
          label: const Text(
              'منظمة الصحة العالمية: علامات الخطر لدى حديثي الولادة'),
        ),
        TextButton.icon(
          onPressed: () => _openSource(
            'https://www.healthychildren.org/English/health-issues/conditions/fever/Pages/When-to-Call-the-Pediatrician.aspx',
          ),
          icon: const Icon(Icons.open_in_new),
          label: const Text('الأكاديمية الأمريكية لطب الأطفال: الحمى'),
        ),
        TextButton.icon(
          onPressed: () => _openSource(
            'https://www.healthychildren.org/English/family-life/health-management/Pages/urgent-care-ER-or-pediatrician-a-parent-guide.aspx',
          ),
          icon: const Icon(Icons.open_in_new),
          label: const Text('الأكاديمية الأمريكية: علامات تستدعي الطوارئ'),
        ),
        TextButton.icon(
          onPressed: () => _openSource(
            'https://www.nhs.uk/symptoms/diarrhoea-and-vomiting/',
          ),
          icon: const Icon(Icons.open_in_new),
          label: const Text('NHS: القيء الأخضر وعلامات الجفاف'),
        ),
      ],
    );
  }
}

class _EmergencyItem {
  final String title;
  final String description;
  final String action;

  const _EmergencyItem(this.title, this.description, this.action);
}

class NewbornAssistant extends StatefulWidget {
  const NewbornAssistant({super.key});

  @override
  State<NewbornAssistant> createState() => _NewbornAssistantState();
}

class _NewbornAssistantState extends State<NewbornAssistant> {
  final NewbornAssistantService service = NewbornAssistantService();
  final TextEditingController question = TextEditingController();
  final List<_AssistantMessage> messages = <_AssistantMessage>[];
  bool sending = false;
  bool assistantConsent = false;
  NewbornAssistantStatus? assistantStatus;
  String? error;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshProviderStatus());
  }

  Future<void> _refreshProviderStatus() async {
    final status = await service.checkStatus();
    if (mounted) setState(() => assistantStatus = status);
  }

  @override
  void dispose() {
    question.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = question.text.trim();
    if (sending || text.isEmpty) return;

    if (!service.isConfigured || assistantStatus?.available != true) {
      setState(() {
        error =
            'خدمة المساعد غير متاحة الآن؛ لم يُرسل سؤالك. حاولي مرة أخرى بعد قليل.';
      });
      return;
    }

    if (!assistantConsent) {
      final consent = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('إرسال السؤال للمساعد؟'),
          content: const Text(
            'سيُرسل نص سؤالك فقط عبر HTTPS إلى خادم المساعد، وقد يعالجه مزوّد نموذج نصي لإعداد إجابة عامة. لا تكتبي اسم الطفل أو عنوانك أو رقم هاتفك أو أي بيانات تعريفية. لا يُرسل الصوت أو الموقع أو ملف الطفل. المساعد لا يشخّص ولا يصف جرعات أدوية.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('أوافق لهذه الجلسة'),
            ),
          ],
        ),
      );
      if (consent != true || !mounted) return;
      assistantConsent = true;
    }

    setState(() {
      sending = true;
      error = null;
      messages.add(_AssistantMessage(text, true));
      question.clear();
    });

    try {
      final answer = await service.ask(text);
      if (mounted) {
        setState(() {
          messages.add(_AssistantMessage(answer, false));
        });
      }
    } on NewbornAssistantException catch (exception) {
      if (mounted) {
        setState(() {
          error = exception.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            error = 'تعذر الاتصال بالمساعد. تحققي من الإنترنت وحاولي لاحقًا.');
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'اسألي عن رعاية حديثي الولادة',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  assistantStatus?.providerConfigured == true
                      ? 'المساعد متصل بخدمة ذكاء اصطناعي آمنة. اكتبي سؤالًا عامًا دون اسم الطفل أو بيانات تعريفية.'
                      : assistantStatus?.isOffline == true
                          ? 'المساعد الإرشادي المحلي متاح للتجربة الآن. مزود الذكاء الاصطناعي الخارجي غير مفعّل؛ لا تكتبي بيانات تعريفية.'
                          : assistantStatus?.available == false
                              ? 'خدمة المساعد غير متاحة الآن؛ حاولي مرة أخرى بعد قليل.'
                              : 'جارٍ التحقق من اتصال المساعد…',
                ),
                const SizedBox(height: 6),
                const Text(
                  'السؤال يُرسل فقط بعد موافقتك. الموقع والصوت وتاريخ الميلاد لا تُرسل إلى المساعد.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
        if (messages.isEmpty)
          const Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(22),
                child: Text(
                  'أمثلة: كيف أميّز صعوبة التنفس؟ ما علامات الرضاعة الكافية؟ كيف أهيئ مكان نوم آمن؟',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return Align(
                  alignment: message.fromUser
                      ? AlignmentDirectional.centerStart
                      : AlignmentDirectional.centerEnd,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 340),
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: message.fromUser
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(message.text),
                  ),
                );
              },
            ),
          ),
        if (sending)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: LinearProgressIndicator(),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Text(
              error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: question,
                    enabled: !sending,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 900,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => unawaited(_send()),
                    decoration: const InputDecoration(
                      hintText: 'اكتبي سؤالك هنا',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: sending ? null : _send,
                  icon: const Icon(Icons.send),
                  tooltip: 'إرسال السؤال',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AssistantMessage {
  final String text;
  final bool fromUser;

  const _AssistantMessage(this.text, this.fromUser);
}
