import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/vaccine_schedules.dart';
import 'services/cry_recording_service.dart';
import 'services/newborn_assistant_service.dart';
import 'widgets/baby_monitor_logo.dart';

void main() => runApp(const BabyMonitorApp());

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Baby Monitor',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.pink,
        scaffoldBackgroundColor: const Color(0xfffdfbff),
      ),
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
              body: Center(child: Text('تعذر فتح بيانات التطبيق على هذا الجهاز.')),
            );
          }
          return store.profile == null
              ? ConsentAndProfile(
                  store: store,
                  onSaved: () => setState(() {}),
                )
              : Home(store: store);
        },
      ),
    );
  }
}

class AppStore {
  ChildProfile? profile;
  final Set<String> completedVaccineIds = <String>{};

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
  }

  Future<void> save(ChildProfile value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('profile', value.toJson());
    profile = value;
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
}

class ChildProfile {
  final String baby;
  final String mother;
  final String father;
  final String country;
  final String language;
  final DateTime dob;
  final bool locationConsent;

  const ChildProfile({
    required this.baby,
    required this.mother,
    required this.father,
    required this.country,
    required this.language,
    required this.dob,
    this.locationConsent = false,
  });

  ChildProfile copyWith({bool? locationConsent}) => ChildProfile(
        baby: baby,
        mother: mother,
        father: father,
        country: country,
        language: language,
        dob: dob,
        locationConsent: locationConsent ?? this.locationConsent,
      );

  String toJson() => jsonEncode({
        'baby': baby,
        'mother': mother,
        'father': father,
        'country': country,
        'language': language,
        'dob': dob.toIso8601String(),
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

const List<String> languages = [
  'العربية',
  'English',
  'Français',
  'Deutsch',
  'हिन्दी',
  '中文',
  'Türkçe',
];

class ConsentAndProfile extends StatefulWidget {
  final AppStore store;
  final VoidCallback onSaved;

  const ConsentAndProfile({
    super.key,
    required this.store,
    required this.onSaved,
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
  String language = 'العربية';
  DateTime dob = DateTime.now();
  bool acceptedMedicalNotice = false;
  bool locationConsent = false;
  bool saving = false;
  String? locationNotice;

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

    if (locationConsent) {
      try {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          locationNotice = 'لم يُمنح إذن الموقع من الجهاز. يمكنك تغييره لاحقًا من صفحة الطوارئ.';
        } else {
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 5),
            ),
          );
        }
      } catch (_) {
        locationNotice = 'احفظي الملف أولًا؛ يمكن طلب إذن الموقع من صفحة الطوارئ.';
      }
    }

    await widget.store.save(
      ChildProfile(
        baby: baby.text.trim(),
        mother: mother.text.trim(),
        father: father.text.trim(),
        country: country,
        language: language,
        dob: dob,
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
                DropdownButtonFormField<String>(
                  value: language,
                  items: languages
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => language = value!),
                  decoration: const InputDecoration(
                    labelText: 'اللغة',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                _textField(baby, 'اسم الطفل'),
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
                const Card(
                  color: Color(0xfffff5d8),
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'التطبيق إرشادي ولا يقدم تشخيصًا أو علاجًا. عند ظهور علامة طوارئ، اطلبي الرعاية الطبية فورًا.',
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
                    title: const Text('أوافق على استخدام موقعي عند طلب مستشفى قريب'),
                    subtitle: const Text(
                      'سيطلب الجهاز إذن GPS الآن. لن يحفظ التطبيق إحداثياتك أو يرسلها إلى خادمه؛ تُستخدم فقط لفتح الخرائط عند طلبك.',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: saving ? null : _saveProfile,
                  child: Text(saving ? 'جارٍ الحفظ...' : 'ابدأ'),
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
        validator: (value) => value == null || value.trim().isEmpty
            ? 'هذا الحقل مطلوب'
            : null,
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

  const Home({super.key, required this.store});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  final GlobalKey<_CryPageState> cryPageKey = GlobalKey<_CryPageState>();

  @override
  Widget build(BuildContext context) {
    final profile = widget.store.profile!;
    final pages = [
      CryPage(key: cryPageKey),
      const Reassure(),
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
            NavigationDestination(icon: Icon(Icons.vaccines), label: 'التطعيمات'),
            NavigationDestination(icon: Icon(Icons.warning_amber), label: 'الطوارئ'),
            NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'اسألي'),
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

class _CryPageState extends State<CryPage> {
  final CryRecordingService recorder = CryRecordingService();
  final AudioPlayer player = AudioPlayer();
  StreamSubscription<void>? playerCompleteSubscription;
  Uint8List? audioPreview;
  Timer? timer;
  int seconds = 0;
  bool recording = false;
  bool busy = false;
  bool playing = false;
  String message = '';

  @override
  void initState() {
    super.initState();
    playerCompleteSubscription = player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => playing = false);
    });
  }

  Future<void> start() async {
    if (recording || busy) return;
    await player.stop();
    _clearPreview();
    setState(() {
      busy = true;
      message = '';
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
          message = 'تعذر بدء التسجيل. اسمحي بالميكروفون في Safari ثم حاولي مجددًا.';
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
                ' كيلوبايت محليًا. يمكنك الاستماع ثم حذف التسجيل؛ لا يُرفع الصوت ولا يُحلل البكاء بعد.';
          } else {
            audioPreview = null;
            message = 'لم يصل صوت إلى المسجل. تحققي من إذن الميكروفون، ومن أن الصفحة مفتوحة عبر HTTPS في Safari، ثم أعيدي المحاولة.';
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
          message = 'تعذر إكمال التسجيل. تحققي من إذن الميكروفون وحاولي مرة أخرى.';
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
          message = 'تعذر تشغيل التسجيل على هذا المتصفح. يمكنك حذفه وإعادة المحاولة.';
          playing = false;
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
        message = 'تم حذف التسجيل من الذاكرة.';
      });
    }
  }

  Future<void> discardCaptureAndPreview() async {
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
          message = 'تعذر حذف الصوت عند مغادرة الصفحة. عودي إلى الصوت واستخدمي حذف التسجيل.';
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
        if (recording)
          LinearProgressIndicator(value: seconds / 10),
        const SizedBox(height: 10),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'الصوت يبقى مؤقتًا في ذاكرة التطبيق للاستماع، ويمكن حذفه فورًا. يُحذف عند إغلاق الصفحة؛ لا يُحفظ كملف ولا يُرفع إلى خادم. تفسير البكاء غير متاح الآن.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: FilledButton.icon(
            onPressed: busy || recording ? null : start,
            icon: const Icon(Icons.mic),
            label: Text(busy ? 'جارٍ تجهيز الميكروفون...' : 'ابدأ التسجيل'),
          ),
        ),
        if (audioPreview != null) ...[
          const SizedBox(height: 8),
          Center(
            child: OutlinedButton.icon(
              onPressed: busy ? null : _playPreview,
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              label: Text(playing ? 'إيقاف الاستماع' : 'استمع للتسجيل'),
            ),
          ),
          Center(
            child: TextButton.icon(
              onPressed: busy ? null : _deletePreview,
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
        if (message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Text(message, textAlign: TextAlign.center),
          ),
        const SizedBox(height: 10),
        const Text(
          'إذا كنت قلقة على تنفس الطفل أو صحته، اطلبي الرعاية الطبية ولا تعتمدي على التسجيل.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class Reassure extends StatelessWidget {
  const Reassure({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text('اطمئن', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        Text('سجّلي المؤشرات اليومية وشاركيها مع طبيب الأطفال عند الحاجة.'),
        _Field('ساعات البكاء اليومي'),
        _Field('عدد الرضعات'),
        _Field('الحفاضات المبللة'),
        _Field('ساعات النوم'),
        _Field('درجة الحرارة'),
        _Field('ملاحظات'),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final String label;

  const _Field(this.label);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
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

  @override
  Widget build(BuildContext context) {
    final profile = widget.store.profile!;
    final doses = vaccineSchedules[profile.country] ?? const <VaccineScheduleDose>[];
    final grouped = <int, List<VaccineScheduleDose>>{};
    for (final dose in doses) {
      grouped.putIfAbsent(dose.ageMonths, () => <VaccineScheduleDose>[]).add(dose);
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
        const Card(
          color: Color(0xfffff5d8),
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'هذه مواعيد إرشادية من جدول الدولة المبلّغ إلى WHO/UNICEF؛ قد توجد جرعات إضافية أو بدائل أو شروط عمرية. اعتمدي كارت التطعيم ومركز الصحة المحلي، ولا تغيّري موعدًا أو تفوّتي جرعة بناءً على التطبيق وحده.',
            ),
          ),
        ),
        for (final month in grouped.keys.toList()..sort())
          _vaccineAgeGroup(
            month,
            grouped[month]!,
            profile,
          ),
        const SizedBox(height: 8),
        const Text(
          'تاريخ إدخال البيانات: 20 سبتمبر 2026. راجعي المصدر الرسمي قبل كل موعد.',
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
              final overdue = dateOnly(dueDate).isBefore(dateOnly(DateTime.now()));
              final name = vaccineArabicNames[dose.code] ?? dose.code;
              final conditionalNote = dose.conditional && dose.timingNote == null
                  ? 'قد يعتمد على الموسم أو الحالة الصحية • '
                  : '';

              return CheckboxListTile(
                value: done,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) async {
                  await widget.store.setVaccineCompleted(id, value ?? false);
                  if (mounted) setState(() {});
                },
                title: Text(name),
                subtitle: Text(
                  conditionalNote +
                      (dose.timingNote == null ? '' : dose.timingNote! + ' • ') +
                      (done
                          ? 'سُجّلت كجرعة أُعطيت'
                          : overdue
                              ? 'موعدها مرّ — راجعي مركز التطعيم'
                              : 'الموعد المتوقع: ' +
                                  DateFormat('yyyy-MM-dd').format(dueDate)),
                ),
                secondary: dose.conditional
                    ? const Icon(Icons.info_outline, color: Colors.orange)
                    : Icon(
                        done ? Icons.check_circle : Icons.vaccines_outlined,
                        color: done ? Colors.green : null,
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
            locationStatus = 'موافقة التطبيق مسجلة، لكن إذن الموقع من الجهاز غير ممنوح.';
          });
        } else {
          setState(() {
            locationResolved = false;
            locationStatus = 'الإذن متاح. اضغطي تحديد مكاني لفتح المستشفى القريب.';
          });
        }
      } catch (_) {
        setState(() {
          locationResolved = false;
          locationStatus = 'تعذّر طلب إذن الجهاز. افتحي إعدادات Safari للموقع ثم حاولي مجددًا.';
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

  Future<void> _findNearbyHospital() async {
    final profile = widget.store.profile!;
    if (!profile.locationConsent) {
      setState(() {
        locationResolved = false;
        locationStatus = 'وافقي أولًا على استخدام الموقع من المفتاح أعلاه.';
      });
      return;
    }

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
        setState(() {
          locationStatus = 'إذن GPS غير متاح. اسمحي بالموقع لهذا الموقع من إعدادات Safari.';
        });
        return;
      }

      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() {
          locationStatus = 'خدمة الموقع متوقفة في الجهاز. فعّليها ثم حاولي مرة أخرى.';
        });
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
        locationStatus = 'تم تحديد موقعك الآن ✓. سيُستخدم لفتح الخرائط فقط.';
      });

      final coordinates =
          position.latitude.toString() + ',' + position.longitude.toString();
      final uri = Uri.https(
        'maps.apple.com',
        '/',
        {'q': 'مستشفى أطفال', 'll': coordinates},
      );
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        setState(() {
          locationStatus = 'تم تحديد الموقع ✓، لكن تعذر فتح الخرائط على هذا الجهاز.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          locationResolved = false;
          locationStatus = 'تعذر تحديد الموقع. تحققي من إذن GPS واتصال الجهاز ثم حاولي مجددًا.';
        });
      }
    } finally {
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
        const Card(
          color: Color(0xffffeeee),
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
                          color: locationResolved ? Colors.green.shade800 : null,
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
                    'الموقع لا يُحفظ في الملف ولا يُرسل إلى خادم التطبيق.',
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: locating ? null : _findNearbyHospital,
                    icon: locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.map_outlined),
                    label: Text(
                      locating ? 'جارٍ تحديد الموقع...' : 'ابحث عن مستشفى أطفال قريب',
                    ),
                  ),
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
          label: const Text('منظمة الصحة العالمية: علامات الخطر لدى حديثي الولادة'),
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
  final NewbornAssistantService service = const NewbornAssistantService();
  final TextEditingController question = TextEditingController();
  final List<_AssistantMessage> messages = <_AssistantMessage>[];
  bool sending = false;
  String? error;

  @override
  void dispose() {
    question.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = question.text.trim();
    if (sending || text.isEmpty) return;

    if (!service.isConfigured) {
      setState(() {
        error = 'المساعد الذكي غير متصل في هذه النسخة؛ لم يُرسل سؤالك. يحتاج التطبيق إلى خدمة آمنة على الخادم قبل تفعيله.';
      });
      return;
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
        setState(() => messages.add(_AssistantMessage(answer, false)));
      }
    } on NewbornAssistantException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'تعذر الاتصال بالمساعد. تحققي من الإنترنت وحاولي لاحقًا.');
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
                  service.isConfigured
                      ? 'المساعد متصل. اكتبي سؤالًا عامًا دون اسم الطفل أو بيانات تعريفية.'
                      : 'المساعد الذكي غير متصل بعد. إعداد الخادم ومفتاح الخدمة غير موجودين؛ لن يُرسل السؤال حتى يتم الإعداد.',
                ),
                const SizedBox(height: 6),
                const Text(
                  'الموقع والصوت وتاريخ الميلاد لا تُرسل إلى المساعد. إجاباته تثقيفية وليست تشخيصًا؛ وفي الطوارئ استخدمي صفحة الطوارئ.',
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
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
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
