import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:baby_monitor/main.dart';
import 'package:baby_monitor/services/audio_activity.dart';
import 'package:baby_monitor/services/cry_recording_service.dart';
import 'package:baby_monitor/screens/doctor_mode.dart';
import 'package:baby_monitor/screens/emergency_page.dart';

Uint8List pcm(int amplitude, int samples) {
  final data = ByteData(samples * 2);
  for (var i = 0; i < samples; i++) {
    data.setInt16(i * 2, i.isEven ? amplitude : -amplitude, Endian.little);
  }
  return data.buffer.asUint8List();
}

class FakeCapture extends CryRecordingService {
  final bool audible;
  final bool denied;
  int starts = 0, stops = 0, cancels = 0;
  FakeCapture({this.audible = false, this.denied = false});
  @override
  Future<void> start() async {
    starts++;
    if (denied)
      throw const CryRecordingException('نحتاج إذن الميكروفون لبدء التسجيل.');
  }

  @override
  Future<bool> stopAndDelete() async {
    stops++;
    return audible;
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets(
    'Saved boy profile applies the light blue theme without another disclaimer',
    (tester) async {
      final profile = ChildProfile(
        baby: 'Baby',
        mother: 'Mother',
        father: 'Father',
        country: 'مصر',
        language: 'العربية',
        dob: DateTime(2026, 8, 24),
        gender: 'boy',
      );
      SharedPreferences.setMockInitialValues({'profile': profile.toJson()});
      await tester.pumpWidget(const BabyMonitorApp());
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Home));
      expect(
        Theme.of(context).scaffoldBackgroundColor,
        const Color(0xfff0f8ff),
      );
      expect(find.text('قرأت التنبيه وأوافق على المتابعة'), findsNothing);
      await tester.tap(find.byTooltip('نوع الطفل'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('بنت • وردي'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(Home))).scaffoldBackgroundColor,
        const Color(0xfffff4f8),
      );
      expect(
        (await SharedPreferences.getInstance()).getString('profile'),
        contains('girl'),
      );
    },
  );
  testWidgets('Silence ends capture with no result and allows a retry', (
    tester,
  ) async {
    final capture = FakeCapture();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CryPage(service: capture)),
      ),
    );
    await tester.tap(find.text('ابدأ التسجيل'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(capture.stops, 1);
    expect(find.textContaining('لم يُكتشف صوت كافٍ'), findsOneWidget);
    await tester.tap(find.text('ابدأ التسجيل'));
    await tester.pump();
    expect(capture.starts, 2);
    await tester.tap(find.text('إلغاء وحذف التسجيل'));
    await tester.pump();
    expect(capture.cancels, 1);
    await tester.pump(const Duration(seconds: 10));
    expect(capture.stops, 1);
  });
  testWidgets('Audible recording remains unavailable for interpretation', (
    tester,
  ) async {
    final capture = FakeCapture(audible: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CryPage(service: capture)),
      ),
    );
    await tester.tap(find.text('ابدأ التسجيل'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(find.textContaining('لا توجد نتيجة أو تشخيص'), findsOneWidget);
  });
  testWidgets(
    'Microphone denial reports an error without completing a capture',
    (tester) async {
      final capture = FakeCapture(denied: true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CryPage(service: capture)),
        ),
      );
      await tester.tap(find.text('ابدأ التسجيل'));
      await tester.pump();
      expect(find.text('نحتاج إذن الميكروفون لبدء التسجيل.'), findsOneWidget);
      expect(capture.stops, 0);
    },
  );
  test('Missing, silent, brief and low-level audio cannot pass the gate', () {
    expect(AudioActivity().detected, false);
    for (final value in [pcm(0, 160000), pcm(100, 160000), pcm(2000, 1000)]) {
      final activity = AudioActivity()..add(value);
      expect(activity.detected, false);
    }
  });
  test('Audible PCM and odd chunk boundaries are handled; stream errors reject audio', () {
    final data = pcm(1500, 16000);
    final activity = AudioActivity()
      ..add(Uint8List.sublistView(data, 0, 3))
      ..add(Uint8List.sublistView(data, 3));
    expect(activity.detected, true);
    activity.failed = true;
    expect(activity.detected, false);
  });
  test('Legacy profile survives and gender persists across restart', () async {
    SharedPreferences.setMockInitialValues({
      'profile': 'Baby|Mother|Father|مصر|العربية|2026-08-24',
    });
    final store = AppStore();
    await store.load();
    expect(store.profile!.baby, 'Baby');
    expect(store.disclaimerAccepted, true);
    await store.save(
      ChildProfile(
        baby: 'Baby',
        mother: 'Mother',
        father: 'Father',
        country: 'مصر',
        language: 'العربية',
        dob: DateTime(2026, 8, 24),
        gender: 'boy',
      ),
    );
    final loaded = AppStore();
    await loaded.load();
    expect(loaded.profile!.gender, 'boy');
    expect(loaded.disclaimerAccepted, true);
  });
  test('Map search encodes location and has no-location fallback', () {
    expect(
      hospitalMapUri(latitude: 30.1, longitude: 31.2).queryParameters['query'],
      contains('30.1,31.2'),
    );
    expect(
      hospitalMapUri().queryParameters['query'],
      'children hospitals near me',
    );
  });
  test('Doctor name accepts Arabic and rejects contact information', () {
    expect(validDoctorName('محمد محمود'), true);
    expect(validDoctorName('Mohamed 01012345678'), false);
    expect(validDoctorName('محمد ٠١٠١٢٣٤٥٦٧٨'), false);
    expect(validDoctorName('doctor@example.com'), false);
  });
  testWidgets('Previously accepted disclaimer does not recur in profile form', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'disclaimerAccepted': true});
    final store = AppStore();
    await store.load();
    await tester.pumpWidget(
      MaterialApp(
        home: ConsentAndProfile(store: store, onSaved: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('قرأت التنبيه وأوافق على المتابعة'), findsNothing);
    expect(find.text('نوع الطفل'), findsOneWidget);
  });
  testWidgets('Doctor profile validates, saves and remains isolated', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: DoctorMode()));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsNothing);
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, false);
    await tester.enterText(find.byType(TextFormField), 'محمد محمود');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('حفظ وفتح وضع الطبيب'));
    await tester.pumpAndSettle();
    expect(find.text('أخصائي • محمد محمود'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString('doctorName'),
      'محمد محمود',
    );
    expect(find.textContaining('الدفع غير مفعّل'), findsOneWidget);
  });
}
