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


## Android private beta in Google Play

Use the manual workflow **Build Android Google Play private beta**. The Play track is
always `internal`; this workflow cannot publish to the public production track.

1. Enroll in Play Console and create the app using the final, owner-controlled
   `ANDROID_APPLICATION_ID`. Do not use the current `com.example.baby_monitor`
   preview ID for a store listing; keep the chosen ID permanently.
2. Create an Android upload keystore and add these GitHub Actions secrets:
   `ANDROID_UPLOAD_KEYSTORE_BASE64`, `ANDROID_UPLOAD_KEYSTORE_PASSWORD`,
   `ANDROID_UPLOAD_KEY_ALIAS`, and `ANDROID_UPLOAD_KEY_PASSWORD`. Keep the
   keystore and passwords private; do not commit them or send them in chat.
3. Add the variables `ANDROID_APPLICATION_ID`, `BABY_MONITOR_API_ENDPOINT`,
   `FIREBASE_API_KEY`, `FIREBASE_ANDROID_APP_ID`,
   `FIREBASE_MESSAGING_SENDER_ID`, and `FIREBASE_PROJECT_ID`. The endpoint
   must be HTTPS and end in `/v1/cry-analysis`.
4. Run the workflow once with `publish_to_internal` unchecked to build a signed
   AAB artifact. Use it to create/initialize the app and its first release in
   Play Console if the app has not been uploaded before.
5. For an automated internal-track upload, create a Google Play service account,
   grant it app release access in Play Console, save its JSON as the
   `PLAY_SERVICE_ACCOUNT_JSON` GitHub Actions secret, and rerun with
   `publish_to_internal` checked. This path checks that the model service is
   ready before uploading.

For new personal Play Console accounts, Google currently requires a closed test
with at least 12 opted-in testers for 14 continuous days before requesting
production access; that is separate from an internal beta. See Google's
[testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en).
