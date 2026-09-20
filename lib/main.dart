import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      return store.profile == null ? ConsentAndProfile(store: store) : Home(store: store);
    }),
  );
}

class AppStore {
  ChildProfile? profile;
  int launchPriceEgp = 100;
  Future<void> load() async { final p = await SharedPreferences.getInstance(); final raw = p.getString('profile'); if (raw != null) profile = ChildProfile.fromJson(raw); }
  Future<void> save(ChildProfile value) async { final p = await SharedPreferences.getInstance(); await p.setString('profile', value.toJson()); profile = value; }
}
class ChildProfile {
  final String baby, mother, father, country, language; final DateTime dob;
  const ChildProfile({required this.baby, required this.mother, required this.father, required this.country, required this.language, required this.dob});
  String toJson() => '${baby.replaceAll('|', '')}|${mother.replaceAll('|', '')}|${father.replaceAll('|', '')}|$country|$language|${dob.toIso8601String()}';
  factory ChildProfile.fromJson(String value) { final p = value.split('|'); return ChildProfile(baby:p[0], mother:p[1], father:p[2], country:p[3], language:p[4], dob:DateTime.parse(p[5])); }
}
const countries = ['مصر','السعودية','الإمارات','الولايات المتحدة','المملكة المتحدة','فرنسا','ألمانيا','الهند','الصين','تركيا'];
const languages = ['العربية','English','Français','Deutsch','हिन्दी','中文','Türkçe'];

class ConsentAndProfile extends StatefulWidget { final AppStore store; const ConsentAndProfile({super.key, required this.store}); @override State<ConsentAndProfile> createState() => _ConsentState(); }
class _ConsentState extends State<ConsentAndProfile> {
  final form = GlobalKey<FormState>(); final baby=TextEditingController(), mom=TextEditingController(), dad=TextEditingController();
  String country='مصر', language='العربية'; DateTime dob=DateTime.now(); bool accepted=false;
  @override void dispose(){baby.dispose(); mom.dispose(); dad.dispose(); super.dispose();}
  @override Widget build(BuildContext context) => Directionality(textDirection: language=='العربية'?TextDirection.rtl:TextDirection.ltr, child:Scaffold(body:SafeArea(child:Form(key:form,child:ListView(padding:const EdgeInsets.all(20),children:[
    const Center(child:BabyMonitorLogo(size:150)), const SizedBox(height:10), const Center(child:Text('Baby Monitor',style:TextStyle(fontSize:30,fontWeight:FontWeight.bold))), const Center(child:Text('اسمع بكاء طفلك وافهم احتياجه بشكل إرشادي')), const SizedBox(height:24),
    DropdownButtonFormField(value:country,items:countries.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>setState(()=>country=x!),decoration:const InputDecoration(labelText:'الدولة',border:OutlineInputBorder())), const SizedBox(height:12),
    DropdownButtonFormField(value:language,items:languages.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>setState(()=>language=x!),decoration:const InputDecoration(labelText:'اللغة',border:OutlineInputBorder())), const SizedBox(height:12),
    _field(baby,'اسم الطفل'), _field(mom,'اسم الأم'), _field(dad,'اسم الأب'), ListTile(contentPadding:EdgeInsets.zero,title:const Text('تاريخ ميلاد الطفل'),subtitle:Text(DateFormat('yyyy-MM-dd').format(dob)),trailing:const Icon(Icons.calendar_month),onTap:()async{final x=await showDatePicker(context:context,initialDate:dob,firstDate:DateTime(2015),lastDate:DateTime.now());if(x!=null)setState(()=>dob=x);}),
    const Card(color:Color(0xfffff5d8),child:Padding(padding:EdgeInsets.all(14),child:Text('تنبيه: التطبيق إرشادي وليس استشارة أو تشخيصًا أو علاجًا طبيًا. في الطوارئ اتصل بخدمات الطوارئ أو اذهب للمستشفى.'))), CheckboxListTile(value:accepted,onChanged:(x)=>setState(()=>accepted=x??false),title:const Text('قرأت التنبيه وأوافق على المتابعة'),controlAffinity:ListTileControlAffinity.leading),
    FilledButton(onPressed:!accepted?null:()async{if(!form.currentState!.validate())return;await widget.store.save(ChildProfile(baby:baby.text.trim(),mother:mom.text.trim(),father:dad.text.trim(),country:country,language:language,dob:dob));if(mounted)setState((){});},child:const Text('ابدأ'))
  ])))));
  Widget _field(TextEditingController c,String label)=>Padding(padding:const EdgeInsets.only(bottom:12),child:TextFormField(controller:c,validator:(v)=>v==null||v.trim().isEmpty?'هذا الحقل مطلوب':null,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder())));
}

class BabyMonitorLogo extends StatelessWidget { final double size; const BabyMonitorLogo({super.key,this.size=72}); @override Widget build(BuildContext c)=>ClipRRect(borderRadius:BorderRadius.circular(size*.23),child:SvgPicture.asset('assets/branding/baby_monitor_logo.svg',width:size,height:size,semanticsLabel:'Baby Monitor logo')); }
class Home extends StatefulWidget { final AppStore store; const Home({super.key,required this.store}); @override State<Home> createState()=>_HomeState(); }
class _HomeState extends State<Home>{int tab=0; @override Widget build(BuildContext c){final p=widget.store.profile!;final pages=[const CryPage(),const Reassure(),Vaccines(store:widget.store),const Emergency()];return Directionality(textDirection:p.language=='العربية'?TextDirection.rtl:TextDirection.ltr,child:Scaffold(appBar:AppBar(title:Text('Baby Monitor • ${p.baby}'),leading:const Padding(padding:EdgeInsets.all(7),child:BabyMonitorLogo(size:42))),body:pages[tab],bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(x)=>setState(()=>tab=x),destinations:const[NavigationDestination(icon:Icon(Icons.mic),label:'بكاء'),NavigationDestination(icon:Icon(Icons.favorite),label:'اطمئن'),NavigationDestination(icon:Icon(Icons.vaccines),label:'تطعيمات'),NavigationDestination(icon:Icon(Icons.warning_amber),label:'طوارئ')])));}}

class CryPage extends StatefulWidget { const CryPage({super.key}); @override State<CryPage> createState()=>_CryPageState(); }
class _CryPageState extends State<CryPage>{final recorder=AudioRecorder();Timer? timer;int seconds=0;bool recording=false;String? path;String message='';
  Future<void> start() async { if(!await recorder.hasPermission()){setState(()=>message='نحتاج إذن الميكروفون لبدء التسجيل.');return;} final dir=await getTemporaryDirectory();path='${dir.path}/baby_cry_${DateTime.now().millisecondsSinceEpoch}.m4a';await recorder.start(const RecordConfig(encoder:AudioEncoder.aacLc,numChannels:1,sampleRate:16000),path:path!);setState(()=>{recording=true,seconds=0,message=''});timer=Timer.periodic(const Duration(seconds:1),(_){if(seconds>=9){timer?.cancel();finish();}else{setState(()=>seconds++);}}); }
  Future<void> finish() async {final output=await recorder.stop();if(!mounted)return;setState(()=>{recording=false,seconds=10,path=output,message='تم التسجيل. لا يوجد نموذج تحليل متصل حاليًا؛ لا يمكن عرض احتياج الطفل بأمان قبل ربط خادم مدرّب.'});}
  @override void dispose(){timer?.cancel();recorder.dispose();super.dispose();}
  @override Widget build(BuildContext c)=>Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[const BabyMonitorLogo(size:170),const SizedBox(height:18),const Text('حلّل بكاء طفلك',style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)),const SizedBox(height:10),Text(recording?'جارٍ التسجيل: ${10-seconds} ثوانٍ':seconds==10?'تم التسجيل':'سجّل 10 ثوانٍ للحصول على تحليل إرشادي'),const SizedBox(height:20),FilledButton.icon(onPressed:recording?null:start,icon:const Icon(Icons.mic),label:Text(recording?'تسجيل...':'ابدأ التسجيل')),if(message.isNotEmpty)Padding(padding:const EdgeInsets.only(top:18),child:Text(message,textAlign:TextAlign.center)),const SizedBox(height:12),const Text('النتيجة احتمالية وليست تشخيصًا طبيًا.',textAlign:TextAlign.center)])));
}
class Reassure extends StatelessWidget{const Reassure({super.key});@override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(16),children:const[Text('اطمئن',style:TextStyle(fontSize:28,fontWeight:FontWeight.bold)),Text('سجّل المؤشرات اليومية وشاركها مع طبيب الأطفال عند الحاجة.'),_Field('ساعات البكاء اليومي'),_Field('عدد الرضعات'),_Field('الحفاضات المبللة'),_Field('ساعات النوم'),_Field('درجة الحرارة'),_Field('ملاحظات')]);}
class _Field extends StatelessWidget{final String label;const _Field(this.label);@override Widget build(BuildContext c)=>Card(child:TextField(decoration:InputDecoration(labelText:label,border:InputBorder.none,contentPadding:const EdgeInsets.all(16))));}
class Vaccines extends StatelessWidget{final AppStore store;const Vaccines({super.key,required this.store});@override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(16),children:[Text('التطعيمات • ${store.profile!.country}',style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),const Text('سيتم تحميل الجدول الرسمي حسب الدولة وتاريخ الميلاد بعد ربط الخادم.'),...['تطعيم حديثي الولادة — حسب البروتوكول المحلي','الجرعة التالية — يحددها تاريخ الميلاد','تذكير التطعيم — قابل للتحديث من الإدارة'].map((x)=>Card(child:ListTile(title:Text(x),leading:const Icon(Icons.vaccines),trailing:const Icon(Icons.notifications_none))))]);}
class Emergency extends StatelessWidget{const Emergency({super.key});@override Widget build(BuildContext c)=>ListView(padding:EdgeInsets.all(16),children:[Text('طوارئ',style:TextStyle(fontSize:28,fontWeight:FontWeight.bold,color:Colors.red)),Card(child:Padding(padding:EdgeInsets.all(16),child:Text('اذهب للطوارئ فورًا عند صعوبة التنفس، ازرقاق، تشنج، فقدان وعي، خمول شديد، نزيف، قيء أخضر أو متكرر، جفاف واضح، أو تدهور سريع.'))),Text('استخدم زر الموقع في النسخة المتصلة للعثور على مستشفى أطفال قريب.')]);}
