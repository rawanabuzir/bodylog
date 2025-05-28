# Smart Scale Connect (تطبيق ميزان ذكي)

[![Flutter](https://img.shields.io/badge/Made%20with-Flutter-blue.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Language-Dart-0175C2.svg)](https://dart.dev/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## الوصف العام للمشروع

يهدف هذا المشروع إلى تطوير تطبيق Flutter للاتصال بميزان ذكي متوافق مع بروتوكول OKOK (أو يعتمد على شرائح Chipsea) عبر تقنية البلوتوث منخفضة الطاقة (BLE). يوفر التطبيق واجهة سهلة الاستخدام لاكتشاف الميزان، الاتصال به، واستقبال بيانات الوزن في الوقت الفعلي مع تحليلها وعرضها بوضوح. يمثل هذا المشروع محاولة لفك قيود الاعتماد على التطبيقات الرسمية للموازين الذكية، مما يتيح للمستخدمين والمطورين دمج بيانات الوزن في أنظمتهم المخصصة.

## الميزات الرئيسية

* **اكتشاف الأجهزة:** مسح فعال لأجهزة البلوتوث لاكتشاف الموازين الذكية المتوافقة.
* **الاتصال والتوصيل:** إقامة اتصال BLE مستقر وموثوق مع الميزان.
* **استقبال البيانات:** استقبال بيانات الوزن الخام من الميزان فور حدوث القياس.
* **تحليل البروتوكول:** فك تشفير بيانات OKOK Protocol (نسخة `0xCA`) بما في ذلك:
    * التحقق من صحة الإطار باستخدام Checksum (XOR).
    * استخلاص قيمة الوزن الخام.
    * تحديد وحدة القياس (كجم، رطل، جين، ST:LB).
    * تحديد عدد المنازل العشرية للوزن.
* **واجهة مستخدم جذابة:** عرض الوزن الحالي وحالة الاتصال بتصميم عصري وبديهي.
* **إدارة حالة البلوتوث:** التحقق من حالة البلوتوث وطلب تفعيله إذا كان معطلاً.

## التحديات التي تم مواجهتها

* **بروتوكول الاتصال المخصص:** كان التحدي الأكبر هو فهم وهندسة بروتوكول OKOK BLE Protocol، والذي لا توجد له وثائق عامة وشاملة. تم الاعتماد على وثائق جزئية وتحليل سلوك الجهاز.
* **تأسيس الاتصال:** واجهة BLE للميزان قد تتطلب تسلسلاً معيناً أو "مصافحة" خاصة لإقامة الاتصال بنجاح، مما قد يسبب أخطاء مثل `ANDROID_SPECIFIC_ERROR` أو `Timed out`. هذا يتطلب التجريب الدقيق والفحص باستخدام أدوات مثل nRF Connect.

## المتطلبات المسبقة

لإنشاء وتشغيل هذا المشروع، ستحتاج إلى:

* [Flutter SDK](https://flutter.dev/docs/get-started/install) (الإصدار 3.x.x أو أحدث موصى به)
* جهاز Android (Android 6.0 Marshmallow أو أحدث) أو iOS (iOS 11.0 أو أحدث) يدعم BLE.
* ميزان ذكي متوافق مع بروتوكول OKOK / Chipsea (مثل "Chipsea-BLE").

## كيفية التشغيل

1.  **استنساخ المستودع:**
    ```bash
    git clone [https://github.com/YourUsername/smart_scale_connect.git](https://github.com/YourUsername/smart_scale_connect.git)
    cd smart_scale_connect
    ```

2.  **الحصول على التبعيات:**
    ```bash
    flutter pub get
    ```

3.  **تحديث MAC Address واسم الجهاز (إن وجد):**
    افتح الملف `lib/main.dart` (أو ملف الصفحة الرئيسية لتطبيقك) وقم بتحديث `targetMacAddress` و `targetDeviceName` بناءً على معلومات الميزان الخاص بك التي تحصل عليها من أداة مثل [nRF Connect](https://www.nordicsemi.com/Products/Software-and-Tools/nRF-Connect-for-Mobile).

    ```dart
    final String targetMacAddress = "XX:XX:XX:XX:XX:XX"; // استبدل بالـ MAC Address الفعلي لميزانك
    final String targetDeviceName = "Your_Scale_Name"; // استبدل بالاسم الفعلي لميزانك (مثل Chipsea-BLE)
    ```

4.  **تشغيل التطبيق:**
    ```bash
    flutter run
    ```
    (تأكد من أن جهازك المحمول متصل ومفعل به وضع تصحيح الأخطاء USB).

5.  **تفعيل البلوتوث والميزان:**
    تأكد من تفعيل البلوتوث على جهازك المحمول. بمجرد تشغيل التطبيق، قم بتنشيط الميزان الذكي (عادةً بالوقوف عليه لبضع ثوانٍ) لجعله يبدأ في الإعلان عن نفسه ويكون قابلاً للاكتشاف والاتصال.

## الأذونات (Android)

يتطلب التطبيق الأذونات التالية في ملف `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
