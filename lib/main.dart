import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const BabyMonitorApp());

class BabyMonitorApp extends StatefulWidget {
  const BabyMonitorApp({super.key});
  @override State<BabyMonitorApp> createState() => _BabyMonitorAppState();
}
class _BabyMonitorAppState extends State<BabyMonitorApp> {
  final store = AppStore();
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'Baby Monitor',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.pink, fontFamily: 'Arial'),
    home: FutureBuilder(future: store.load(), builder: (_, s) => s.connectionState != ConnectionState.done
      ? const Scaffold(body: Center(child: CircularProgressIndicator()))
      : store.profile == null ? ConsentAndProfile(store: store) : Home(store: store)),
  );
}

class AppStore {
  ChildProfile? profile; bool consent = false;
  // Server-controlled in production. The client default is only a fallback.
  int launchPriceEgp = 100;
  Future<void> load() async { final p = await SharedPreferences.getInstance(); final raw = p.getString('profile'); if (raw != null) profile = ChildProfile.fromJson(jsonDecode(raw)); }
  Future<void> save(ChildProfile p) async { final s = await SharedPreferences.getInstance(); await s.setString('profile', jsonEncode(p.toJson())); profile = p; }
}
class ChildProfile { final String baby, mother, father, country, language; final DateTime dob;
  ChildProfile({required this.baby, required this.mother, required this.father, required this.country, required this.language, required this.dob});
  Map<String,dynamic> toJson()=>{'baby':baby,'mother':mother,'father':father,'country':country,'language':language,'dob':dob.toIso8601String()};
  factory ChildProfile.fromJson(Map<String,dynamic> j)=>ChildProfile(baby:j['baby'],mother:j['mother'],father:j['father'],country:j['country'],language:j['language'],dob:DateTime.parse(j['dob']));
}
const countries = ['مصر','السعودية','الإمارات','الولايات المتحدة','المملكة المتحدة','فرنسا','ألمانيا','الهند','الصين','تركيا'];
const languages = ['العربية','English','Français','Deutsch','हिन्दी','中文','Türkçe'];

class ConsentAndProfile extends StatefulWidget { final AppStore store; const ConsentAndProfile({super.key, required this.store}); @override State<ConsentAndProfile> createState()=>_ConsentState(); }
class _ConsentState extends State<ConsentAndProfile> { final form=GlobalKey<FormState>(); final baby=TextEditingController(), mom=TextEditingController(), dad=TextEditingController(); String country='مصر', language='العربية'; DateTime dob=DateTime.now(); bool accepted=false;
  @override Widget build(BuildContext c)=>Directionality(textDirection: language=='العربية'?TextDirection.rtl:TextDirection.ltr, child:Scaffold(body:SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Form(key:form,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[const Text('Baby Monitor',style:TextStyle(fontSize:32,fontWeight:FontWeight.bold)),const SizedBox(height:8),const Text('مساعد إرشادي لمتابعة الطفل، وليس بديلًا عن الطبيب.'),const SizedBox(height:24), DropdownButtonFormField(value:country,items:countries.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>setState(()=>country=x!),decoration:const InputDecoration(labelText:'الدولة')), DropdownButtonFormField(value:language,items:languages.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>setState(()=>language=x!),decoration:const InputDecoration(labelText:'اللغة')), ...[('اسم الطفل',baby),('اسم الأم',mom),('اسم الأب',dad)].map((e)=>TextFormField(controller:e.$2,validator:(v)=>v==null||v.trim().isEmpty?'مطلوب':null,decoration:InputDecoration(labelText:e.$1))), ListTile(title:const Text('تاريخ ميلاد الطفل'),subtitle:Text(DateFormat('yyyy-MM-dd').format(dob)),trailing:const Icon(Icons.calendar_month),onTap:()async{final x=await showDatePicker(context:c,initialDate:dob,firstDate:DateTime(2015),lastDate:DateTime.now());if(x!=null)setState(()=>dob=x);}), Card(color:Colors.amber.shade50,child:const Padding(padding:EdgeInsets.all(12),child:Text('تنبيه: المعلومات إرشادية وليست استشارة أو تشخيصًا أو علاجًا طبيًا. في الطوارئ اتصل بخدمات الطوارئ أو اذهب للمستشفى.'))), CheckboxListTile(value:accepted,onChanged:(x)=>setState(()=>accepted=x!),title:const Text('قرأت التنبيه وأوافق على المتابعة'),controlAffinity:ListTileControlAffinity.leading), ElevatedButton(onPressed:accepted?()async{if(form.currentState!.validate()){await widget.store.save(ChildProfile(baby:baby.text.trim(),mother:mom.text.trim(),father:dad.text.trim(),country:country,language:language,dob:dob));setState((){});}}:null,child:const Text('ابدأ'))])))))); }
}

class Home extends StatefulWidget { final AppStore store; const Home({super.key,required this.store}); @override State<Home> createState()=>_HomeState(); }
class _HomeState extends State<Home>{int tab=0; @override Widget build(BuildContext c){final pages=[CryPage(store:widget.store), Reassure(), Vaccines(store:widget.store), Emergency()]; return Directionality(textDirection:widget.store.profile!.language=='العربية'?TextDirection.rtl:TextDirection.ltr,child:Scaffold(appBar:AppBar(title:Text('Baby Monitor • ${widget.store.profile!.baby}')),body:pages[tab],bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(x)=>setState(()=>tab=x),destinations:const[NavigationDestination(icon:Icon(Icons.mic),label:'بكاء'),NavigationDestination(icon:Icon(Icons.favorite),label:'اطمئن'),NavigationDestination(icon:Icon(Icons.vaccines),label:'تطعيمات'),NavigationDestination(icon:Icon(Icons.warning),label:'طوارئ')])));}}
class CryPage extends StatefulWidget{final AppStore store;const CryPage({super.key,required this.store});@override State<CryPage> createState()=>_CryState();}
class _CryState extends State<CryPage>{bool recording=false;int seconds=0;void start(){setState(()=>recording=true);Future.doWhile(()async{await Future.delayed(const Duration(seconds:1));if(!mounted||!recording)return false;setState(()=>seconds++);if(seconds>=10){setState(()=>recording=false);return false;}return true;});} @override Widget build(BuildContext c)=>Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.child_friendly,size:90,color:Colors.pink),const Text('حلّل بكاء طفلك',style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)),const SizedBox(height:12),Text(recording?'جارٍ التسجيل: ${10-seconds} ثوانٍ':'سجّل 10 ثوانٍ للحصول على احتمال إرشادي'),const SizedBox(height:20),ElevatedButton.icon(onPressed:recording?null:(){seconds=0;start();},icon:const Icon(Icons.mic),label:Text(recording?'تسجيل...':'ابدأ التسجيل')),if(!recording&&seconds>=10)const Padding(padding:EdgeInsets.all(16),child:Text('التحليل الصوتي يحتاج نموذجًا مدرّبًا وواجهة خادم آمنة. هذه نسخة الواجهة الأولية ولا تعرض تشخيصًا.'))])));}}
class Reassure extends StatelessWidget{const Reassure({super.key});@override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(16),children:const[Text('اطمئن',style:TextStyle(fontSize:28,fontWeight:FontWeight.bold)),Text('سجّل المؤشرات اليومية لعرضها على طبيب الأطفال.'),_Field('ساعات البكاء اليومي'),_Field('عدد الرضعات'),_Field('الحفاضات المبللة'),_Field('ساعات النوم'),_Field('درجة الحرارة'),_Field('ملاحظات')]);}
class _Field extends StatelessWidget{final String t;const _Field(this.t);@override Widget build(BuildContext c)=>Card(child:TextField(decoration:InputDecoration(labelText:t,border:InputBorder.none,contentPadding:const EdgeInsets.all(16))));}
class Vaccines extends StatelessWidget{final AppStore store;const Vaccines({super.key,required this.store});@override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(16),children:[Text('التطعيمات • ${store.profile!.country}',style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),const Text('الجدول النهائي يجب أن يُراجع من الجهة الصحية الرسمية في الدولة المختارة.'),...['جرعة حديثي الولادة — حسب البروتوكول المحلي','الجرعة التالية — يحددها تاريخ الميلاد والجهة الرسمية','تذكير التطعيم — قابل للتعديل من الخادم'].map((x)=>Card(child:ListTile(title:Text(x),leading:const Icon(Icons.vaccines),trailing:const Icon(Icons.notifications_none))))]);}
class Emergency extends StatelessWidget{const Emergency({super.key});Future<void> locate()async{final ok=await Geolocator.requestPermission();if(ok==LocationPermission.denied||ok==LocationPermission.deniedForever)return;final p=await Geolocator.getCurrentPosition();final u=Uri.parse('https://www.google.com/maps/search/?api=1&query=${p.latitude},${p.longitude}+children%27s+hospital');launchUrl(u,mode:LaunchMode.externalApplication);} @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(16),children:[const Text('طوارئ',style:TextStyle(fontSize:28,fontWeight:FontWeight.bold,color:Colors.red)),const Card(child:Padding(padding:EdgeInsets.all(16),child:Text('اذهب للطوارئ فورًا عند صعوبة التنفس، ازرقاق، تشنج، فقدان وعي، خمول شديد، نزيف، قيء أخضر/متكرر، جفاف واضح، أو تدهور سريع.'))),ElevatedButton.icon(onPressed:locate,icon:const Icon(Icons.location_on),label:const Text('اعثر على أقرب مستشفى أطفال')),const Text('الموقع اختياري ويُستخدم لفتح نتائج الخرائط القريبة فقط.')]);}
