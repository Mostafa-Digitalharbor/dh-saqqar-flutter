# البرومبت الجاهز — انسخ اللي تحت الخط ده كله

مبني على تنفيذ فعلي كامل لتطبيق صقّار (2026-08-18). كل فخ مذكور جواه كلّف
دورة CI حقيقية، فمكتوب بنص رسالة الخطأ عشان الـ AI يعرفه قبل ما يقع فيه.

**قبل ما تلصقه:** لو عندك القيم دي جاهزة، حطها في آخر البرومبت في قسم
"معلومات جاهزة" — هيوفر عليك أسئلة.

---

اشتغل على المشروع ده وجهّزه لـ CI/CD كامل يبني ويرفع تلقائياً على Google Play
و TestFlight، ويربط Sentry.

**كلّمني بالعامية المصرية، والمصطلحات التقنية تفضل إنجليزي.**

## المرجع

الخط ده اتنفذ قبل كده بالكامل في مشروع تاني ونجح على المنصتين. المطلوب منك
تكرّره هنا. كل فخ مذكور تحت حصل فعلاً وكلّف دورة CI — اتأكد منه **قبل** أول
تشغيل مش بعده.

## المرحلة ١ — افحص المشروع الأول (متبنيش قبل كده)

استخرج القيم دي من الريبو نفسه ولا تفترض أي واحدة:

```bash
# الـ applicationId بتاع أندرويد
grep -n "applicationId" android/app/build.gradle.kts android/app/build.gradle 2>/dev/null

# الـ bundle ids بتاعت iOS (غالباً مختلفة عن أندرويد!) + الـ Team ID
grep -oE "PRODUCT_BUNDLE_IDENTIFIER = [^;]+;" ios/Runner.xcodeproj/project.pbxproj | sort -u
grep -oE "DEVELOPMENT_TEAM = [A-Z0-9]+" ios/Runner.xcodeproj/project.pbxproj | head -1

# deployment target
grep -oE "IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;" ios/Runner.xcodeproj/project.pbxproj | sort -u
grep -m1 "platform :ios" ios/Podfile

# كل الـ dart-defines اللي الكود بيقراها
grep -rn "fromEnvironment" lib/ --include=*.dart

# النسخة الحالية + هل فيه keystore
grep -m1 "^version:" pubspec.yaml
ls android/*.jks android/key.properties 2>/dev/null

# نسخة Flutter
flutter --version
```

**اطبعلي جدول بالنتائج** قبل ما تكتب أي حاجة.

## المرحلة ٢ — الفحوصات الحرجة (الاتنين دول كلّفوا دورة CI كاملة)

### أ) نسخة Flutter لازم تطابق الكود الـ native

```bash
grep -rn "FlutterImplicitEngineDelegate\|didInitializeImplicitFlutterEngine" ios/Runner/
grep -n "UIApplicationSceneManifest" ios/Runner/Info.plist
ls ios/Runner/SceneDelegate.swift 2>/dev/null
```

أي نتيجة = التطبيق على **UIScene embedding** ومحتاج **Flutter ≥ 3.38**.
لو ثبّتنا أقل، البناء بيفشل عند ترجمة Swift بـ
`Cannot find type 'FlutterImplicitEngineDelegate' in scope` — ورسالة مابتقولش
أي حاجة عن نسخة Flutter.

**على ويندوز ده مستحيل يظهر محلياً** لأن `flutter build ios` مابيشتغلش أصلاً.

### ب) `MinimumOSVersion`

```bash
grep -c "MinimumOSVersion" ios/Flutter/AppFrameworkInfo.plist
```

لو `0` → ضيفه بقيمة تساوي `IPHONEOS_DEPLOYMENT_TARGET`:

```xml
<key>MinimumOSVersion</key>
<string>15.0</string>
```

ولازم القيمة تبقى **15.0 أو أعلى** في التلات أماكن مع بعض:
`IPHONEOS_DEPLOYMENT_TARGET` في كل build configuration، و`platform :ios` في
الـ Podfile، والـ plist ده.

فشلين مختلفين، والاتنين بيحصلوا **بعد** ما النسخة تترفع بنجاح — يعني الـ CI
هيبقى أخضر في الحالتين:

* **ناقص** → رفض نهائي في التحقق:
  `MinimumOSVersion in 'Runner.app/Frameworks/App.framework' is ''`.
* **أقل من 15.0** → `ITMS-90068: MinimumOSVersion too low` — إيميل من آبل
  ومثلث أصفر جنب النسخة في TestFlight. **دلوقتي تحذير، ومن ربيع 2027 رفض.**

رفع الحد لـ 15.0 مش بيخسّرك أي جهاز: أي آيفون بيشغّل iOS 13 بيشغّل 15
(الـ 6s وأحدث).

وكمان كل pod شايل `MinimumOSVersion` بتاعه وآبل بتفحص **أقل** واحد في الحزمة،
فلازم تفرض الحد في `post_install` بتاع الـ Podfile كمان — بـ**رفع فقط**،
ماتنزّلش pod طالب نسخة أحدث.

## المرحلة ٣ — Sentry

لو مش مربوط:

1. ضيف `sentry_flutter` في `pubspec.yaml`
2. في `main()`: لُف التطبيق بـ `SentryFlutter.init` مع `appRunner`
3. الـ DSN من `--dart-define` **مش hardcoded**:
   ```dart
   options.dsn = const String.fromEnvironment('APP_SENTRY_DSN', defaultValue: '');
   ```
   (فاضي = Sentry بيعطّل نفسه — مفيد للتطوير المحلي)
4. `options.environment = kReleaseMode ? 'production' : 'development'`
5. `options.release` من `PackageInfo` عشان يتتبع pubspec لوحده
6. **متبعتش PII**: `sendDefaultPii = false`, `attachScreenshot = false`
7. فلتر `beforeSend` يرمي أخطاء الشبكة و4xx — دي ضوضاء بيئية مش باجات،
   وبتحرق الـ quota المجانية

## المرحلة ٤ — ملفات الـ CI/CD

اكتب `.github/workflows/ci.yml` و `.github/workflows/release.yml` و
`ios/Gemfile` و `ios/fastlane/Appfile` و `ios/fastlane/Fastfile`.

### التصميم المطلوب

**`ci.yml`** — على كل push للفرع: `flutter analyze` + `flutter test` + بناء
debug APK. **مابيرفعش أي حاجة لأي متجر.** ده مكان التجريب المجاني.

**`release.yml`** — بالـ **tag بس** (`on: push: tags: ['v*']`)، مش على كل
push. مراجعة المتاجر بتاخد ساعات لأيام، فخط بيرفع مع كل commit بيبني طابور
مايفضاش أبداً.

أربع jobs:
1. `verify` — analyze + tests
2. `version` — يستخرج `build_name` من الـ tag، و`build_number` من
   `OFFSET + github.run_number` (عشان يزيد لوحده ومستحيل يتكرر)، **و**
   يصدّر `has_android` / `has_ios` كـ outputs حسب وجود الـ secrets
3. `android` — AAB موقّع → Play **internal track** (مش production)
4. `ios` — على `macos-15` → IPA → TestFlight للمختبرين الداخليين بس

**مهم:** المنصة اللي مفاتيحها ناقصة لازم **تتخطى نفسها** (skip) مش تفشل. الـ
`secrets` context **مش متاح** في `jobs.<id>.if` — لازم تعديه عن طريق job
output زي فوق.

### الفخاخ — كل واحد فيهم حصل فعلاً

**١. ذاكرة Gradle.** الـ runner بتاع repo خاص = **2 vCPU / 7 GB**. لو
`android/gradle.properties` فيه `-Xmx8G` (عادي على جهاز مطوّر)، الـ JVM
بتتقتل وGradle بيخرج بـ**143** وGitHub بيكتب `The operation was canceled` —
شكلها كأن حد ضغط إلغاء. اكتب override في `GRADLE_USER_HOME` (بيغلب ملف
المشروع) بـ`-Xmx3G` و`org.gradle.daemon=false` و`workers.max=2`، وسيب ملف
المشروع زي ما هو عشان البناء المحلي مايبطّأش.

**٢. Jetifier.** اتأكد:
```bash
find ~/.gradle/caches/modules-2/files-2.1 -maxdepth 1 \
     \( -iname "com.android.support*" -o -iname "android.arch*" \) | wc -l
```
لو `0` → شيل `android.enableJetifier=true`. بيعيد كتابة مئات الأرشيفات عشان
يغيّر ولا حاجة، وبيمسك كل واحد في الذاكرة. على cap 3 جيجا الـ **debug** build
بيقع بـ`JetifyTransform … Java heap space` والـ release بيعدّي — لأن الـ debug
بيضم jars بتاعت x86/x86_64 كمان.

**٣. القرص.** البناء محتاج أكتر من الـ ~14 GB المتاحة بعد ما Gradle يفك NDK و
CMake. الامتلاء بيظهر كـ`Could not add entry '…/transforms/…' to cache
file-access.bin` — شكلها كاش باظ. ضيف خطوة تمسح
`/usr/share/dotnet /opt/ghc /usr/local/.ghcup /opt/hostedtoolcache/CodeQL`
وتطبع `df -h` قبل وبعد.

**٤. `google-services.json`.** مش في git بس الـ plugin بيفشل من غيره في **كل**
بناء أندرويد حتى الـ debug. استرجعه من secret في **الـ job الاتنين**.

**٥. نسخة Xcode.** `Runner.xcodeproj` المكتوب بـXcode 16+ فيه
`PBXFileSystemSynchronizedRootGroup`، وXcode 15 مابيقراهوش وبينهار
(`xcodebuild -list` بيعمل DVTAssertions failure وsignal 6). استخدم `macos-15`
وضيف خطوة تختار **الأحدث بـ`sort -V`** — **مش** بـglob زي `Xcode_1[6-9]*`
لأن آبل نقلت من 16.x لـ26.x فالنمط ده بيسيب كل النسخ الحالية.

**٦. `xcodebuild -version` متعديهوش على `head`.** تحت Xcode 26 بينهار على EPIPE
(`Broken pipe`, exit 134) و`pipefail` بيفشّل الخطوة — بعد ما يكون طبع النسخة
الصح بسطر واحد، فالفشل شكله كأن الاختيار باظ. خد المخرجات كاملة في متغير
وحلّلها في الذاكرة.

**٧. CocoaPods لازم تبقى في نفس الـ Ruby بتاعة fastlane.** `ruby/setup-ruby`
بيحط Ruby غير اللي الـ image سطّب عليها CocoaPods، و`flutter build ios` بيستدعي
`pod install` **بنفسه** مش عن طريق bundler — فبيحذّر بس
(`CocoaPods is installed but broken`) وبعدين يفشل. الحل: `gem "cocoapods"` في
`ios/Gemfile`. وضيف خطوة `which pod && pod --version` قبل البناء عشان تفشل في
ثواني بدل ٢٠ دقيقة.

**٨. متستخدمش `bundler-cache: true`** — بيعتمد على `Gemfile.lock` مش متسجّل،
وتوليده على ويندوز بيثبّت platforms غلط. `bundle install` عادي أنضف.

**٩. `--dart-define=K=` فاضي ≠ إنك ماتعديهوش.** `String.fromEnvironment` بترجع
الـ`defaultValue` **بس** لما المفتاح **غايب**؛ النص الفاضي قيمة وبتغلب. يعني
تمرير secret ناقص **بيمسح** قيمة افتراضية شغّالة في الكود. ضيف الـ flag **بس**
لما الـ secret يكون مش فاضي.

**١٠. توقيع iOS.** استخدم `-allowProvisioningUpdates` مع مفتاح App Store
Connect + استيراد شهادة التوزيع من `.p12`. **مفتاح الـ API لازم يكون `Admin`**
— `App Manager` بيرفع بيلد بس **مش** بيوقّع سحابياً، والفشل بيقول
`exportArchive Cloud signing permission error / No profiles were found` وشكله
مشكلة provisioning مش صلاحيات.

## المرحلة ٥ — بعد ما تخلّص الكود

اطبعلي **قايمة مرقّمة بالخطوات اللي عليّا أنا**، وسطر فاضي بين كل رقم والتاني،
وبالترتيب اللي هنفّذه فعلاً. اتبع القواعد دي:

### قواعد إجبارية للمخرجات

1. **كل خطوة على موقع خارجي لازم يكون معاها لينك مباشر جاهز للضغط**، بالـ IDs
   بتاعتي متحطوطة جواه مش placeholders. اسألني عن أي ID محتاجه (رقم حساب
   Play، الـ app id، الـ Team ID) بدل ما تكتب `<YOUR_ID>`.

2. لكل لينك، قولّي **اسم الزرار بالظبط** اللي هدوسه و**اسم الحقل** اللي
   هملاه — مش "روح للإعدادات".

3. **اطبعلي جدول بالـ secrets** فيه: الاسم بالظبط، مصدر القيمة، وأمر يطبعها لو
   موجودة على جهازي.

4. أي أمر terminal اكتبه **جاهز للنسخ بمساري الفعلي**، مش نسبي.

5. **ماتعملش commit ولا push ولا tag.** اديني الأوامر وأنا أنفّذها. الـ tag
   بيرفع بيلد حقيقي على حساب متجر حقيقي — ده قراري.

6. لو حاجة محتاجة **ماك** أو صلاحية **مش متأكد إني معايا**، قولّي صراحة
   واقترح البديل. *(ملحوظة: تصدير شهادة التوزيع **مش** محتاج ماك — OpenSSL
   على ويندوز بيعمل نفس الـ`.p12`. في Git Bash استخدم `MSYS_NO_PATHCONV=1`
   مع `-subj` و`-legacy` مع `pkcs12 -export`.)*

7. **رتّب الخطوات بحيث كل اللي مابيرفعش حاجة يتعمل الأول.** آخر خطوة بس هي
   اللي تلمس متجر.

8. حذّرني من أي حاجة **مالهاش رجعة** قبلها بسطر واضح.

## معلومات جاهزة (املاها قبل ما تلصق)

- حساب Google Play developer id: `7574373484861523453`
- Apple Team ID: `P95FNYY2S2`
- عندي بالفعل من مشروع تاني وهعيد استخدامها:
  شهادة توزيع آبل (`.p12` + باسورد)، مفتاح App Store Connect (Admin)،
  حساب خدمة Play. **متطلبش مني أعملهم من جديد** — حساب آبل مسموح له
  بـ٣ شهادات توزيع بس.
- جهازي **ويندوز**، والـ shell المتاح Git Bash و PowerShell.

ابدأ بالمرحلة ١ واطبعلي جدول الفحص قبل ما تكتب أي كود.
