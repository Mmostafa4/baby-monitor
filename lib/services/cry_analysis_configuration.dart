import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'cry_analysis_client.dart';

/// Build-time, public Firebase app configuration plus an HTTPS API address.
/// No model or service-account secret belongs in the mobile app.
class CryAnalysisConfiguration {
  static const String _endpointValue =
      String.fromEnvironment('BABY_MONITOR_API_ENDPOINT');
  static const String _firebaseApiKey =
      String.fromEnvironment('FIREBASE_API_KEY');
  static const String _firebaseAndroidAppId =
      String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const String _firebaseIosAppId =
      String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const String _firebaseWebAppId =
      String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const String _firebaseMessagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String _firebaseProjectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID');

  static bool _firebaseInitialized = false;
  static bool _firebaseInitializationFailed = false;

  static String get _firebaseAppId {
    if (kIsWeb) return _firebaseWebAppId;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return _firebaseIosAppId;
      case TargetPlatform.android:
        return _firebaseAndroidAppId;
      default:
        return '';
    }
  }

  static Uri? get endpoint {
    final value = Uri.tryParse(_endpointValue);
    if (value == null ||
        value.scheme != 'https' ||
        value.host.isEmpty ||
        value.userInfo.isNotEmpty) {
      return null;
    }
    return value;
  }

  static bool get isReady => endpoint != null && _firebaseInitialized;

  static Future<void> initialize() async {
    final values = [
      _firebaseApiKey,
      _firebaseAppId,
      _firebaseMessagingSenderId,
      _firebaseProjectId,
    ];
    if (values.any((value) => value.isEmpty)) return;

    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: _firebaseApiKey,
          appId: _firebaseAppId,
          messagingSenderId: _firebaseMessagingSenderId,
          projectId: _firebaseProjectId,
        ),
      );
      _firebaseInitialized = true;
    } catch (_) {
      _firebaseInitializationFailed = true;
    }
  }

  static String get unavailableMessage => _firebaseInitializationFailed
      ? 'تعذر إعداد تسجيل الدخول الآمن للتحليل التجريبي.'
      : 'التحليل التجريبي غير مفعّل. يلزم إعداد خادم HTTPS وتسجيل دخول آمن.';

  static Future<void> deleteAnonymousUser() async {
    if (!_firebaseInitialized) return;
    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      if (user?.isAnonymous == true) {
        await user!.delete().timeout(const Duration(seconds: 5));
      }
    } catch (_) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {
        // Local data deletion must not depend on a network connection.
      }
    }
  }

  static CryAnalysisClient? createClient() {
    final uri = endpoint;
    if (uri == null || !_firebaseInitialized) return null;
    return CryAnalysisClient(endpoint: uri, accessToken: _getAccessToken);
  }

  static Future<String?> _getAccessToken() async {
    if (!_firebaseInitialized || Firebase.apps.isEmpty) return null;

    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser ?? (await auth.signInAnonymously()).user;
      if (user == null) return null;
      return user.getIdToken();
    } on FirebaseAuthException catch (error) {
      if (error.code == 'operation-not-allowed') {
        throw const CryAnalysisException(
          'تسجيل الدخول المجهول غير مفعّل في خدمة التجربة.',
        );
      }
      throw const CryAnalysisException(
        'تعذر إنشاء جلسة دخول آمنة. لم يكتمل التحليل.',
      );
    } catch (_) {
      throw const CryAnalysisException(
        'تعذر إنشاء جلسة دخول آمنة. لم يكتمل التحليل.',
      );
    }
  }
}
