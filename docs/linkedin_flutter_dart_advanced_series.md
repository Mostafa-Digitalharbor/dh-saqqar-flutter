# سلسلة Flutter & Dart المتقدمة — LinkedIn (١٠ بوستات)

> ١٠ بوستات تقنية متقدمة في Flutter و Dart — كلها مواضيع جديدة (مش متكررة مع السلاسل السابقة).
> الهدف: تبان كمهندس فاهم الإطار من جوّه، مش بس بيستخدم الـ widgets.
> جدول مقترح: ٣ بوستات / أسبوع (السبت / الإثنين / الأربعاء).

| # | الموضوع | الفكرة اللي بتوصّلها |
|---|---------|----------------------|
| ١ | الثلاث شجرات (Widget/Element/RenderObject) | الـ Widget مش هو اللي على الشاشة فعلاً |
| ٢ | الـ Keys | السر اللي بيحافظ على state العناصر في القوايم |
| ٣ | الـ BuildContext | هو إيه بالظبط وليه بيغلط معاك |
| ٤ | الـ Event Loop في Dart | إزاي single-thread بيعمل async من غير threads |
| ٥ | Streams vs Futures | قيمة واحدة مقابل سيل قيم |
| ٦ | الـ Mixins | إعادة استخدام السلوك من غير وراثة متعددة |
| ٧ | Records & Patterns (Dart 3) | ترجّع أكتر من قيمة وتفكّكها بسطر |
| ٨ | Sealed Classes (Dart 3) | الـ compiler يجبرك تغطّي كل الحالات |
| ٩ | الـ Memory Leaks | ليه لازم تعمل dispose وإمتى |
| ١٠ | الـ InheritedWidget | أصل Provider و Theme و MediaQuery |

---

## البوست ١ — الثلاث شجرات: الـ Widget مش هو اللي على الشاشة فعلاً 🌳

> **سؤال بيكشف اللي فاهم Flutter من جوّه: لو الـ Widgets بتتبني وتترمي مع كل rebuild (immutable)، أمّال الـ state بيتحفظ إزاي؟ السر في شجرة تانية مبتشوفهاش 👇**
>
> إحنا بنكتب Widgets، وفاكرين إنها هي اللي على الشاشة. الحقيقة إن Flutter بيشتغل بـ **٣ شجرات** متوازية:
>
> **1. شجرة الـ Widgets** 🧩
> دي اللي بتكتبها انت. خفيفة جداً، **immutable**، وبتتعمل وترمي عشرات المرات في الثانية. هي مجرد "وصفة / configuration" — مش كائن حقيقي على الشاشة.
>
> **2. شجرة الـ Elements** 🔗
> دي الطبقة الوسيطة اللي **بتعيش وتفضل ثابتة** عبر الـ rebuilds. كل Element بيمسك الـ state وبيربط الـ Widget (الوصفة) بالـ RenderObject (الرسم). ده اللي بيخلي الـ `State` بتاعتك مبتضيعش لما الـ widget يتبني من جديد.
>
> **3. شجرة الـ RenderObjects** 🎨
> دي اللي بتعمل الشغل التقيل فعلاً: الـ layout (الحجم والمكان) والـ paint (الرسم). تقيلة، وعشان كده Flutter بيحاول يعيد استخدامها قدر الإمكان بدل ما يبنيها من جديد.
>
> ```
> Widget (وصفة، بترمى وتتعمل)  →  Element (بيعيش، بيمسك الـ state)  →  RenderObject (بيرسم)
> ```
>
> **الفايدة العملية (ركّز هنا):**
> لما تعمل `setState`، Flutter **مبيرميش** شجرة الـ Elements. بيمر عليها ويقارن الـ Widget الجديد بالقديم (نفس النوع ونفس الـ key؟) → لو أيوه، بيعيد استخدام نفس الـ Element والـ RenderObject ويحدّث القيم بس. ده اللي بيخلّي rebuild مكلّف مليون widget رخيص في الواقع.
>
> 💡 لما تفهم إن الـ Widget مجرد وصفة بتترمى، هتبطّل تخاف من كتر الـ rebuilds، وهتركّز على المكان الصح: تقليل شغل الـ Element/RenderObject (بالـ `const` والـ keys).
>
> ━━━━━━━━━━━━━━━
> كنت فاكر إن الـ Widget هو اللي على الشاشة؟ 👇
>
> #Flutter #Dart #FlutterDev #MobileDev #SoftwareEngineering

**برومبت الصورة:**
```
Create a clean, modern technical infographic for LinkedIn explaining Flutter's
three trees: Widget vs Element vs RenderObject.

Style: Flat design, dark navy background (#0D1B2A) with Flutter blue (#02569B)
and cyan (#13B9FD) accents. Minimalist, professional, high contrast developer
poster.

Main layout: three vertical tree diagrams side by side, connected left-to-right
with arrows, each clearly labeled:
1. LEFT "Widget Tree" — light, ghosted/translucent nodes with a small recycle
   icon and a caption "blueprint • immutable • rebuilt often". Make it look
   disposable.
2. CENTER "Element Tree" — solid, glowing cyan nodes with a small anchor/pin
   icon and a caption "persists • holds state". Make it look stable and alive.
3. RIGHT "RenderObject Tree" — nodes drawn as paint/ruler icons with a caption
   "layout & paint • heavy". 

Draw horizontal arrows connecting the corresponding nodes across the three
trees (Widget -> Element -> RenderObject).

Title at top: "Flutter's 3 Trees". Add a small bottom caption: "The Widget is
NOT what's on screen". Clean white sans-serif text, monospace for any code.
Keep ALL text short and correctly spelled: Widget Tree, Element Tree,
RenderObject Tree, state, paint. Aspect ratio 1200x627 (LinkedIn landscape).
No watermarks, no gibberish text.
```

---

## البوست ٢ — الـ Keys: السر اللي بيحافظ على عناصرك في القوايم 🔑

> **عندك ListView، حذفت أول عنصر… فلقيت الـ state بتاع العناصر اتلخبط كله! checkbox اتشال، لون اتبدّل. السبب إنك ناسي حاجة اسمها Key 🔑**
>
> لما Flutter بيعمل rebuild لقايمة، بيقارن الـ Widget القديم بالجديد عشان يقرر يعيد استخدام الـ Element ولا يعمل واحد جديد. القرار ده بياخده بـ **نوع الـ Widget + الـ Key**.
>
> **المشكلة من غير keys:**
> Flutter بيقارن بالـ **مكان (position)** في الشجرة. فلو شِلت أول عنصر، كل العناصر بتتزحلق مكان، وFlutter بيفتكر إن العنصر الأول لسه موجود — فبيربط الـ state القديم بالعنصر الغلط.
>
> ```dart
> // ❌ من غير key: الـ state بيتربط بالمكان، مش بالعنصر
> ListView(children: items.map((i) => TodoTile(i)).toList())
>
> // ✅ مع key: الـ state بيتبع العنصر نفسه مهما اتحرك
> ListView(
>   children: items.map((i) => TodoTile(i, key: ValueKey(i.id))).toList(),
> )
> ```
>
> **أنواع الـ Keys اللي تهمّك:**
> - **`ValueKey`** → بتربط بقيمة فريدة (زي `id`). ده اللي هتستخدمه ٩٠٪ من الوقت.
> - **`ObjectKey`** → لما الهوية بتيجي من الكائن نفسه كله.
> - **`UniqueKey`** → بيعمل key فريد كل مرة → بيجبر Flutter يبني العنصر من جديد (استخدمه بحذر).
> - **`GlobalKey`** → بيديك وصول لـ state/context من بره الشجرة (زي `Form`). تقيل، استخدمه لما تحتاجه فعلاً بس.
>
> **القاعدة الذهبية:**
> محتاج keys لما يكون عندك **قايمة من نفس نوع الـ widgets ليها state**، وبتعيد ترتيبها / تحذف / تضيف. لو القايمة ثابتة أو stateless → مش محتاجها.
>
> 💡 لو حسّيت إن "الـ state بيتنقل للعنصر الغلط" — ده دايماً تقريباً مشكلة keys.
>
> ━━━━━━━━━━━━━━━
> اصطادك الـ bug ده قبل كده في ListView؟ 👇
>
> #Flutter #Dart #FlutterDev #MobileDev #CleanCode

**برومبت الصورة:**
```
Create a clean, modern technical infographic for LinkedIn explaining Flutter
Keys and how they preserve widget state in lists.

Style: Flat design, dark navy background (#0D1B2A) with Flutter blue (#02569B)
and cyan (#13B9FD) accents, plus red (#EF4444) for the error case and green
(#22C55E) for the correct case. Minimalist, professional, high contrast.

Split into two stacked rows, each showing a vertical list of 3 colored cards
(each card has a small checkbox that represents its state).

TOP ROW labeled "Without Keys (state binds to position)":
- Show the list before and after deleting the first item. After deletion, draw
  the state/checkboxes staying in the WRONG positions (state mismatched),
  marked with a red X and a small "state jumped to wrong item" caption.

BOTTOM ROW labeled "With ValueKey (state follows the item)":
- Same delete action, but the checkboxes/state correctly move WITH their cards,
  marked with a green check and a caption "state stays correct".

Add a large stylized key icon as the hero element in the center divider.
Title at top: "Keys Keep State in the Right Place". Clean white sans-serif
text, monospace for "ValueKey". Keep ALL text short and correctly spelled:
Without Keys, ValueKey, state. Aspect ratio 1200x627. No watermarks, no
gibberish text.
```

---

## البوست ٣ — الـ BuildContext هو إيه بالظبط؟ وليه بيرميلك errors 🧭

> **كل `build` بتاخد `BuildContext context`، وبتستخدمه طول اليوم… بس لو سألتك هو إيه بالظبط، هتعرف تجاوب؟ فهمه بيخلّصك من نص errors اللي بتقابلك 🧭**
>
> الـ `BuildContext` مش حاجة سحرية — هو ببساطة **مرجع لمكان الـ Widget في شجرة الـ Elements**. يعني هو الـ Element نفسه بيتقدّملك بصيغة مبسّطة.
>
> **ليه ده مهم؟**
> عشان كل عمليات الـ "lookup" بتمشي **لفوق** في الشجرة من النقطة دي. لما تكتب `Theme.of(context)` أو `Provider.of(context)`، انت بتقوله: "ابتدي من مكاني وطلع لفوق لحد ما تلاقي أقرب `Theme` / `Provider`".
>
> **الخطأ الكلاسيكي #1 — استخدام context قبل ما يتركّب في الشجرة:**
> ```dart
> // ❌ بتدوّر على Scaffold فوقك وانت لسه نفس الـ context
> @override
> Widget build(BuildContext context) {
>   ScaffoldMessenger.of(context); // ممكن يلاقي الغلط
>   return Scaffold(...);
> }
> ```
> الحل: استخدم `Builder` عشان تجيب context **جوّه** الـ Scaffold، أو خد المرجع في وقت أنسب.
>
> **الخطأ الكلاسيكي #2 — استخدام context بعد `await`:**
> ```dart
> onPressed: () async {
>   await saveData();
>   // ❌ ممكن الـ widget يكون اتشال خلاص من الشجرة!
>   Navigator.of(context).pop();
> }
> ```
> الحل: اتأكد إن الـ widget لسه موجود قبل ما تستخدم الـ context:
> ```dart
>   if (!context.mounted) return;
>   Navigator.of(context).pop();
> ```
>
> 💡 القاعدة: الـ context بيعبّر عن **مكان ولحظة** في الشجرة. لو المكان غلط (فوق اللي بتدوّر عليه) أو اللحظة غلط (بعد await والـ widget اتشال) → بيجيلك error. افهم النقطتين دول وريّح دماغك.
>
> ━━━━━━━━━━━━━━━
> قابلك "looking up a deactivated widget's ancestor" قبل كده؟ 👇
>
> #Flutter #Dart #FlutterDev #MobileDev #SoftwareEngineering

**برومبت الصورة:**
```
Create a clean, modern technical infographic for LinkedIn explaining what
Flutter's BuildContext really is and how lookups work.

Style: Flat design, dark navy background (#0D1B2A) with Flutter blue (#02569B)
and cyan (#13B9FD) accents, plus red (#EF4444) for the error cases.
Minimalist, professional, high contrast.

Main visual: a vertical tree of nodes (the widget/element tree). Near the
bottom, highlight one node with a glowing pin/location marker labeled "you are
here = BuildContext". From that node, draw an UPWARD arrow traveling up the
tree, passing nodes labeled "Provider", "Theme", "Scaffold", with a caption
".of(context) searches UPWARD".

On the right side, two small red error cards stacked:
1. "Used too early — ancestor not found yet" with a small clock icon.
2. "Used after await — widget unmounted" with a small unplugged icon, and a
   fix tag "check context.mounted" with a green check.

Title at top: "BuildContext = your spot in the tree". Clean white sans-serif
text, monospace for ".of(context)" and "context.mounted". Keep ALL text short
and correctly spelled: BuildContext, Provider, Theme, Scaffold, mounted.
Aspect ratio 1200x627. No watermarks, no gibberish text.
```

---

## البوست ٤ — الـ Event Loop: إزاي Dart بيعمل async وهو single-thread؟ 🔄

> **Dart بيشتغل على thread واحد… أمّال بيعمل إزاي مليون عملية async في نفس الوقت من غير ما الـ UI يتجمّد؟ السر مش threads — السر الـ Event Loop 🔄**
>
> الـ async في Dart **مش** معناه threads جديدة. كله بيحصل على نفس الـ thread، عن طريق حلقة بتلف باستمرار اسمها **Event Loop**، وبتاخد شغل من **طابورين**:
>
> **1. Microtask Queue** (أولوية أعلى ⚡)
> طابور للمهام القصيرة جداً الداخلية (زي اللي بيتولّد من `Future` بيخلص، أو `scheduleMicrotask`). الـ Event Loop **بيفضّي الطابور ده بالكامل** قبل ما يبص للطابور التاني.
>
> **2. Event Queue** (أولوية أقل)
> طابور للأحداث الأكبر: I/O، الـ timers، نقرات المستخدم، رسائل الـ isolates، و`Future.delayed`.
>
> **الترتيب اللي بيشتغل بيه (مهم جداً):**
> ```
> 1. نفّذ كل الكود المتزامن (sync) لحد ما يخلص
> 2. فضّي الـ Microtask Queue بالكامل
> 3. خد حدث واحد من الـ Event Queue
> 4. ارجع فضّي الـ Microtasks تاني
> 5. كرّر ➰
> ```
>
> **مثال بيلخبط ناس كتير — خمّن الترتيب:**
> ```dart
> print('1');
> Future(() => print('2'));                 // event queue
> Future.microtask(() => print('3'));       // microtask queue
> print('4');
> // الناتج: 1, 4, 3, 2
> ```
> الـ `1` و `4` متزامنين (الأول). بعدين الـ microtask (`3`) قبل الـ event (`2`) — رغم إنه اتكتب بعديه!
>
> **ليه ده يفيدك عملياً؟**
> لو حطيت شغل تقيل في microtask، ممكن **تجوّع** الـ Event Queue وتأخّر استجابة الـ UI (النقرات والرسم في الـ event queue). فالقاعدة: المهام التقيلة → isolate. المهام البسيطة → سيبها للـ async العادي.
>
> 💡 `async/await` مش سحر ولا threads — هو مجرد طريقة أنيقة تقول للـ Event Loop "كمّل السطر ده لما النتيجة دي تجهز".
>
> ━━━━━━━━━━━━━━━
> عرفت تتوقّع ناتج الـ `1,4,3,2` صح من أول مرة؟ 👇
>
> #Flutter #Dart #AsyncAwait #SoftwareEngineering #FlutterDev

**برومبت الصورة:**
```
Create a clean, modern technical infographic for LinkedIn explaining Dart's
single-threaded event loop with the microtask queue and event queue.

Style: Flat design, dark navy background (#0D1B2A) with Flutter blue (#02569B),
cyan (#13B9FD), and amber (#F59E0B) accents. Minimalist, professional, high
contrast.

Center: a large circular loop arrow (the "Event Loop") with a small CPU/gear
icon in the middle, labeled "Event Loop (single thread)".

Feeding into the loop, draw TWO horizontal queues as rows of boxes:
1. TOP queue labeled "Microtask Queue — HIGH priority" (cyan), with a small
   lightning icon and caption "drained FULLY first".
2. BOTTOM queue labeled "Event Queue — I/O, timers, taps" (amber), with caption
   "one event at a time".

On the right, show a small code-result panel demonstrating order:
"print order: 1 → 4 → 3 → 2" with tiny tags mapping 3=microtask, 2=event.

Title at top: "How Dart Does Async on ONE Thread". Clean white sans-serif text,
monospace for the print order. Keep ALL text short and correctly spelled:
Event Loop, Microtask Queue, Event Queue. Aspect ratio 1200x627. No watermarks,
no gibberish text.
```

---

## البوست ٥ — Streams vs Futures: قيمة واحدة مقابل سيل قيم 🌊

> **الـ Future بتجيبلك قيمة واحدة في المستقبل. بس لو محتاج سيل قيم بتتحدّث مع الوقت — موقع GPS، رسائل شات، ضغطات زرار؟ ده شغل الـ Stream 🌊**
>
> الاتنين بيتعاملوا مع المستقبل، بس الفرق جوهري:
>
> **الـ Future = وعد بقيمة واحدة** (بتيجي مرة وتخلص):
> ```dart
> Future<User> fetchUser();   // قيمة واحدة، بعدها خلاص
> final user = await fetchUser();
> ```
>
> **الـ Stream = سلسلة قيم عبر الزمن** (٠ أو أكتر، وممكن تفضل شغّالة):
> ```dart
> Stream<int> counter();      // 1... 2... 3... على مدار الوقت
> await for (final n in counter()) {
>   print(n);                 // بيطبع كل قيمة أول ما توصل
> }
> ```
>
> **إزاي تعمل Stream بنفسك — `async*` و `yield`:**
> ```dart
> Stream<int> countTo(int max) async* {
>   for (int i = 1; i <= max; i++) {
>     await Future.delayed(const Duration(seconds: 1));
>     yield i;               // "ابعت" القيمة دي للـ stream واستنى
>   }
> }
> ```
> الـ `yield` بيرمي قيمة في الـ stream من غير ما يخرج من الدالة (عكس `return`).
>
> **نوعين من الـ Streams لازم تفرّق بينهم:**
> - **Single-subscription** → مستمع واحد بس (زي قراءة ملف). الافتراضي.
> - **Broadcast** → كذا مستمع في نفس الوقت (زي أحداث UI). تعمله بـ `.asBroadcastStream()`.
>
> **في Flutter بتستخدمها كل يوم:**
> `StreamBuilder` بيعيد بناء الـ UI تلقائياً مع كل قيمة جديدة في الـ stream — مثالي للبيانات الحيّة (Firebase, WebSocket, sensors).
>
> 💡 القاعدة: حدث بيحصل **مرة** → Future. حاجة بتتحدّث **على مدار الوقت** → Stream. ومتنساش تعمل `cancel` للـ subscription عشان متعملش memory leak (شوف بوست الـ leaks 😉).
>
> ━━━━━━━━━━━━━━━
> أكتر مكان استخدمت فيه Stream في مشروعك؟ 👇
>
> #Flutter #Dart #Streams #AsyncAwait #FlutterDev

**برومبت الصورة:**
```
Create a clean, modern technical infographic for LinkedIn comparing Dart
Futures vs Streams.

Style: Flat design, dark navy background (#0D1B2A) with Flutter blue (#02569B)
and cyan (#13B9FD) accents. Minimalist, professional, high contrast.

Split the canvas into two clearly labeled panels side by side.

LEFT PANEL — "FUTURE": draw a single pipe/arrow delivering ONE wrapped gift box
(a single value) at the end, with a caption "one value, then done". Add a small
tag: "await fetchUser()".

RIGHT PANEL — "STREAM": draw a flowing river/pipe emitting MULTIPLE value
bubbles spaced out along a timeline arrow (labeled t1, t2, t3...), with a
caption "many values over time". Add small tags: "async* / yield" and
"StreamBuilder".

Add a bottom strip with two mini examples: "GPS, chat, taps = Stream" and
"single API call = Future".

Title at top: "One Value vs A Flow of Values". Clean white sans-serif text,
monospace for code tags. Keep ALL text short and correctly spelled: Future,
Stream, yield, StreamBuilder. Aspect ratio 1200x627. No watermarks, no
gibberish text.
```

---

## البوست ٦ — الـ Mixins: إعادة استخدام السلوك من غير وراثة 🧬

> **عايز تشارك نفس الكود بين كذا class مش بينهم علاقة وراثة؟ الحل مش copy-paste، ومش وراثة متعددة (Dart مبيسمحش بيها أصلاً). الحل: Mixins 🧬**
>
> الـ Mixin طريقة تحقن **سلوك (methods/properties)** في كذا class من غير ما تعمل علاقة "is-a" (وراثة). بتفكّر فيه كـ "قدرة" بتديها للـ class.
>
> **المشكلة اللي بيحلها:**
> عندك `Bird` و `Plane` — الاتنين بيطيروا، بس مفيش بينهم أب مشترك منطقي. تكرّر كود الطيران؟ تعمل أب مصطنع غريب؟ لأ — تعمل mixin اسمه `CanFly`.
>
> ```dart
> mixin CanFly {
>   void fly() => print('Flying! ✈️');
> }
>
> mixin CanSwim {
>   void swim() => print('Swimming! 🏊');
> }
>
> // بتاخد القدرتين مع بعض — "وراثة متعددة" للسلوك
> class Duck with CanFly, CanSwim {}
>
> Duck().fly();   // Flying!
> Duck().swim();  // Swimming!
> ```
>
> **كلمة `on` — تقييد قوي:**
> تقدر تقول إن الـ mixin ده ميتحطّش إلا على class معيّن، فيقدر يستخدم أعضاءه:
> ```dart
> mixin Logger on Widget {
>   void log() => print('Building $runtimeType');
> }
> // دلوقتي Logger يقدر يستخدم خصائص Widget، وميتحطش على غيره
> ```
>
> **استخدامها في Flutter اللي اتقابلت بيه أكيد:**
> `SingleTickerProviderStateMixin` — لما تكتب `with SingleTickerProviderStateMixin` عشان تعمل `AnimationController`، انت بتحقن قدرة الـ `vsync` في الـ State بتاعتك. ده mixin!
>
> **Mixin مقابل Interface مقابل Extends:**
> - `extends` → "هو نوع من" (علاقة هوية). class واحد بس.
> - `implements` → "بيلتزم بالشكل ده" (لازم تكتب كل حاجة بنفسك).
> - `with` (mixin) → "بياخد القدرة دي **بتنفيذها**". كذا واحد.
>
> 💡 القاعدة: السلوك المشترك اللي مالوش علاقة وراثة منطقية → mixin. ده بيخلّي الكود DRY من غير شجرة وراثة متشابكة.
>
> ━━━━━━━━━━━━━━━
> استخدمت mixin من عندك قبل كده ولا بس اللي جاهزة؟ 👇
>
> #Flutter #Dart #OOP #CleanCode #FlutterDev

**برومبت الصورة:**
```
Create a clean, modern technical infographic for LinkedIn explaining Dart
mixins (reusing behavior without inheritance).

Style: Flat design, dark navy background (#0D1B2A) with Flutter blue (#02569B)
and cyan (#13B9FD) accents. Minimalist, professional, high contrast.

Central concept: show two "ability" capsules/chips floating, labeled
"CanFly ✈️" and "CanSwim 🏊" (drawn as glowing puzzle pieces or LEGO-style
blocks). Draw arrows showing them snapping INTO a class box labeled "Duck",
which then displays both abilities. Caption near Duck: "class Duck with CanFly,
CanSwim".

On the side, a small comparison legend with three rows:
- "extends = is-a (one parent)"
- "implements = contract only"
- "with (mixin) = borrow behavior (many)"

Add a small real-world tag at the bottom: "Flutter: SingleTickerProviderStateMixin".

Title at top: "Mixins: Share Behavior, Not a Family Tree". Clean white
sans-serif text, monospace for code. Keep ALL text short and correctly spelled:
mixin, with, CanFly, CanSwim, extends, implements. Aspect ratio 1200x627. No
watermarks, no gibberish text.
```

---

## البوست ٧ — Records & Patterns: ترجّع أكتر من قيمة وتفكّكها بسطر (Dart 3) 📦

> **محتاج دالة ترجّع قيمتين مع بعض؟ زمان كنت تعمل class مخصوص أو List ملخبطة. من Dart 3 بقى عندك حل أنيق: Records & Patterns 📦**
>
> دي من أقوى إضافات Dart 3، وبتغيّر طريقة كتابتك فعلاً.
>
> **الـ Records — تجمّع قيم من غير ما تعرّف class:**
> ```dart
> // بترجّع قيمتين مسمّيين على طول
> (double lat, double lng) location() => (30.0444, 31.2357);
>
> // أو بأسماء (named fields)
> ({int code, String msg}) status() => (code: 200, msg: 'OK');
> ```
>
> **الـ Patterns — تفكّك القيم (destructuring) بسطر:**
> ```dart
> // فكّك الـ record لمتغيرين مباشرة
> final (lat, lng) = location();
> print('$lat, $lng');   // 30.0444, 31.2357
>
> // فكّك List
> final [first, second, ...rest] = [1, 2, 3, 4, 5];
> // first = 1, second = 2, rest = [3, 4, 5]
> ```
>
> **الـ Switch بقى وحش حقيقي — pattern matching:**
> ```dart
> final result = switch (response) {
>   (code: 200, :final msg) => 'Success: $msg',
>   (code: 404, :_)         => 'Not found',
>   (code: >= 500, :_)      => 'Server error',
>   _                       => 'Unknown',
> };
> ```
> بصّ — بتطابق على **الشكل والقيمة** مع بعض، وتستخرج البيانات في نفس اللحظة. ده أقوى بمراحل من `if/else` المتشعّبة.
>
> **حاجة لذيذة — if-case:**
> ```dart
> if (json case {'name': String name, 'age': int age}) {
>   print('$name is $age');   // بيتأكد من الشكل والنوع ويستخرج في خطوة
> }
> ```
>
> 💡 الـ Records خفيفة (value-based equality جاهزة)، مثالية للقيم المؤقتة المرتبطة. لو القيمة ليها سلوك أو هوية ثابتة → لسه class أنسب. بس للرجوع السريع والتفكيك → Records & Patterns بتختصرلك كود كتير.
>
> ━━━━━━━━━━━━━━━
> جرّبت Records & Patterns في Dart 3 ولا لسه؟ 👇
>
> #Flutter #Dart #Dart3 #CleanCode #FlutterDev

**برومبت الصورة:**
```
Create a clean, modern technical infographic for LinkedIn explaining Dart 3
Records and Patterns (returning multiple values and destructuring).

Style: Flat design, dark navy background (#0D1B2A) with Flutter blue (#02569B)
and cyan (#13B9FD) accents, plus a touch of green (#22C55E). Minimalist,
professional, high contrast.

Split into two connected sections:

LEFT "RECORDS — bundle values": draw a function box outputting a single
package/parcel that contains TWO labeled items inside it, e.g. "(lat, lng)"
and "(code: 200, msg: 'OK')". Caption: "return many values, no class needed".

RIGHT "PATTERNS — destructure": draw the package being opened, with its two
items flowing out into two separate labeled variable boxes (an unboxing/
unzipping visual). Caption: "final (lat, lng) = location()".

At the bottom, a small "switch" panel showing pattern matching rows:
"200 -> Success", "404 -> Not found", ">=500 -> Server error", styled like a
clean match table.

Title at top: "Records & Patterns (Dart 3)". Clean white sans-serif text,
monospace for code. Keep ALL text short and correctly spelled: Records,
Patterns, switch, destructure. Aspect ratio 1200x627. No watermarks, no
gibberish text.
```

---

## البوست ٨ — Sealed Classes: خلّي الـ Compiler يجبرك تغطّي كل حالة (Dart 3) 🛡️

> **بتعمل states للـ UI (Loading / Success / Error) وبتخاف تنسى حالة وتطلع bug وقت التشغيل؟ Dart 3 جاب حاجة بتمنع ده تماماً: Sealed Classes 🛡️**
>
> الـ `sealed class` معناها إنك بتقول للـ compiler: "كل الأنواع اللي بترث من ده **معروفة ومقفولة** في نفس الملف". والنتيجة سحرية: الـ compiler بقى يعرف كل الاحتمالات.
>
> ```dart
> sealed class ApiState {}
>
> class Loading extends ApiState {}
> class Success extends ApiState { final String data; Success(this.data); }
> class Failure extends ApiState { final String error; Failure(this.error); }
> ```
>
> **الفايدة القاتلة — exhaustive switch:**
> ```dart
> String render(ApiState state) => switch (state) {
>   Loading()       => 'Loading...',
>   Success(:final data)  => 'Data: $data',
>   Failure(:final error) => 'Error: $error',
>   // مفيش default محتاجينه — الـ compiler عارف إنها كل الحالات
> };
> ```
>
> **هنا السر اللي بيوفّر عليك bugs حقيقية:**
> لو ضِفت حالة جديدة بكرة، مثلاً `class Empty extends ApiState {}`، الـ **compile هيقع** في كل `switch` نسيت تغطّيها فيه، ويقولك "حالة ناقصة"! يعني الغلط بيتمسك وانت بتكتب، **مش** قدام المستخدم.
>
> **`sealed` مقابل `abstract`:**
> - `abstract class` → ممكن حد يرث منها من أي مكان → الـ compiler **مش** قادر يضمن الحالات → محتاج `default`.
> - `sealed class` → الوراثة مقفولة في الملف → الـ compiler يضمن exhaustiveness → أمان كامل.
>
> **امتى تستخدمها؟**
> أي حاجة ليها **عدد محدود معروف من الأشكال**: حالات الـ UI، نتيجة عملية (نجاح/فشل)، أنواع الأحداث، خطوات في flow. ده بديل نظيف لـ enums + بيانات.
>
> 💡 الفرق بين كود بيقع وقت التشغيل وكود بيقع وقت الـ compile = الفرق بين bug عند العميل و bug على شاشتك. الـ sealed classes بتنقل الأخطاء للناحية الصح.
>
> ━━━━━━━━━━━━━━━
> بتمثّل حالات الـ UI بإيه — enums، sealed، ولا حاجة تانية؟ 👇
>
> #Flutter #Dart #Dart3 #CleanCode #SoftwareEngineering

**برومبت الصورة:**
```
Create a clean, modern technical infographic for LinkedIn explaining Dart 3
sealed classes and exhaustive switch.

Style: Flat design, dark navy background (#0D1B2A) with Flutter blue (#02569B)
and cyan (#13B9FD) accents, plus green (#22C55E) for safety and red (#EF4444)
for the caught error. Minimalist, professional, high contrast.

Center: a parent box labeled "sealed class ApiState" with a small padlock icon
(meaning closed/sealed). Three child boxes branch from it: "Loading",
"Success", "Failure" — drawn as a closed, finite set inside a dashed boundary.

Right side: a "switch" panel listing the three cases each with a green check
(all covered). Below it, show a NEW case "Empty" being added, and a red
compiler error banner pointing at the switch: "Compile error: missing case!"
with a caption "caught at compile time, not at runtime".

Title at top: "Sealed Classes: Cover Every Case". Add a small bottom caption:
"The compiler has your back". Clean white sans-serif text, monospace for code.
Keep ALL text short and correctly spelled: sealed class, Loading, Success,
Failure, switch. Aspect ratio 1200x627. No watermarks, no gibberish text.
```

---

## البوست ٩ — الـ Memory Leaks في Flutter: ليه `dispose` مش رفاهية 🧹

> **تطبيقك بيبقى تقيل ويسخّن الموبايل مع الوقت من غير سبب واضح؟ غالباً عندك Memory Leaks — حاجات فاتحاها ونسيت تقفلها 🧹**
>
> Flutter عنده Garbage Collector، فناس كتير بتفتكر إن الذاكرة بتتنضّف لوحدها. صح — **بس** بشرط مفيش حاجة لسه ماسكة (reference) للكائن. والـ leaks بتيجي بالظبط من المراجع المنسية دي.
>
> **أشهر ٤ مصادر للـ leaks في Flutter:**
>
> **1. الـ Controllers من غير dispose:**
> ```dart
> class _MyState extends State<MyWidget> {
>   final _controller = TextEditingController();
>
>   @override
>   void dispose() {
>     _controller.dispose();   // ✅ لازم — غير كده يفضل في الذاكرة
>     super.dispose();
>   }
> }
> ```
> نفس الكلام لـ `ScrollController`, `AnimationController`, `PageController`.
>
> **2. الـ Stream subscriptions من غير cancel:**
> ```dart
> late final StreamSubscription _sub;
> _sub = stream.listen(...);
> // في dispose:
> _sub.cancel();   // ✅ غير كده الـ stream يفضل ماسكك
> ```
>
> **3. الـ Listeners من غير removeListener:**
> ```dart
> // ضِفت listener؟ شيله في dispose
> someNotifier.removeListener(_onChange);
> ```
>
> **4. الـ Timers اللي بتفضل شغّالة:**
> ```dart
> _timer = Timer.periodic(...);
> _timer?.cancel();   // ✅ في dispose
> ```
>
> **إزاي تكتشفها؟**
> DevTools → تبويب **Memory** → خد snapshot، استخدم الشاشة، ارجعلها، خد snapshot تاني. لو عدد الـ instances بيزيد ومبيرجعش ينزل → عندك leak. كمان لو شفت تحذير `A <Controller> was used after being disposed` في الـ console، ده دليل.
>
> 💡 القاعدة الذهبية: **أي حاجة بتعملها `listen` / `create` / `open` في `initState`، لازم تعملها `cancel` / `dispose` / `close` في `dispose`.** خليها عادة، مش حاجة بتفتكرها بعد ما المشكلة تحصل.
>
> ━━━━━━━━━━━━━━━
> اتصيّدت leak في تطبيقك قبل كده؟ كان سببه إيه؟ 👇
>
> #Flutter #Dart #Performance #MemoryManagement #FlutterDev

**برومبت الصورة:**
```
Create a clean, modern technical infographic for LinkedIn explaining memory
leaks in Flutter and the importance of dispose().

Style: Flat design, dark navy background (#0D1B2A) with Flutter blue (#02569B)
and cyan (#13B9FD) accents, plus red (#EF4444) for leaks and green (#22C55E)
for the fix. Minimalist, professional, high contrast.

Main visual: a smartphone with a memory bar/gauge that is overflowing and
turning red (rising memory). Around it, draw four "leaking faucet" icons, each
labeled with a common leak source:
1. "Controllers" (TextEditingController, AnimationController)
2. "Stream subscriptions"
3. "Listeners"
4. "Timers"

On the right, a clean green "dispose()" panel acting like a drain/cleanup that
closes all four faucets, with check marks and the pairing caption:
"initState opens it -> dispose closes it".

Title at top: "Don't Forget to dispose()". Add a small bottom tag: "GC can't
free what's still referenced". Clean white sans-serif text, monospace for
"dispose()". Keep ALL text short and correctly spelled: Controllers, Stream,
Listeners, Timers, dispose. Aspect ratio 1200x627. No watermarks, no gibberish
text.
```

---

## البوست ١٠ — الـ InheritedWidget: أصل كل State Management في Flutter 🌐

> **Provider, Riverpod, Theme.of(context), MediaQuery.of(context)… كلهم بيشتغلوا فوق نفس الآلية الأساسية اللي قليل اللي بيفهمها: الـ InheritedWidget 🌐**
>
> لو فهمت الـ InheritedWidget، هتفهم **إزاي** كل أدوات الـ state management بتشارك البيانات وبتعمل rebuild بكفاءة.
>
> **المشكلة اللي بيحلها:**
> عايز توصّل بيانات من widget فوق لـ widget تحت بعمق ٥ مستويات. تعديها يدوي في الـ constructors (prop drilling)؟ كابوس. الـ InheritedWidget بيخلّي أي widget تحت يوصل للبيانات **مباشرة** بـ `context`.
>
> ```dart
> class ThemeProvider extends InheritedWidget {
>   final Color color;
>   const ThemeProvider({required this.color, required super.child});
>
>   // ده اللي بيخلّي .of(context) ممكن
>   static ThemeProvider of(BuildContext context) =>
>     context.dependOnInheritedWidgetOfExactType<ThemeProvider>()!;
>
>   @override
>   bool updateShouldNotify(ThemeProvider old) => color != old.color;
> }
> ```
>
> **السحر الحقيقي في حاجتين:**
>
> **1. `dependOnInheritedWidgetOfExactType`:**
> لما widget تستخدم ده، Flutter بيسجّلها كـ "مشترك". فلما البيانات تتغير، Flutter بيعمل rebuild للـ widgets دي **بس** — مش الشجرة كلها. ده سر الكفاءة.
>
> **2. `updateShouldNotify`:**
> بيقرّر: "هل التغيير ده يستاهل أعمل rebuild للمشتركين؟". لو رجّعت `false`، محدش بيتحدّث. ده اللي بيمنع الـ rebuilds الزيادة.
>
> **الربط بالأدوات اللي بتستخدمها:**
> - `Theme.of(context)` → InheritedWidget
> - `MediaQuery.of(context)` → InheritedWidget
> - `Provider` → غلاف أنيق حوالين InheritedWidget
> - `Navigator`, `Localizations` → كلهم نفس الفكرة
>
> 💡 مش لازم تكتب InheritedWidget بإيدك كل يوم (الأدوات الجاهزة أريح). بس فهمه بيخلّيك تعرف **ليه** الـ `.of(context)` بيشتغل، وليه أحياناً بيعمل rebuild أكتر من اللازم، وإزاي تحسّنه. ده الفرق بين اللي بيستخدم الأداة واللي فاهمها.
>
> ━━━━━━━━━━━━━━━
> كنت عارف إن Theme و MediaQuery أصلهم InheritedWidget؟ 👇
>
> #Flutter #Dart #StateManagement #FlutterDev #SoftwareEngineering

**برومبت الصورة:**
```
Create a clean, modern technical infographic for LinkedIn explaining Flutter's
InheritedWidget as the foundation of state management.

Style: Flat design, dark navy background (#0D1B2A) with Flutter blue (#02569B)
and cyan (#13B9FD) accents, plus green (#22C55E) for the efficient rebuild.
Minimalist, professional, high contrast.

Main visual: a widget tree. At the TOP, a glowing node labeled "InheritedWidget
(data source)". Draw data "broadcasting" downward as a soft cyan aura over the
whole subtree. Then highlight only TWO deep descendant nodes that actually
"subscribed" (drawn with a small antenna/link icon and a green glow), with a
caption "only subscribers rebuild — not the whole tree".

Show one node reaching up with a dashed arrow labeled ".of(context)".

On the right, a small stacked legend listing what is built on it:
"Theme.of(context)", "MediaQuery.of(context)", "Provider", "Navigator" — each
with a tiny link icon pointing back to InheritedWidget.

Title at top: "InheritedWidget: The Root of State Management". Clean white
sans-serif text, monospace for ".of(context)". Keep ALL text short and
correctly spelled: InheritedWidget, Theme, MediaQuery, Provider. Aspect ratio
1200x627. No watermarks, no gibberish text.
```

---

## نصائح للنشر (تنطبق على السلسلة كلها)

- **التوقيت:** المحتوى التقني بيشتغل كويس الصبح (٨–١٠) أو بعد الضهر (٤–٦) بتوقيت جمهورك.
- **أول سطر = البطل:** كل البوستات هنا بتبدأ بسؤال أو موقف بيحصل للمطور فعلاً — ده اللي بيوقف الـ scroll.
- **التناسق البصري:** كل البرومبتات بنفس الألوان (navy `#0D1B2A` + أزرق Flutter + سماوي) → السلسلة هتبان موحّدة واحترافية، ومتطابقة مع سلسلة Flutter السابقة.
- **نص الصورة:** لو Gemini كتب أي مصطلح غلط، قوله: `"Fix the text, use only these exact words: ..."` أو سيب النص فاضي وضيفه في Canva.
- **التفاعل:** رد على أول ٥–١٠ كومنتات في أول ساعة — بيرفع الـ reach بشكل كبير.
- **فكرة carousel:** البوستات اللي فيها مراحل (الثلاث شجرات، الـ Event Loop، مصادر الـ leaks) ممكن تتعمل carousel (كذا صورة) لو حابب تفاعل أعلى.

## ليه المواضيع دي بالظبط؟

كل المواضيع اتختارت إنها **"تحت الكابوت"** — حاجات بيستخدمها المطور كل يوم من غير ما يعرف إزاي بتشتغل. ده اللي بيخلّيك تبان كمهندس فاهم الإطار، مش بس بيلزّق widgets:

| الموضوع | الفكرة اللي بتميّزك |
|---------|---------------------|
| الثلاث شجرات | تفهم rebuilds وكفاءة Flutter من جوّه |
| Keys | تحل bugs الـ state في القوايم اللي بتلخبط الناس |
| BuildContext | تفهم نص errors الـ context قبل ما تحصل |
| Event Loop | تفهم async من غير أسطورة "threads" |
| Streams | تفرّق امتى Future وامتى Stream |
| Mixins | إعادة استخدام نظيفة من غير شجرة وراثة متشابكة |
| Records & Patterns | كود أقصر وأأمن في Dart 3 |
| Sealed Classes | تنقل الأخطاء من runtime لـ compile-time |
| Memory Leaks | تطبيق خفيف ومحترف |
| InheritedWidget | تفهم كل أدوات الـ state management من أصلها |
