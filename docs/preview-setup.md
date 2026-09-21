# تجهيز نسخة التجربة الخاصة

تعمل الواجهة والتسجيل محليًا بدون إعداد خارجي. يبقى زر التحليل معطّلًا إلى أن
يتصل التطبيق بخدمة HTTPS ومشروع Firebase. يستخدم المسار الحالي نموذجًا تجريبيًا
حقيقيًا؛ لكنه لا يصنّف طلب الحنان أو الضيق، ولا يشخّص المغص أو المرض.

## الخادم وFirebase

1. شغّل حاوية `backend/` على استضافة تملكها، خلف HTTPS، ومن دون مجلد تخزين دائم
   للتسجيلات. وفّر `FIREBASE_PROJECT_ID` ومفتاح Firebase Admin عبر مدير الأسرار
   الخاص بالاستضافة. لا ترفع مفتاح الخدمة إلى GitHub أو ترسله في المحادثة.
2. في Firebase، فعّل تسجيل الدخول المجهول وسجّل تطبيقي Android وiOS بمعرّفاتهما
   النهائية. معرّف Android الحالي في APK التجريبي هو `com.example.baby_monitor`؛
   ويتحدد معرّف iOS بواسطة `IOS_BUNDLE_ID`. افحص إعداد الاحتفاظ بالسجلات لدى مزود
   الاستضافة قبل تجربة أي صوت.
3. أضف القيم العامة التالية في مستودع GitHub من
   **Settings → Secrets and variables → Actions → Variables**:

   | المتغير | القيمة |
   | --- | --- |
   | `BABY_MONITOR_API_ENDPOINT` | عنوان HTTPS الكامل وينتهي بـ `/v1/cry-analysis` |
   | `FIREBASE_API_KEY` | مفتاح تطبيق Firebase العام |
   | `FIREBASE_ANDROID_APP_ID` | معرّف تطبيق Android في Firebase |
   | `FIREBASE_IOS_APP_ID` | معرّف تطبيق iOS في Firebase |
   | `FIREBASE_MESSAGING_SENDER_ID` | معرّف المرسل في Firebase |
   | `FIREBASE_PROJECT_ID` | معرّف مشروع Firebase |

## تثبيت النسخة على iPhone عبر TestFlight

يحتاج التوزيع إلى حساب Apple Developer، ومعرّف حزمة وتطبيق مسجّلين في App Store
Connect، وشهادة توزيع وملف provisioning من نوع App Store، ومفتاح App Store
Connect بصلاحية App Manager. يجب أن تطابق قيمة `IOS_PROFILE_NAME` اسم ملف
App Store provisioning في حساب Apple حرفيًا. نزّلي ملف المفتاح الخاص مرة واحدة
واحتفظي به محليًا لإضافته إلى GitHub Secrets؛ لا ترسليه في المحادثة.
في **Variables** أضف `IOS_BUNDLE_ID` و`IOS_TEAM_ID` و`IOS_PROFILE_NAME` و
`APPSTORE_ISSUER_ID` و`APPSTORE_API_KEY_ID`. وفي **Secrets** أضف
`APPSTORE_API_PRIVATE_KEY` و`APPSTORE_CERTIFICATES_FILE_BASE64` و
`APPSTORE_CERTIFICATES_PASSWORD`.

بعد إعدادها وتشغيل الخادم بنجاح، شغّل يدويًا سير العمل **Build iOS TestFlight beta** من تبويب
**Actions**. يتحقق السير من جاهزية النموذج، ثم يبني ملف IPA ويحفظه كأثر للتنزيل
ويرفعه إلى TestFlight. لا يشغّل
هذا السير تلقائيًا عند كل تعديل. ملف محاكي iOS منفصل للاختبار على محاكي Mac فقط،
ولا يثبت على iPhone.

يمرّر بناء Android وبناء محاكي iOS إعداد Firebase وعنوان الخادم إلى التطبيق عند
توفرها. من دونها يظل التسجيل والاستماع والحذف محليًا، ويظهر أن التحليل غير مفعّل.
