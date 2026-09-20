import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';

import 'services/cry_recording_service.dart';
import 'widgets/baby_monitor_logo.dart';

void main() => runApp(const BabyMonitorApp());

class BabyMonitorApp extends StatefulWidget {
  const BabyMonitorApp({super.key});
  @override State<BabyMonitorApp> createState() => _BabyMonitorAppState();
}

class _BabyMonitorAppState extends State<BabyMonitorApp> {
  final store = AppStore();
  late final Future<void> startup = store.load();
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Baby Monitor',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.pink, scaffoldBackgroundColor: const Color(0xfffdfbff)),
    home: FutureBuilder<void>(future: startup, builder: (_, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      return store.profile == null
          ? ConsentAndProfile(
              store: store,
              onSaved: () => setState(() {}),
            )
          : Home(store: store);
    }),
  );
}

class AppStore {
  ChildProfile? profile;
  int launchPriceEgp = 100;
  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString('profile');
    if (raw == null) return;

    try {
      profile = ChildProfile.fromJson(raw);
    } on FormatException {
      // Return to onboarding instead of getting stuck on a damaged local profile.
      await preferences.remove('profile');
    }
  }

  Future<void> save(ChildProfile value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('profile', value.toJson());
    profile = value;
  }
}
class ChildProfile {
  final String baby, mother, father, country, language; final DateTime dob;
  const ChildProfile({required this.baby, required this.mother, required this.father, required this.country, required this.language, required this.dob});
  String toJson() => jsonEncode({
        'baby': baby,
        'mother': mother,
        'father': father,
        'country': country,
        'language': language,
        'dob': dob.toIso8601String(),
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
          );
        }
      }
    } on FormatException {
      // Read profiles saved by the earlier pipe-delimited MVP version.
    }

    final legacy = value.split('|');
    if (legacy.length != 6) throw const FormatException('Invalid child profile.');
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
const countries = ['مصر','السعودية','الإمارات','الولايات المتحدة','المملكة المتحدة','فرنسا','ألمانيا','الهند','الصين','تركيا'];
const languages = ['العربية','English','Français','Deutsch','हिन्दी','中文','Türkçe'];

class ConsentAndProfile extends StatefulWidget {
  final AppStore store;
  final VoidCallback onSaved;

  const ConsentAndProfile({
    super.key,
    required this.store,
    required this.onSaved,
  });

  @override
  State<ConsentAndProfile> createState() => _ConsentState();
}
class _ConsentState extends State<ConsentAndProfile> {
  final form = GlobalKey<FormState>(); final baby=TextEditingController(), mom=TextEditingController(), dad=TextEditingController();
  String country='مصر', language='العربية'; DateTime dob=DateTime.now(); bool accepted=false;
  @override void dispose(){baby.dispose(); mom.dispose(); dad.dispose(); super.dispose();}
  @override Widget build(BuildContext context) => Directionality(textDirection:TextDirection.rtl, child:Scaffold(body:SafeArea(child:Form(key:form,child:ListView(padding:const EdgeInsets.all(20),children:[
    const Center(child:BabyMonitorLogo(size:150)), const SizedBox(height:10), const Center(child:Text('Baby Monitor',style:TextStyle(fontSize:30,fontWeight:FontWeight.bold))), const Center(child:Text('تسجيل محلي تجريبي ومعلومات إرشادية لرعاية طفلك')), const SizedBox(height:24),
    DropdownButtonFormField(value:country,items:countries.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>setState(()=>country=x!),decoration:const InputDecoration(labelText:'الدولة',border:OutlineInputBorder())), const SizedBox(height:12),
    DropdownButtonFormField(value:language,items:languages.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>setState(()=>language=x!),decoration:const InputDecoration(labelText:'اللغة',border:OutlineInputBorder())), const SizedBox(height:12),
    _field(baby,'اسم الطفل'), _field(mom,'اسم الأم'), _field(dad,'اسم الأب'), ListTile(contentPadding:EdgeInsets.zero,title:const Text('تاريخ ميلاد الطفل'),subtitle:Text(DateFormat('yyyy-MM-dd').format(dob)),trailing:const Icon(Icons.calendar_month),onTap:()async{final x=await showDatePicker(context:context,initialDate:dob,firstDate:DateTime(2015),lastDate:DateTime.now());if(x!=null)setState(()=>dob=x);}),
    const Card(color:Color(0xfffff5d8),child:Padding(padding:EdgeInsets.all(14),child:Text('تنبيه: التطبيق إرشادي وليس استشارة أو تشخيصًا أو علاجًا طبيًا. في الطوارئ اتصل بخدمات الطوارئ أو اذهب للمستشفى.'))), CheckboxListTile(value:accepted,onChanged:(x)=>setState(()=>accepted=x??false),title:const Text('قرأت التنبيه وأوافق على المتابعة'),controlAffinity:ListTileControlAffinity.leading),
    FilledButton(
      onPressed: !accepted
          ? null
          : () async {
              if (!form.currentState!.validate()) return;
              await widget.store.save(
                ChildProfile(
                  baby: baby.text.trim(),
                  mother: mom.text.trim(),
                  father: dad.text.trim(),
                  country: country,
                  language: language,
                  dob: dob,
                ),
              );
              if (mounted) widget.onSaved();
            },
      child: const Text('ابدأ'),
    )
  ])))));
  Widget _field(TextEditingController c,String label)=>Padding(padding:const EdgeInsets.only(bottom:12),child:TextFormField(controller:c,validator:(v)=>v==null||v.trim().isEmpty?'هذا الحقل مطلوب':null,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder())));
}

class Home extends StatefulWidget { final AppStore store; const Home({super.key,required this.store}); @override State<Home> createState()=>_HomeState(); }
class _HomeState extends State<Home>{int tab=0; @override Widget build(BuildContext c){final p=widget.store.profile!;final pages=[const CryPage(),const Reassure(),Vaccines(store:widget.store),const Emergency()];return Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:Text('Baby Monitor • ${p.baby}'),leading:const Padding(padding:EdgeInsets.all(7),child:BabyMonitorLogo(size:42))),body:pages[tab],bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(x)=>setState(()=>tab=x),destinations:const[NavigationDestination(icon:Icon(Icons.mic),label:'بكاء'),NavigationDestination(icon:Icon(Icons.favorite),label:'اطمئن'),NavigationDestination(icon:Icon(Icons.vaccines),label:'تطعيمات'),NavigationDestination(icon:Icon(Icons.warning_amber),label:'طوارئ')])));}}

class CryPage extends StatefulWidget {
  const CryPage({super.key});
  @override
  State<CryPage> createState() => _CryPageState();
}

class _CryPageState extends State<CryPage> {
  final recorder = CryRecordingService();
  Timer? timer;
  int seconds = 0;
  bool recording = false;
  bool busy = false;
  String message = '';

  Future<void> start() async {
    if (recording || busy) return;
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

      timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (seconds >= 9) {
          timer.cancel();
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
        setState(() => message = 'تعذر بدء التسجيل. تحقق من إذن الميكروفون وحاول مرة أخرى.');
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
      await recorder.stopAndDelete();
      if (mounted) {
        setState(() {
          recording = false;
          busy = false;
          seconds = 10;
          message = 'اكتمل التسجيل وحُذف الصوت المؤقت. Analysis is currently unavailable. لم يُرسل الصوت إلى خادم.';
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
          message = 'تعذر إكمال التسجيل أو حذف الصوت المؤقت. حاول مرة أخرى.';
        });
      }
    }
  }

  Future<void> cancelRecording() async {
    final wasRecording = recording;
    timer?.cancel();
    setState(() => busy = true);
    try {
      await recorder.cancel();
      if (mounted) {
        setState(() {
          recording = false;
          busy = false;
          seconds = 0;
          message = wasRecording
              ? 'تم إلغاء التسجيل وحذف الصوت المؤقت.'
              : 'تم حذف التسجيل المؤقت بنجاح.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          recording = false;
          busy = false;
          message = error is CryRecordingException
              ? error.message
              : 'تعذر حذف الصوت المؤقت. حاول مرة أخرى.';
        });
      }
    }
  }

  Future<void> _cancelQuietly() async {
    try {
      await recorder.cancel();
    } catch (_) {
      // The UI reports the original recording error. Disposal tries cleanup again.
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    unawaited(recorder.dispose().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const BabyMonitorLogo(size: 170),
              const SizedBox(height: 18),
              const Text('تسجيل بكاء الطفل', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(recording
                  ? 'جارٍ التسجيل: ${10 - seconds} ثوانٍ'
                  : seconds == 10
                      ? 'اكتمل التسجيل'
                      : 'سجّل 10 ثوانٍ كتسجيل محلي تجريبي.'),
              const SizedBox(height: 8),
              const Text(
                'Analysis is currently unavailable.\nالتحليل غير متاح حاليًا. التسجيل تجريبي، ويُحذف الصوت ولا يُرسل إلى خادم.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: busy || recording ? null : start,
                icon: const Icon(Icons.mic),
                label: Text(busy ? 'جارٍ تجهيز التسجيل...' : 'ابدأ التسجيل'),
              ),
              if (recording || recorder.hasPendingCleanup)
                TextButton.icon(
                  onPressed: busy ? null : cancelRecording,
                  icon: Icon(
                    recording ? Icons.delete_outline : Icons.refresh,
                  ),
                  label: Text(
                    recording ? 'إلغاء وحذف التسجيل' : 'إعادة محاولة الحذف',
                  ),
                ),
              if (message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text(message, textAlign: TextAlign.center),
                ),
              const SizedBox(height: 12),
              const Text('التطبيق إرشادي ولا يشخّص حالة طبية.', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
class Reassure extends StatelessWidget{const Reassure({super.key});@override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(16),children:const[Text('اطمئن',style:TextStyle(fontSize:28,fontWeight:FontWeight.bold)),Text('سجّل المؤشرات اليومية وشاركها مع طبيب الأطفال عند الحاجة.'),_Field('ساعات البكاء اليومي'),_Field('عدد الرضعات'),_Field('الحفاضات المبللة'),_Field('ساعات النوم'),_Field('درجة الحرارة'),_Field('ملاحظات')]);}
class _Field extends StatelessWidget{final String label;const _Field(this.label);@override Widget build(BuildContext c)=>Card(child:TextField(decoration:InputDecoration(labelText:label,border:InputBorder.none,contentPadding:const EdgeInsets.all(16))));}
class Vaccines extends StatelessWidget{final AppStore store;const Vaccines({super.key,required this.store});@override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(16),children:[Text('التطعيمات • ${store.profile!.country}',style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),const Text('سيتم تحميل الجدول الرسمي حسب الدولة وتاريخ الميلاد بعد ربط الخادم.'),...['تطعيم حديثي الولادة — حسب البروتوكول المحلي','الجرعة التالية — يحددها تاريخ الميلاد','تذكير التطعيم — قابل للتحديث من الإدارة'].map((x)=>Card(child:ListTile(title:Text(x),leading:const Icon(Icons.vaccines),trailing:const Icon(Icons.notifications_none))))]);}
class Emergency extends StatelessWidget{const Emergency({super.key});@override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(16),children:[const Text('طوارئ',style:TextStyle(fontSize:28,fontWeight:FontWeight.bold,color:Colors.red)),const Card(child:Padding(padding:EdgeInsets.all(16),child:Text('اذهب للطوارئ فورًا عند صعوبة التنفس، ازرقاق، تشنج، فقدان وعي، خمول شديد، نزيف، قيء أخضر أو متكرر، جفاف واضح، أو تدهور سريع.'))),const Text('استخدم زر الموقع في النسخة المتصلة للعثور على مستشفى أطفال قريب.')]);}
