# سلسلة بوستات أساسيات البرمجة (CS Fundamentals) — LinkedIn

> ٦ بوستات عن مفاهيم أساسية في علوم الحاسب — مختارة بعناية إنها حاجات **بيغلط فيها ناس كتير**
> أو مش بتتشرح صح. الهدف: تبان كـ Software Engineer فاهم الأساس، مش بس Developer شغّال على framework.
>
> جدول النشر: ٣ بوستات / أسبوع (السبت / الإثنين / الأربعاء).

| اليوم | الموضوع | المفهوم الخاطئ الشائع |
|------|---------|----------------------|
| السبت | Floating Point | "الكمبيوتر بيغلط في الحساب" |
| الإثنين | Big O | "Big O يعني السرعة" |
| الأربعاء | Stack vs Heap | "كل المتغيرات في نفس المكان" |
| السبت ٢ | Pass by Value/Reference | "الـ objects بتتبعت by reference" |
| الإثنين ٢ | كيف يعمل الـ Hash Map | "الوصول دايماً O(1)" |
| الأربعاء ٢ | Concurrency vs Parallelism | "هما نفس الحاجة" |

---

## البوست ١ — ليه `0.1 + 0.2 ≠ 0.3` ؟

> **جرّب في أي لغة برمجة: `0.1 + 0.2`. الناتج هيكون `0.30000000000000004`. الكمبيوتر مش بيغلط — انت اللي مش فاهم إزاي بيفكر 🧠**
>
> ده مش bug، وده موجود في Dart و JavaScript و Python و C++ … كلهم. السبب معيار اسمه **IEEE 754** اللي بيتخزن بيه الأرقام العشرية.
>
> **المشكلة الأساسية:**
> الكمبيوتر بيخزّن كل حاجة بالـ **binary** (أصفار وآحاد). بعض الأرقام العشرية البسيطة عندنا — زي `0.1` — **مالهاش تمثيل دقيق بالـ binary**، بالظبط زي ما `1/3` مالهاش تمثيل دقيق عندنا في النظام العشري (0.3333… لا نهاية).
>
> فالكمبيوتر بيخزّن أقرب قيمة ممكنة، والفرق الصغير ده بيتراكم لما تجمع.
>
> ```dart
> print(0.1 + 0.2);        // 0.30000000000000004
> print(0.1 + 0.2 == 0.3); // false  ← الخطر هنا!
> ```
>
> **ليه ده خطير في الشغل الحقيقي؟**
> تخيل بتحسب فلوس 💸. لو قارنت مبلغين بـ `==` على float، ممكن تطلعلك العملية غلط من غير ما تفهم ليه.
>
> **الحلول الصح:**
> - للمقارنة: استخدم فرق صغير (epsilon)
> ```dart
> (a - b).abs() < 0.0001
> ```
> - للفلوس تحديداً: **متستخدمش float أصلاً**. استخدم integers (خزّن بالقروش/السنت) أو نوع Decimal مخصص.
>
> 💡 القاعدة: الـ float للقياسات التقريبية (مسافات، نِسَب)، مش للأرقام اللي لازم تكون مظبوطة ١٠٠٪.
>
> ━━━━━━━━━━━━━━━
> اتصدمت قبل كده من نتيجة حسابية في الكود؟ احكيلنا 👇
>
> #SoftwareEngineering #ComputerScience #Programming #CleanCode

**برومبت الصورة:**
```
Create a highly detailed, professional educational infographic for LinkedIn
explaining why "0.1 + 0.2 ≠ 0.3" in computers (IEEE 754 floating point).

Style: Modern flat tech illustration, dark slate background (#111827) with
electric blue (#3B82F6), teal (#14B8A6), and warm amber (#F59E0B) accents.
Clean, high-contrast, lots of structure. Looks like a premium developer
educational poster.

Layout (top to bottom, clearly sectioned):
1. HERO TITLE at top: "0.1 + 0.2 = 0.30000000000000004" shown in a code-style
   monospace box, with a surprised/glitch effect on the long decimal tail.
2. MIDDLE — a clear analogy: show a balance/comparison between two columns.
   LEFT column "Decimal (base 10)" shows "1/3 = 0.3333... (infinite)".
   RIGHT column "Binary (base 2)" shows "0.1 = 0.0001100110011... (infinite)".
   Use repeating-digit visuals to imply infinity.
3. BOTTOM — a small bit-layout diagram of an IEEE 754 double: three labeled
   segments in a row: "Sign (1 bit)", "Exponent (11 bits)", "Mantissa
   (52 bits)", each segment a different accent color.
4. A small green callout box: "Fix: compare with epsilon, or use integers
   for money".

Typography: clean sans-serif for labels, monospace for code/numbers. White
and light-grey text. Keep ALL text short and correctly spelled. Aspect ratio
1200x627 (LinkedIn landscape). No watermarks, no gibberish text, no random
symbols.
```

---

## البوست ٢ — Big O مش معناها "السرعة"

> **أكبر سوء فهم في الـ Big O: إنها بتقيس "السرعة". لأ — هي بتقيس إزاي البطء بيكبر لما البيانات تكبر 📈**
>
> خوارزمية `O(n²)` ممكن تكون **أسرع** من `O(n log n)` على ١٠ عناصر. الفرق بيبان لما العدد يكبر.
>
> **الفكرة الحقيقية:**
> Big O بتجاوب على سؤال واحد: *"لو ضاعفت حجم البيانات، الوقت هيتضاعف قد إيه؟"*
> - `O(1)` → ثابت، مش بيتأثر بالحجم
> - `O(n)` → خطي، ضِعف البيانات = ضِعف الوقت
> - `O(n²)` → ضِعف البيانات = ٤ أضعاف الوقت 😱
>
> **الحاجة اللي ناس كتير بتنساها — الثوابت موجودة في الواقع:**
> Big O بتتجاهل الثوابت (`O(2n)` = `O(n)`). نظرياً صح، عملياً الثوابت دي بتفرق! خوارزمية بتستغل الـ **cache locality** كويس ممكن تكسب واحدة "أحسن نظرياً" بسبب إزاي الذاكرة بتشتغل فعلياً.
>
> ```
> // الاتنين O(n)، بس ده أسرع في الواقع
// لإنه بيمشي على الذاكرة بالترتيب (cache-friendly)
> for (i = 0; i < n; i++) sum += arr[i];
> ```
>
> **القاعدة العملية:**
> - بيانات صغيرة → اكتب أبسط كود مقروء، متقلقش من الـ Big O.
> - بيانات بتكبر → اختار التعقيد الصح من بدري.
> - **قِس قبل ما تحسّن** (profile, don't guess).
>
> 💡 الـ Big O أداة للتفكير في الـ scaling، مش معيار مطلق للأفضلية.
>
> ━━━━━━━━━━━━━━━
> إيه أكتر مرة Big O فرقت معاك في قرار تقني؟ 👇
>
> #SoftwareEngineering #Algorithms #ComputerScience #BigO #Programming

**برومبت الصورة:**
```
Create a highly detailed, professional educational infographic for LinkedIn
explaining Big O notation — emphasizing that it measures GROWTH, not raw speed.

Style: Modern flat tech illustration, dark slate background (#111827) with
electric blue (#3B82F6), teal (#14B8A6), amber (#F59E0B), and red (#EF4444)
accents. Premium, structured, high-contrast.

Main element: a clean line GRAPH (chart) with X-axis labeled "Input size (n)"
and Y-axis labeled "Operations / time". Plot several labeled curves with
distinct colors, each clearly labeled:
- A flat green line: "O(1)"
- A teal straight diagonal line: "O(n)"
- A blue gentle curve: "O(n log n)"
- A red steep curve shooting upward: "O(n²)"
Make O(n²) visually dramatic (steep), O(1) calm and flat.

Add a callout near the small-n region of the graph: "On small data, a 'worse'
Big O can be faster". Add a small side note box: "Big O ignores constants —
but cache locality matters in the real world".

Typography: clean sans-serif, monospace for the O() labels. White/light-grey
text. Keep ALL text short and correctly spelled (O(1), O(n), O(n log n),
O(n^2)). Aspect ratio 1200x627. No watermarks, no gibberish.
```

---

## البوست ٣ — Stack vs Heap: فين بتتخزن متغيراتك؟

> **سؤال بيفرّق Software Engineer عن Developer: المتغير ده بيتخزن في الـ Stack ولا الـ Heap؟ 🧱**
>
> كل برنامج بيشتغل بمنطقتين ذاكرة مختلفتين تماماً، وفهم الفرق بيشرحلك مشاكل زي الـ Stack Overflow والـ Memory Leaks.
>
> **الـ Stack (المكدّس):**
> - سريع جداً ⚡
> - بيخزّن المتغيرات المحلية والـ function calls
> - منظّم: آخر حاجة تدخل = أول حاجة تطلع (LIFO)
> - حجمه **محدود** → لو عملت recursion بلا نهاية، بيمتلي → **Stack Overflow**
> - بيتنضف **تلقائياً** أول ما الـ function تخلص
>
> **الـ Heap (الكومة):**
> - أبطأ شوية، بس **كبير ومرن**
> - بيخزّن الـ objects والبيانات اللي عمرها أطول من الـ function
> - بيتدار بالـ Garbage Collector (في Dart/Java) أو يدوياً (في C/C++)
> - لو فضل في references لـ object مش محتاجينه → **Memory Leak**
>
> ```dart
> void example() {
>   int x = 5;              // 'x' نفسه على الـ Stack
>   var list = [1, 2, 3];   // 'list' (reference) على الـ Stack،
>                           // بس الـ List object نفسه على الـ Heap
> }
> ```
>
> **الفكرة المفتاحية اللي بتغيب عن الناس:**
> المتغير اللي شكله "object" — اللي على الـ Stack هو *العنوان* (reference)، والبيانات الفعلية على الـ Heap. ده أساس فهم موضوع الـ pass by reference (البوست الجاي 😉).
>
> 💡 لما تفهم ده، الـ Stack Overflow و الـ Memory Leaks بيبقوا منطقيين مش ألغاز.
>
> ━━━━━━━━━━━━━━━
> أول مرة شفت فيها Stack Overflow كانت بسبب إيه؟ 👇
>
> #SoftwareEngineering #ComputerScience #MemoryManagement #Programming

**برومبت الصورة:**
```
Create a highly detailed, professional educational infographic for LinkedIn
comparing Stack vs Heap memory.

Style: Modern flat tech illustration, dark slate background (#111827) with
electric blue (#3B82F6) and teal (#14B8A6) accents, plus subtle red for
warnings. Premium, structured, high-contrast developer poster look.

Layout: split the canvas into two clearly separated panels side by side.

LEFT PANEL — "STACK":
- Draw it as a vertical pile of neat stacked frames/plates (LIFO), with a
  small arrow showing "push" on top and "pop" off the top.
- Labels/icons: "Fast", "Local variables", "Auto-cleaned", "Limited size".
- A small red warning at the bottom: "Overflow if too deep".

RIGHT PANEL — "HEAP":
- Draw it as a larger, looser scattered cluster of memory blocks of varying
  sizes connected by little pointer arrows.
- Labels/icons: "Large & flexible", "Objects", "Garbage Collected", "Slower".
- A small red warning: "Leak if references linger".

In the CENTER between them, illustrate the key idea: a small stack box labeled
"reference / address" with an arrow pointing across to a heap block labeled
"actual object data".

Typography: clean sans-serif labels, monospace where appropriate. White/
light-grey text. Keep ALL text short and correctly spelled: STACK, HEAP,
reference, object data. Aspect ratio 1200x627. No watermarks, no gibberish.
```

---

## البوست ٤ — Pass by Value vs Pass by Reference

> **"في Java/Dart/Python الـ objects بتتبعت by reference" — دي جملة غلط بيقولها ناس كتير. الحقيقة أدق من كده بكتير 🎯**
>
> الموضوع ده بيلخبط مطورين بسنين خبرة، والسبب إن أغلب اللغات الحديثة بتعمل حاجة اسمها **"pass reference by value"** — مش pass by reference.
>
> **يعني إيه بالظبط؟**
> لما تبعت object لـ function، اللي بيتبعت هو **نسخة من الـ reference** (العنوان)، مش نسخة من الـ object نفسه، ومش الـ reference الأصلي.
>
> **النتيجة العملية (ركّز هنا):**
> - تقدر **تعدّل محتوى** الـ object جوه الـ function، والتعديل هيظهر بره ✅
> - بس لو حاولت **تستبدل** الـ object بواحد جديد، الأصلي **مش هيتأثر** ❌
>
> ```dart
> void mutate(List<int> list) {
>   list.add(99);        // ✅ بيأثر بره — نفس الـ object
> }
>
> void reassign(List<int> list) {
>   list = [0, 0, 0];    // ❌ مبيأثرش بره — غيّرنا النسخة المحلية بس
> }
>
> var nums = [1, 2, 3];
> mutate(nums);    // nums = [1, 2, 3, 99]
> reassign(nums);  // nums لسه [1, 2, 3, 99]
> ```
>
> **ليه ده مهم؟**
> ده بالظبط مصدر أصعب bugs الـ "ليه القيمة دي اتغيرت لوحدها؟!". لما تفهم إن اللي اتبعت نسخة من العنوان، السلوك ده بيبقى متوقع تماماً.
>
> 💡 القيم البدائية (int, bool) بتتبعت by value فعلاً. الـ objects بتتبعت بـ "نسخة من الـ reference".
>
> ━━━━━━━━━━━━━━━
> الـ bug ده اصطادك قبل كده؟ احكيلنا 👇
>
> #SoftwareEngineering #ComputerScience #Programming #CleanCode

**برومبت الصورة:**
```
Create a highly detailed, professional educational infographic for LinkedIn
explaining "pass by value" vs "pass reference by value" in programming.

Style: Modern flat tech illustration, dark slate background (#111827) with
electric blue (#3B82F6), teal (#14B8A6), green (#22C55E) for success and red
(#EF4444) for failure. Premium, structured, high-contrast.

Layout: a central object on the HEAP drawn as a box of data labeled "Object
[1,2,3]". A variable outside (caller) points to it with an arrow labeled
"original reference". When passed to a function, draw a SECOND arrow (a copy)
labeled "copied reference" also pointing to the SAME object box.

Then show two outcome panels:
- TOP panel "MUTATE (works)": the function arrow modifies the object's
  contents (show [1,2,3] -> [1,2,3,99]) with a green checkmark, and the
  caller sees the change.
- BOTTOM panel "REASSIGN (no effect)": the copied reference is redirected to
  a NEW separate object box "[0,0,0]" with a red X, while the original caller
  arrow still points to the unchanged object.

Title at top: "It's not 'pass by reference'. It's a copy of the reference."
Typography: clean sans-serif labels, monospace for arrays. White/light-grey
text. Keep ALL text short and correctly spelled. Aspect ratio 1200x627. No
watermarks, no gibberish text.
```

---

## البوست ٥ — إزاي الـ Hash Map بيشتغل فعلاً؟

> **بتستخدم `Map` / `Dictionary` كل يوم. بس تعرف ليه الوصول بيبقى تقريباً فوري؟ وامتى بيبقى بطيء؟ 🗺️**
>
> الـ Hash Map من أهم هياكل البيانات على الإطلاق، وفهم اللي تحته بيخليك تستخدمه صح.
>
> **الفكرة في سطر:**
> بدل ما يدور على المفتاح عنصر عنصر، بيحوّل المفتاح لرقم (عن طريق **hash function**)، والرقم ده بيقوله المكان بالظبط في الذاكرة. → وصول مباشر.
>
> ```
> key "ahmed"  →  hash()  →  3892  →  index 12  →  القيمة هنا
> ```
>
> **بس فيه مشكلة — الـ Collisions (التصادم):**
> أحياناً مفتاحين مختلفين بيطلعوا نفس الـ index. ساعتها الـ map بيخزّنهم في نفس الخانة (في list صغيرة أو شجرة)، ولازم يدوّر بينهم.
>
> **هنا السر اللي ناس كتير مش واخدة بالها منه:**
> الوصول `O(1)` ده **في المتوسط (amortized)**، مش مضمون. لو الـ hash function وحشة وكل المفاتيح بتتصادم → بيتحوّل لـ `O(n)` (بيبقى زي list عادية)! 😱
>
> **يعني إيه عملياً؟**
> - لما تعمل key class بتاعتك، نفّذ `hashCode` و `==` صح ومتسقين.
> - مفتاحين متساويين (`==`) **لازم** يبقى ليهم نفس الـ `hashCode`.
> ```dart
> @override
> int get hashCode => Object.hash(id, name);
> @override
> bool operator ==(other) => other is User && other.id == id;
> ```
>
> 💡 الـ hashCode الوحش = أداء وحش. ده مش تفصيلة، ده أساس.
>
> ━━━━━━━━━━━━━━━
> نفّذت `hashCode` بنفسك قبل كده؟ ولا بتسيبه للـ IDE؟ 👇
>
> #SoftwareEngineering #DataStructures #ComputerScience #Programming

**برومبت الصورة:**
```
Create a highly detailed, professional educational infographic for LinkedIn
explaining how a Hash Map works internally, including collisions.

Style: Modern flat tech illustration, dark slate background (#111827) with
electric blue (#3B82F6), teal (#14B8A6), amber (#F59E0B), red (#EF4444)
accents. Premium, structured, high-contrast educational poster.

Main flow (left to right):
1. A "key" box on the left (e.g. a label "ahmed").
2. An arrow into a gear/funnel icon labeled "hash function".
3. An arrow out to a number, e.g. "→ index 12".
4. On the right, a vertical array of numbered buckets/slots (an array of
   boxes labeled 0..n). The arrow lands in bucket 12 holding the value.

Below, illustrate a COLLISION: two different keys both pointing to the SAME
bucket, and that bucket expanding into a small linked chain of 2 items, with
a small red label "collision → O(n) in worst case".

Add a callout box: "O(1) on average — NOT guaranteed". And a small note:
"equal keys must share the same hashCode".

Typography: clean sans-serif, monospace for keys/indices. White/light-grey
text. Keep ALL text short and correctly spelled: hash function, index,
collision, O(1), O(n), bucket. Aspect ratio 1200x627. No watermarks, no
gibberish.
```

---

## البوست ٦ — Concurrency مش Parallelism

> **بيتقالوا كأنهم نفس الحاجة، وهما مفهومين مختلفين تماماً. الفرق ده بيفرّق المهندس عن غيره 🔀**
>
> **Concurrency (التزامن):**
> التعامل مع **أكتر من مهمة في نفس الفترة** — بس مش بالضرورة في نفس اللحظة. الـ CPU بيبدّل بسرعة بين المهام (context switching) لدرجة إنها *تبان* متوازية.
>
> **Parallelism (التوازي):**
> تنفيذ **أكتر من مهمة في نفس اللحظة فعلاً** — وده محتاج أكتر من نواة (core) أو معالج.
>
> **التشبيه الأوضح ☕:**
> - **Concurrency:** باريستا واحد بيعمل قهوتين — بيبدأ في الأولى، وبينما بتسخّن بيبدأ في التانية، بيلف بينهم. مهمة واحدة في اللحظة، بس بيتقدّم في الاتنين.
> - **Parallelism:** اتنين باريستا، كل واحد بيعمل قهوة — في نفس اللحظة بالظبط.
>
> **الخلاصة اللي بتلخبط الناس:**
> - تقدر يكون عندك **concurrency من غير parallelism** (نواة واحدة بتبدّل بين المهام — زي async/await).
> - الـ **parallelism محتاج hardware** فيه أكتر من نواة.
>
> **في الكود:**
> - `async/await` → concurrency (مهمة بتستنى I/O، فالـ CPU يشتغل على غيرها).
> - Threads / Isolates حقيقية على أنوية متعددة → parallelism.
>
> ```dart
> // Concurrency: بنستنى الشبكة، الـ CPU فاضي يشتغل على غيره
> final data = await fetchFromNetwork();
>
> // Parallelism: شغل حقيقي بالتوازي على أنوية مختلفة
> await Future.wait([Isolate.run(taskA), Isolate.run(taskB)]);
> ```
>
> 💡 القاعدة: الـ Concurrency عن **التنظيم** (بنية البرنامج). الـ Parallelism عن **التنفيذ** (الهاردوير).
>
> ━━━━━━━━━━━━━━━
> أنهي واحدة بتستخدمها أكتر في شغلك؟ 👇
>
> #SoftwareEngineering #Concurrency #ComputerScience #Programming

**برومبت الصورة:**
```
Create a highly detailed, professional educational infographic for LinkedIn
explaining the difference between Concurrency and Parallelism using a coffee
shop barista analogy.

Style: Modern flat tech illustration, dark slate background (#111827) with
electric blue (#3B82F6), teal (#14B8A6), amber (#F59E0B) accents. Premium,
warm, friendly but technical. High-contrast.

Split into two clearly labeled panels side by side:

LEFT PANEL — "CONCURRENCY":
- ONE barista character juggling TWO coffee cups, with curved arrows showing
  them switching attention back and forth between the two cups.
- Small caption: "one worker, switching tasks".
- A tiny CPU icon with a single core and a "context switch" loop arrow.

RIGHT PANEL — "PARALLELISM":
- TWO barista characters, each making one coffee cup at the same time.
- Small caption: "multiple workers, truly at once".
- A tiny CPU icon with two cores both active.

Title at top: "Concurrency is NOT Parallelism". A bottom strip with two mini
labels: "async/await = concurrency" and "multi-core = parallelism".

Typography: clean sans-serif. White/light-grey text. Keep ALL text short and
correctly spelled: CONCURRENCY, PARALLELISM, async/await, multi-core. Aspect
ratio 1200x627. No watermarks, no gibberish text.
```

---

## ليه المواضيع دي بالظبط؟

كل موضوع اتختار لإنه **مفهوم خاطئ شائع** — يعني هتقدّم قيمة حقيقية وتصحّح معلومة غلط، وده اللي بيخلّي البوست ينتشر ويخلّيك تبان كمرجع:

| الموضوع | الغلط اللي بتصلّحه |
|---------|---------------------|
| Floating Point | "الكمبيوتر بيغلط" → لأ، انت مش فاهم IEEE 754 |
| Big O | "Big O = السرعة" → لأ، هي معدّل النمو |
| Stack vs Heap | "كل المتغيرات سواء" → لأ، فيه منطقتين مختلفتين |
| Pass by Reference | "الـ objects by reference" → لأ، نسخة من الـ reference |
| Hash Map | "دايماً O(1)" → لأ، amortized وممكن يبقى O(n) |
| Concurrency/Parallelism | "نفس الحاجة" → لأ، تنظيم مقابل تنفيذ |

## ملاحظة على الكود في البوستات

استخدمت Dart في الأمثلة عشان يفضل متسق مع هويتك (Flutter)، بس المفاهيم **language-agnostic** — وده بالظبط الرسالة: إنك مهندس فاهم الأساس اللي تحت أي لغة، مش مربوط بـ framework واحد.
