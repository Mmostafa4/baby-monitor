import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const BabyMonitorApp());

class BabyMonitorApp extends StatefulWidget {
  const BabyMonitorApp({super.key});
  @override State<BabyMonitorApp> createState() => _BabyMonitorAppState();
}

class _BabyMonitorAppState extends State<BabyMonitorApp> {
  final store = AppStore();
  late final Future<void> startup = store.load();

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Baby Monitor',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.pink,
          scaffoldBackgroundColor: const Color(0xFFFDFBFF),
        ),
        home: FutureBuilder<void>(
          future: startup,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return store.profile == null
                ? ConsentAndProfile(store: store)
                : Home(store: store);
          },
        ),
      );
}

class AppStore {
  ChildProfile? profile;
  int launchPriceEgp = 100;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('profile');
    if (raw != null) profile = ChildProfile.fromJson(jsonDecode(raw));
  }

  Future<void> save(ChildProfile value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile', jsonEncode(value.toJson()));
    profile = value;
  }
}

class ChildProfile {
  final String baby, mother, father, country, language;
  final DateTime dob;

  const ChildProfile({
    required this.baby,
    required this.mother,
    required this.father,
    required this.country,
    required this.language,
    required this.dob,
  });

  Map<String, dynamic> toJson() => {
        'baby': baby,
        'mother': mother,
        'father': father,
        'country': country,
        'language': language,
        'dob': dob.toIso8601String(),
      };

  factory ChildProfile.fromJson(Map<String, dynamic> json) => ChildProfile(
        baby: json['baby'] as String,
        mother: json['mother'] as String,
        father: json['father'] as String,
        country: json['country'] as String,
        language: json['language'] as String,
        dob: DateTime.parse(json['dob'] as String),
      );
}

const countries = [
  'مصر', 'السعودية', 'الإمارات', 'الولايات المتحدة', 'المملكة المتحدة',
  'فرنسا', 'ألمانيا', 'الهند', 'الصين', 'تركيا',
];
const languages = ['العربية', 'English', 'Français', 'Deutsch', 'हिन्दी', '中文', 'Türkçe'];

class ConsentAndProfile extends StatefulWidget {
  final AppStore store;
  const ConsentAndProfile({super.key, required this.store});
  @override State<ConsentAndProfile> createState() => _ConsentAndProfileState();
}

class _ConsentAndProfileState extends State<ConsentAndProfile> {
  final form = GlobalKey<FormState>();
  final baby = TextEditingController();
  final mother = TextEditingController();
  final father = TextEditingController();
  String country = 'مصر';
  String language = 'العربية';
  DateTime dob = DateTime.now();
  bool accepted = false;

  @override
  void dispose() {
    baby.dispose();
    mother.dispose();
    father.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: language == 'العربية' ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          body: SafeArea(
            child: Form(
              key: form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Center(child: BabyMonitorLogo(size: 150)),
                  const SizedBox(height: 12),
                  const Center(child: Text('Baby Monitor', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold))),
                  const Center(child: Text('اسمع بكاء طفلك وافهم احتياجه بشكل إرشادي')),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: country,
                    decoration: const InputDecoration(labelText: 'الدولة', border: OutlineInputBorder()),
                    items: countries.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                    onChanged: (value) => setState(() => country = value ?? country),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: language,
                    decoration: const InputDecoration(labelText: 'اللغة', border: OutlineInputBorder()),
                    items: languages.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                    onChanged: (value) => setState(() => language = value ?? language),
                  ),
                  const SizedBox(height: 12),
                  _requiredField(baby, 'اسم الطفل'),
                  _requiredField(mother, 'اسم الأم'),
                  _requiredField(father, 'اسم الأب'),
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
                    color: Colors.amber.shade50,
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('تنبيه: Baby Monitor تطبيق إرشادي، وليس استشارة أو تشخيصًا أو علاجًا طبيًا. في الطوارئ اتصل بخدمات الطوارئ أو اذهب للمستشفى.'),
                    ),
                  ),
                  CheckboxListTile(
                    value: accepted,
                    onChanged: (value) => setState(() => accepted = value ?? false),
                    title: const Text('قرأت التنبيه وأوافق على المتابعة'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  FilledButton(
                    onPressed: !accepted
                        ? null
                        : () async {
                            if (!form.currentState!.validate()) return;
                            await widget.store.save(ChildProfile(
                              baby: baby.text.trim(),
                              mother: mother.text.trim(),
                              father: father.text.trim(),
                              country: country,
                              language: language,
                              dob: dob,
                            ));
                            if (mounted) setState(() {});
                          },
                    child: const Text('ابدأ'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _requiredField(TextEditingController controller, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          validator: (value) => value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
      );
}

class BabyMonitorLogo extends StatelessWidget {
  final double size;
  const BabyMonitorLogo({super.key, this.size = 72});
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

class Home extends StatefulWidget {
  final AppStore store;
  const Home({super.key, required this.store});
  @override State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final profile = widget.store.profile!;
    final pages = [CryPage(), const Reassure(), Vaccines(store: widget.store), const Emergency()];
    return Directionality(
      textDirection: profile.language == 'العربية' ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Baby Monitor • ${profile.baby}'),
          leading: Padding(padding: const EdgeInsets.all(7), child: BabyMonitorLogo(size: 42)),
        ),
        body: pages[tab],
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (value) => setState(() => tab = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.mic), label: 'بكاء'),
            NavigationDestination(icon: Icon(Icons.favorite), label: 'اطمئن'),
            NavigationDestination(icon: Icon(Icons.vaccines), label: 'تطعيمات'),
            NavigationDestination(icon: Icon(Icons.warning_amber), label: 'طوارئ'),
          ],
        ),
      ),
    );
  }
}

class CryPage extends StatefulWidget {
  const CryPage({super.key});
  @override State<CryPage> createState() => _CryPageState();
}
class _CryPageState extends State<CryPage> {
  Timer? timer;
  int seconds = 0;
  bool recording = false;

  void start() {
    timer?.cancel();
    setState(() { recording = true; seconds = 0; });
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (seconds >= 9) {
        timer?.cancel();
        setState(() { seconds = 10; recording = false; });
      } else {
        setState(() => seconds++);
      }
    });
  }

  @override
  void dispose() { timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const BabyMonitorLogo(size: 170),
            const SizedBox(height: 18),
            const Text('حلّل بكاء طفلك', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(recording ? 'جارٍ التسجيل: ${10 - seconds} ثوانٍ' : seconds == 10 ? 'تم التسجيل — التحليل يحتاج خادمًا آمنًا' : 'سجّل 10 ثوانٍ للحصول على احتمال إرشادي'),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: recording ? null : start, icon: const Icon(Icons.mic), label: Text(recording ? 'تسجيل...' : 'ابدأ التسجيل')),
            const SizedBox(height: 14),
            const Text('النتيجة احتمالية وليست تشخيصًا طبيًا.', textAlign: TextAlign.center),
          ]),
        ),
      );
}

class Reassure extends StatelessWidget {
  const Reassure({super.key});
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: const [
    Text('اطمئن', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
    Text('سجّل المؤشرات اليومية وشاركها مع طبيب الأطفال عند الحاجة.'),
    _Field('ساعات البكاء اليومي'), _Field('عدد الرضعات'), _Field('الحفاضات المبللة'), _Field('ساعات النوم'), _Field('درجة الحرارة'), _Field('ملاحظات'),
  ]);
}
class _Field extends StatelessWidget { final String label; const _Field(this.label); @override Widget build(BuildContext context) => Card(child: TextField(decoration: InputDecoration(labelText: label, border: InputBorder.none, contentPadding: const EdgeInsets.all(16)))); }

class Vaccines extends StatelessWidget {
  final AppStore store;
  const Vaccines({super.key, required this.store});
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    Text('التطعيمات • ${store.profile!.country}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    const Text('سيتم تحميل الجدول الرسمي حسب الدولة وتاريخ الميلاد بعد ربط الخادم.'),
    ...['تطعيم حديثي الولادة — حسب البروتوكول المحلي', 'الجرعة التالية — يحددها تاريخ الميلاد', 'تذكير التطعيم — قابل للتحديث من الإدارة'].map((item) => Card(child: ListTile(title: Text(item), leading: const Icon(Icons.vaccines), trailing: const Icon(Icons.notifications_none)))),
  ]);
}

class Emergency extends StatelessWidget {
  const Emergency({super.key});
  Future<void> locate() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
    final position = await Geolocator.getCurrentPosition();
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}+children%27s+hospital');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('طوارئ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red)),
    const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('اذهب للطوارئ فورًا عند صعوبة التنفس، ازرقاق، تشنج، فقدان وعي، خمول شديد، نزيف، قيء أخضر أو متكرر، جفاف واضح، أو تدهور سريع.'))),
    FilledButton.icon(onPressed: locate, icon: const Icon(Icons.location_on), label: const Text('اعثر على أقرب مستشفى أطفال')),
    const Text('الموقع اختياري ويُستخدم لفتح نتائج الخرائط القريبة فقط.'),
  ]);
}
