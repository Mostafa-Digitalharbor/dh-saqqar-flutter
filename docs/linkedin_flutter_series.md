# سلسلة بوستات Flutter المتقدمة — LinkedIn (أسبوعين)

> ٦ بوستات تقنية متقدمة + ٦ برومبتات صور لـ Gemini.
> جدول النشر المقترح: ٣ بوستات في الأسبوع (السبت / الإثنين / الأربعاء مثلاً).

| الأسبوع | اليوم | الموضوع |
|---------|-------|---------|
| ١ | السبت | RepaintBoundary & Rendering Pipeline (البوست الافتتاحي) |
| ١ | الإثنين | Impeller vs Skia |
| ١ | الأربعاء | Isolates للعمليات الثقيلة |
| ٢ | السبت | `const` و قوة الـ compile-time |
| ٢ | الإثنين | Slivers & CustomScrollView |
| ٢ | الأربعاء | DevTools Performance — تشخيص الـ Jank بالأرقام |

---

## البوست ١ — Impeller vs Skia

> **مشكلة الـ "Shader Jank" اللي عذّبت مطوري Flutter لسنين… اتحلت أخيراً 🚀**
>
> هل لاحظت إن أول مرة بتفتح فيها شاشة فيها animation، بيحصل lag بسيط؟ وبعد كده بتشتغل بسلاسة؟ ده مش صدفة — ده اسمه **Shader Compilation Jank**.
>
> **السبب (مع Skia):**
> Skia كان بيـ compile الـ shaders وقت التشغيل (runtime)، أول مرة الـ animation تظهر. الـ compilation ده بياخد وقت → frame بيتأخر → المستخدم بيشوف "تهنيج".
>
> **الحل (Impeller):**
> Impeller — المحرك الجديد (الافتراضي دلوقتي على iOS و Android) — بيعمل **precompile** للـ shaders وقت الـ build، مش وقت التشغيل. النتيجة: مفيش jank في أول frame.
>
> **الفرق عملياً:**
> - Skia → الـ shaders تتبني runtime (وقت ما تحتاجها)
> - Impeller → الـ shaders جاهزة قبل ما التطبيق يشتغل أصلاً
>
> ➕ Impeller كمان بيستغل الـ Metal (iOS) و Vulkan (Android) بشكل مباشر = استغلال أفضل للـ GPU.
>
> **إزاي تتأكد إنك شغال عليه؟**
> من Flutter 3.x هو الافتراضي، بس تقدر تتحكم فيه:
> ```
> flutter run --enable-impeller
> # أو تعطيله للمقارنة:
> flutter run --no-enable-impeller
> ```
>
> 💡 لو عندك custom shaders قديمة، اختبرها كويس بعد التحويل — في فروقات بسيطة في الـ rendering.
>
> ━━━━━━━━━━━━━━━
> جربت الفرق بين Impeller و Skia في مشروعك؟ شاركنا تجربتك 👇
>
> #Flutter #Impeller #Performance #MobileDev #Dart

**برومبت الصورة:**
```
Create a clean, modern technical infographic for LinkedIn comparing two
rendering engines: "Skia" vs "Impeller".

Style: Flat design, dark navy background (#0D1B2A) with Flutter blue
(#02569B) and cyan (#13B9FD) accents. Professional, minimalist, high contrast.

Split the image vertically into two halves:
- LEFT half labeled "Skia (Runtime Compilation)": show a smartphone with a
  loading/stutter icon and a small lag spike graph (jagged red line). Add a
  tiny clock icon meaning "compiles while running".
- RIGHT half labeled "Impeller (Precompiled)": show a smartphone running
  smoothly with a flat green performance line. Add a checkmark and a small
  GPU chip icon.

Title at top: "Goodbye Shader Jank". Use clean sans-serif white text.
Keep ALL text short and correctly spelled: Skia, Impeller, Runtime,
Precompiled, GPU. Aspect ratio 1200x627 (LinkedIn landscape). No watermarks.
```

---

## البوست ٢ — Isolates للعمليات الثقيلة

> **الـ UI بتاعك بيتجمّد لما تعمل عملية تقيلة؟ السبب إن Dart بيشتغل على Thread واحد 🧵**
>
> Dart بطبيعته **single-threaded**. كل حاجة بتحصل على الـ main isolate — بناء الـ UI، الـ animations، والـ logic. فلو عملت عملية تقيلة (parsing لـ JSON ضخم، تشفير، معالجة صورة)، الـ UI بيقف لحد ما تخلص → **frozen frames**.
>
> **الحل: Isolates**
> الـ Isolate ده زي "thread" بذاكرة منفصلة تماماً. بيشتغل بالتوازي من غير ما يلمس الـ main thread.
>
> **أسهل طريقة — `compute()`:**
> ```dart
> // ❌ بيجمّد الـ UI
> final result = heavyParsing(bigJson);
>
> // ✅ بيشتغل في isolate منفصل
> final result = await compute(heavyParsing, bigJson);
> ```
>
> **للحالات المتقدمة — `Isolate.run()` (Dart 2.19+):**
> ```dart
> final result = await Isolate.run(() => heavyParsing(bigJson));
> ```
>
> **نقطة مهمة جداً ⚠️:**
> الـ Isolates **مبيشاركوش الذاكرة**. التواصل بينهم بيتم عن طريق *رسائل* (messages) بتتنسخ. يعني متبعتش object ضخم جيئة ورايحة كتير — التكلفة هتاكل الفايدة.
>
> **امتى تستخدمها؟**
> ✅ JSON parsing لملفات كبيرة
> ✅ تشفير / ضغط بيانات
> ✅ معالجة صور أو فيديو
> ❌ عمليات بسيطة وسريعة (الـ overhead بتاع إنشاء isolate أغلى من العملية نفسها)
>
> ━━━━━━━━━━━━━━━
> إيه أتقل عملية اضطريت تنقلها لـ isolate؟ 👇
>
> #Flutter #Dart #Isolates #Concurrency #Performance

**برومبت الصورة:**
```
Create a clean, modern technical infographic for LinkedIn about Dart
Isolates and concurrency.

Style: Flat design, dark navy background (#0D1B2A) with Flutter blue
(#02569B) and cyan (#13B9FD) accents. Minimalist, professional.

Concept: Show two separate vertical "lanes" (threads) side by side:
- LEFT lane labeled "Main Isolate (UI)": a smooth flowing arrow with small
  UI widget icons (buttons, list) flowing without interruption.
- RIGHT lane labeled "Worker Isolate": a gear/cog icon doing heavy work
  (a heavy weight or large data block icon).
Between them, draw a dashed arrow with an envelope/message icon labeled
"messages (copied, not shared)".

Title at top: "Keep Your UI Smooth". White clean sans-serif text.
Keep labels short and correctly spelled: Main Isolate, Worker Isolate,
messages, UI. Aspect ratio 1200x627. No watermarks, no gibberish text.
```

---

## البوست ٣ — قوة `const` في Flutter

> **كلمة واحدة (`const`) ممكن توفر آلاف الـ rebuilds في تطبيقك. معظم المطورين بيتجاهلوها 🎯**
>
> لما الـ widget بيعمل rebuild، Flutter بيعيد بناء كل الـ children بتوعه… *إلا* الـ widgets اللي معرّفة `const`.
>
> **ليه؟**
> الـ `const` widget بيتبني **مرة واحدة** وقت الـ compile، وبيتخزن في الذاكرة (canonicalized). فلما الـ parent يعمل rebuild، Flutter بيقول: "ده const، نفس الـ instance، مش محتاج أعيد بناءه" → بيتخطاه تماماً.
>
> ```dart
> // ❌ بيتعاد بناءه مع كل rebuild للـ parent
> Padding(
>   padding: EdgeInsets.all(16),
>   child: Text('Hello'),
> )
>
> // ✅ بيتبني مرة واحدة ويتخطى في الـ rebuilds
> const Padding(
>   padding: EdgeInsets.all(16),
>   child: Text('Hello'),
> )
> ```
>
> **الأثر الحقيقي:**
> في شاشة فيها `ListView` بآلاف العناصر، كل rebuild بيتخطى الأجزاء الثابتة بدل ما يعيد بناءها = توفير ضخم في الـ CPU.
>
> **خلّي الـ linter يساعدك:**
> فعّل القاعدة دي في `analysis_options.yaml`:
> ```yaml
> linter:
>   rules:
>     - prefer_const_constructors
>     - prefer_const_literals_to_create_immutables
> ```
> هيقترحلك تلقائياً كل مكان ينفع تحط فيه `const`.
>
> 💡 القاعدة الذهبية: أي widget مالهوش بيانات بتتغير → خلّيه `const`.
>
> ━━━━━━━━━━━━━━━
> راجع آخر شاشة كتبتها — كام `const` ناسيها؟ 👇
>
> #Flutter #Dart #CleanCode #Performance #FlutterDev

**برومبت الصورة:**
```
Create a clean, modern technical infographic for LinkedIn about the power of
the "const" keyword in Flutter.

Style: Flat design, dark navy background (#0D1B2A) with Flutter blue
(#02569B) and cyan (#13B9FD) accents. Minimalist and professional.

Concept: Show a widget tree (connected nodes). On the LEFT version labeled
"Without const", ALL nodes glow orange/red meaning "rebuilt every time". On
the RIGHT version labeled "With const", most nodes are grey/locked (with a
small lock icon) meaning "skipped / cached", and only one node glows.

Add a large stylized "const" keyword badge in the center as the hero element.
Title at top: "One Keyword. Thousands of Saved Rebuilds." White clean
sans-serif text. Keep all text short and correctly spelled: const, Without
const, With const, skipped. Aspect ratio 1200x627. No watermarks.
```

---

## البوست ٤ — Slivers & CustomScrollView

> **لو لسه بتستخدم `ListView` + `Column` عشان تعمل scroll معقد… محتاج تعرف الـ Slivers 📜**
>
> الـ `ListView` و `GridView` و `AppBar` كلهم في الحقيقة عبارة عن **Slivers** متغلفة. الـ Sliver هو الجزء اللي بيتحكم في سلوك العنصر جوه منطقة الـ scroll.
>
> **المشكلة اللي بتحلها:**
> عايز AppBar يصغّر وانت بتعمل scroll؟ عايز header يفضل ثابت؟ عايز grid وبعده list في نفس الـ scroll view بكفاءة؟ الـ widgets العادية بتبقى صعبة ومكلفة. الـ Slivers بتحل ده بأناقة.
>
> ```dart
> CustomScrollView(
>   slivers: [
>     // AppBar بيصغّر مع الـ scroll
>     const SliverAppBar(
>       expandedHeight: 200,
>       floating: false,
>       pinned: true,
>       flexibleSpace: FlexibleSpaceBar(title: Text('Slivers')),
>     ),
>     // قايمة lazy — بتبني العناصر اللي ظاهرة بس
>     SliverList(
>       delegate: SliverChildBuilderDelegate(
>         (context, index) => ListTile(title: Text('Item $index')),
>         childCount: 1000,
>       ),
>     ),
>   ],
> )
> ```
>
> **ليه ده أفضل للـ performance؟**
> الـ `SliverChildBuilderDelegate` بيعمل **lazy building** — بيبني العناصر الظاهرة على الشاشة بس، زي `ListView.builder` بالظبط، بس مع مرونة كاملة في دمج أنواع محتوى مختلفة في scroll view واحد.
>
> 💡 لو عندك أكتر من scrollable في نفس الشاشة → ادمجهم في `CustomScrollView` واحد بدل ما تعشّش (nest) عدة scroll views (اللي بيعمل مشاكل performance و UX).
>
> ━━━━━━━━━━━━━━━
> أكتر sliver بتحبه؟ أنا مش بستغني عن الـ SliverAppBar 👇
>
> #Flutter #Slivers #UI #Performance #MobileDev

**برومبت الصورة:**
```
Create a clean, modern technical infographic for LinkedIn about Flutter
Slivers and CustomScrollView.

Style: Flat design, dark navy background (#0D1B2A) with Flutter blue
(#02569B) and cyan (#13B9FD) accents. Minimalist, professional.

Concept: Show a single smartphone frame in the center. Inside it, illustrate
a scrollable screen composed of stacked "sliver" blocks, each clearly
labeled as a layer:
1. Top block: "SliverAppBar" (a collapsing header bar, shown with a small
   collapse arrow).
2. Middle block: "SliverList" (rows of list items).
3. Bottom block: "SliverGrid" (a grid of squares).
Show a vertical scroll arrow on the right side indicating they all scroll
together as one.

Title at top: "One Scroll View. Many Slivers." White clean sans-serif text.
Keep labels short and correctly spelled: SliverAppBar, SliverList,
SliverGrid. Aspect ratio 1200x627. No watermarks, no gibberish.
```

---

## البوست ٥ — DevTools Performance Tab

> **بتحس إن في "jank" بس مش عارف منين؟ بطّل تخمين — خلّي الأرقام تقولك 📊**
>
> أكبر غلط في تحسين الـ performance إنك تخمّن. Flutter DevTools بيديك **frame timeline** حقيقي يوريك بالظبط أنهي frame اتأخر وليه.
>
> **القاعدة الذهبية — الـ 16ms:**
> عشان توصل لـ 60 FPS، كل frame لازم يخلص في **16 مللي ثانية** (أو ~8ms لـ 120Hz). أي frame بيعدّي الحد ده = المستخدم بيشوف تهنيج.
>
> **إزاي تشخّص؟**
> 1. شغّل التطبيق بـ **profile mode** (مش debug — الأرقام في debug مضللة):
> ```
> flutter run --profile
> ```
> 2. افتح DevTools → تبويب **Performance**.
> 3. شوف الـ Frame Chart: الأعمدة **الحمرا** هي الـ frames اللي عدّت الـ 16ms.
> 4. اضغط على frame أحمر → هيوريك انكسر الوقت فين: **UI thread** (الـ build/layout بتاعك) ولا **Raster thread** (الرسم/الـ GPU).
>
> **الترجمة العملية:**
> - بطء في الـ **UI thread** → مشكلة في الـ Dart code (rebuilds زيادة، عملية تقيلة).
> - بطء في الـ **Raster thread** → مشكلة في الرسم (shaders، opacity مكلف، clipping زيادة).
>
> 💡 استخدم كمان زر **"Track widget rebuilds"** عشان تكتشف الـ widgets اللي بتعمل rebuild أكتر من اللازم.
>
> ━━━━━━━━━━━━━━━
> بتستخدم DevTools قد إيه في شغلك اليومي؟ 👇
>
> #Flutter #DevTools #Performance #Debugging #MobileDev

**برومبت الصورة:**
```
Create a clean, modern technical infographic for LinkedIn about Flutter
DevTools performance profiling.

Style: Flat design, dark navy background (#0D1B2A) with Flutter blue
(#02569B) and cyan (#13B9FD) accents. Minimalist, professional, dashboard look.

Concept: Show a stylized "frame timeline" bar chart (like a performance
profiler). Most bars are short and green (good frames). A few bars are tall
and red, crossing a clearly marked horizontal dashed line labeled "16ms /
60 FPS budget". Add a small magnifying glass icon over one red bar.

Below or beside, show two small labels with icons: "UI Thread" (a code
brackets icon) and "Raster Thread" (a GPU chip icon).

Title at top: "Stop Guessing. Measure the Jank." White clean sans-serif text.
Keep labels short and correctly spelled: 16ms, 60 FPS, UI Thread, Raster
Thread. Aspect ratio 1200x627. No watermarks, no gibberish.
```

---

## البوست ٦ (الافتتاحي) — RepaintBoundary & Rendering Pipeline

> **ليه الـ Flutter app بتاعك بيحصله Jank؟ غالباً السبب مش الكود بتاعك… السبب الـ Repaints 🎯**
>
> كتير مننا بيفتكر إن الـ performance مشكلتها في الـ `build()` بس. الحقيقة إن Flutter بيمر بـ ٣ مراحل لكل frame:
>
> **1. Build** → بناء شجرة الـ Widgets
> **2. Layout** → حساب الأحجام والمواقع
> **3. Paint** → الرسم الفعلي على الشاشة 🎨
>
> المشكلة الخفية: لما widget صغير بيتغير (زي animation أو counter)، أحياناً Flutter بيعيد رسم منطقة أكبر بكتير من اللازم — وممكن يوصل لرسم الشاشة كلها!
>
> **الحل: `RepaintBoundary`**
> بيعمل "عزل" للجزء اللي بيتغير كتير في layer منفصلة، فالـ GPU بيعيد رسم الجزء ده بس.
>
> ```dart
> // ❌ قبل: أي تغيير ممكن يـ repaint اللي حواليه
> AnimatedLogo()
>
> // ✅ بعد: العزل في layer لوحدها
> RepaintBoundary(
>   child: AnimatedLogo(),
> )
> ```
>
> **اكتشف المشكلة قبل ما تحلها:**
> ```dart
> debugRepaintRainbowEnabled = true;
> ```
> لو لقيت مناطق كبيرة بتومض بألوان من غير سبب → ده المكان اللي محتاج `RepaintBoundary`.
>
> 💡 متحطهاش في كل مكان! كل boundary ليها تكلفة memory. استخدمها مع الأجزاء اللي بتتغير بشكل متكرر بس.
>
> ━━━━━━━━━━━━━━━
> إيه أكتر مشكلة performance قابلتك في Flutter؟ 👇
>
> #Flutter #Performance #Dart #FlutterDev #MobileDevelopment

**برومبت الصورة:**
```
Create a clean, modern technical infographic for a LinkedIn post about
Flutter rendering performance.

Style: Flat design, dark navy background (#0D1B2A) with Flutter blue
(#02569B) and cyan (#13B9FD) accents. Minimalist, high contrast.

Top: visualize the Flutter rendering pipeline as 3 connected horizontal
stages with arrows flowing left to right:
1. "BUILD" — a widget tree icon (connected nodes).
2. "LAYOUT" — rulers/measuring frames around boxes.
3. "PAINT" — a paintbrush with color drops.

Bottom: a before/after comparison:
- LEFT (labeled "Without RepaintBoundary"): a phone screen where the ENTIRE
  screen glows red (full repaint, wasteful).
- RIGHT (labeled "With RepaintBoundary"): the same phone but only a small
  isolated widget glows green, rest is calm (efficient).

Title at top: "Flutter Rendering Pipeline". White clean sans-serif text.
Keep all labels short and correctly spelled: BUILD, LAYOUT, PAINT,
RepaintBoundary. Aspect ratio 1200x627. No watermarks, no gibberish text.
```

---

## نصائح عامة للنشر

- **التوقيت:** أفضل أوقات LinkedIn للمحتوى التقني: الصبح ٨–١٠، أو بعد الضهر ٤–٦ (بتوقيت جمهورك).
- **أول سطر هو البطل:** الـ hook (السطر الأول) هو اللي بيوقف الـ scroll — خلّيه قوي.
- **نص الصورة:** Gemini ساعات بيكتب نص مغلوط. لو حصل، قوله: "Fix the text, use only these exact words: …" أو سيب النص فاضي وضيفه بنفسك في Canva.
- **التفاعل:** رد على أول ٥–١٠ كومنتات في أول ساعة — ده بيرفع الـ reach بشكل كبير.
- **الهاشتاجات:** ٣–٥ هاشتاجات كفاية، مزيج بين العام (#Flutter) والمتخصص (#Impeller).
