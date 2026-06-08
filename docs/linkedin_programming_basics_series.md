# سلسلة أساسيات البرمجة المفيدة — LinkedIn (١٠ بوستات)

> ١٠ بوستات تعليمية عن أساسيات البرمجة وإزاي الكمبيوتر بيشتغل تحت — محتوى بيضيف معلومة حقيقية للمبرمج.
> الهدف: تبان كمهندس فاهم الأساس، ومحتوى ينفع كل المبرمجين (مش متخصص في framework واحد).
>
> جدول مقترح: ٣–٤ بوستات / أسبوع.

| # | الموضوع |
|---|---------|
| ١ | Compiler vs Interpreter vs JIT |
| ٢ | النظام الثنائي (Binary) وأنظمة الأرقام |
| ٣ | ليه فيه لغات أسرع من لغات؟ |
| ٤ | رحلة الكود: من Source Code لـ Machine Code |
| ٥ | Static vs Dynamic Typing |
| ٦ | إزاي الكمبيوتر بيخزّن النصوص؟ (ASCII / Unicode / UTF-8) |
| ٧ | الـ Bitwise Operations وسحرها |
| ٨ | Garbage Collection vs Manual Memory |
| ٩ | Process vs Thread |
| ١٠ | إزاي الـ CPU بينفّذ كودك فعلاً؟ |

---

## البوست ١ — Compiler vs Interpreter (و الـ JIT في النص)

> **سؤال بيتسأل في كل interview تقريباً: إيه الفرق بين الـ Compiler و الـ Interpreter؟ خليني أبسّطهولك مرة وللأبد ⚙️**
>
> الكمبيوتر مبيفهمش الكود اللي بتكتبه (C، Python، Java…). بيفهم لغة الآلة بس (٠ و ١). فلازم حاجة تترجم كودك. الترجمة دي بتحصل بطريقتين:
>
> **الـ Compiler (المترجم):**
> بيترجم الكود **كله مرة واحدة** لملف تنفيذي (machine code) قبل ما تشغّله.
> - ✅ سريع جداً وقت التشغيل (الترجمة خلصت قبل كده)
> - ✅ بيكتشف أخطاء كتير قبل التشغيل
> - ❌ لازم تعمل compile كل مرة بعد ما تعدّل
> - أمثلة: **C, C++, Rust, Go**
>
> **الـ Interpreter (المفسّر):**
> بيقرأ ويترجم وينفّذ الكود **سطر بسطر** وقت التشغيل.
> - ✅ مرن، تجرب بسرعة، يشتغل على أي جهاز فيه الـ interpreter
> - ❌ أبطأ (الترجمة بتحصل كل مرة بتشغّل)
> - أمثلة: **Python, Ruby, PHP** (الكلاسيكية)
>
> **والحل الوسط — JIT (Just-In-Time):**
> لغات زي **Java و JavaScript و C#** بتعمل مزيج: بتترجم لصيغة وسطية (bytecode)، وبعدين بتـ compile الأجزاء كتيرة الاستخدام لـ machine code وقت التشغيل = توازن بين السرعة والمرونة.
>
> ```
> Compiler:    كل الكود → machine code → شغّل   (مرة واحدة)
> Interpreter: اقرأ سطر → ترجم → نفّذ → السطر اللي بعده
> JIT:         bytecode → compile الساخن وقت التشغيل
> ```
>
> 💡 مفيش "أحسن" — فيه "أنسب للموقف". الأداء العالي → compiled. السرعة في التطوير → interpreted.
>
> ━━━━━━━━━━━━━━━
> أنهي نوع بتشتغل بيه أكتر؟ 👇
>
> #Programming #ComputerScience #SoftwareEngineering #Coding

**برومبت الصورة:**
```
Create a highly detailed, professional educational infographic for LinkedIn
comparing a Compiler vs an Interpreter vs JIT.

Style: Modern flat tech illustration, dark slate background (#0F172A) with
electric blue (#3B82F6), teal (#14B8A6), amber (#F59E0B) accents. Premium,
clean, well-structured developer poster. High contrast.

Layout: three clearly labeled horizontal lanes stacked vertically.

LANE 1 — "COMPILER": show a stack of source code lines on the left, an arrow
into a big gear/factory icon, then a single output binary file icon (1s and
0s) on the right labeled "machine code", with a caption "translate ALL at
once, then run". Add small tags: "Fast runtime", "C, C++, Rust, Go".

LANE 2 — "INTERPRETER": show source code lines being read one by one, with a
small reading-glass moving line by line, each line turning into execution
immediately. Caption "read & run line by line". Tags: "Flexible", "Python,
Ruby, PHP".

LANE 3 — "JIT (Just-In-Time)": show source -> bytecode (a medium box) ->
a flame icon marking 'hot' parts being compiled to machine code at runtime.
Caption "best of both". Tags: "Java, JavaScript, C#".

Title at top: "How Your Code Becomes Machine Code". Clean sans-serif labels,
monospace for code snippets. White/light-grey text. Keep ALL text short and
correctly spelled. Aspect ratio 1200x627. No watermarks, no gibberish text.
```

---

## البوست ٢ — النظام الثنائي وأنظمة الأرقام

> **الكمبيوتر بيشوف الدنيا كلها أصفار وآحاد. بس إزاي ٠ و ١ بيتحوّلوا لصور وفيديو ونص؟ 🔢**
>
> كل حاجة في جهازك — الكود ده اللي بتقراه دلوقتي — في الآخر عبارة عن bits (أصفار وآحاد). فهم ده أساس كل حاجة بعد كده.
>
> **ليه ثنائي أصلاً؟**
> لإن الترانزستور (وحدة بناء المعالج) ليه حالتين بس: فيه كهرba (1) أو مفيش (0). فأسهل وأضمن نظام للكمبيوتر هو اللي ليه حالتين.
>
> **إزاي بنعدّ بالثنائي؟**
> زي العشري بالظبط بس بـ خانات قوتها ٢ بدل ١٠:
> ```
> Decimal:  13  =  (1×10) + (3×1)
> Binary:  1101 = (1×8) + (1×4) + (0×2) + (1×1) = 13
> ```
>
> **مصطلحات لازم تعرفها:**
> - **Bit** = خانة واحدة (0 أو 1)
> - **Byte** = ٨ bits → بيعبّر عن ٢٥٦ قيمة (0–255)
> - **Hexadecimal (16)** = اختصار مريح للـ binary (كل ٤ bits = خانة hex وحدة) — عشان كده الألوان بتتكتب `#FF5733`
>
> **حاجة هتفيدك فعلاً:**
> لما تشوف `0xFF` ده ٢٥٥، و `255` ده أكبر قيمة في byte واحد. عشان كده الألوان RGB بتوصل لـ 255، وعشان كده المتغيرات ليها حدود (`int8`, `int32`…).
>
> ```dart
> int color = 0xFF5733;   // hex
> print(255 == 0xFF);     // true
> print(0xFF.toRadixString(2)); // "11111111"
> ```
>
> 💡 لما تفهم الـ binary، حاجات كتير بتبقى منطقية: حدود الأرقام، الـ overflow، الألوان، الـ bit flags.
>
> ━━━━━━━━━━━━━━━
> فاكر أول مرة فهمت فيها الـ binary؟ 👇
>
> #Programming #ComputerScience #Binary #Coding #SoftwareEngineering

**برومبت الصورة:**
```
Create a highly detailed, professional educational infographic for LinkedIn
explaining the binary number system.

Style: Modern flat tech illustration, dark slate background (#0F172A) with
electric blue (#3B82F6), teal (#14B8A6), amber (#F59E0B) accents. Premium,
high contrast, clean educational poster.

Center element: a clear place-value breakdown of the binary number 1101.
Draw 4 boxes labeled with powers of two above them: 8, 4, 2, 1. Put the bits
1,1,0,1 inside the boxes. Show the math: (1x8)+(1x4)+(0x2)+(1x1) = 13, with a
big "= 13" result and a small decimal-to-binary bridge.

Around it, add small explainer cards:
- "Bit = 0 or 1" with a single transistor/switch icon (on/off).
- "Byte = 8 bits = 0..255" with a row of 8 small boxes.
- "Hex: #FF5733" showing a color swatch, linking hex to RGB.

Bottom strip: a short visual of a transistor switch (ON=1 / OFF=0) explaining
WHY computers use binary.

Title at top: "Everything is 1s and 0s". Clean sans-serif labels, monospace
for numbers. White/light-grey text. Keep ALL text short and correctly spelled:
Bit, Byte, Hex, 0..255. Aspect ratio 1200x627. No watermarks, no gibberish.
```

---

## البوست ٣ — ليه فيه لغات أسرع من لغات؟

> **ليه C أسرع من Python بمئات المرات؟ مش لأن مطوري Python "وحشين" — السبب أعمق من كده 🏎️**
>
> الفرق في السرعة بيرجع لحاجة أساسية: **قد إيه اللغة قريبة من الآلة، وقد إيه شايلة عنك من شغل.**
>
> **القاعدة العامة:**
> كل ما اللغة تشيل عنك تعقيد (إدارة ذاكرة، أنواع، أمان) = أسهل عليك، بس أبطأ في التنفيذ. مفيش حاجة ببلاش.
>
> **التدرّج (من الأسرع للأبطأ تقريباً):**
> 1. **C / C++ / Rust** → بتترجم لـ machine code مباشرة، تحكم كامل في الذاكرة → الأسرع ⚡
> 2. **Go / Java / C#** → compiled / JIT + garbage collector → سريعة وعملية
> 3. **Python / Ruby / JS** → interpreted، ديناميكية، بتشيل عنك كتير → أبطأ في الحسابات الخام
>
> **ليه Python بطيئة في الحسابات؟**
> - **interpreted** (بتترجم وقت التشغيل)
> - **dynamically typed** (بتتأكد من نوع المتغير وقت التشغيل كل مرة)
> - **garbage collected** + كل قيمة object
>
> **بس استنى — السرعة مش كل حاجة:**
> Python بطيئة في الحساب الخام، لكن مكتباتها (NumPy, TensorFlow) **مكتوبة بـ C تحت**! فبتكتب Python سهل، والشغل التقيل بيتنفّذ بسرعة C. → اختيار الأداة الصح للمكان الصح.
>
> 💡 سرعة اللغة بتفرق في الحسابات الكثيفة. في أغلب التطبيقات، **سرعة التطوير** و**صيانة الكود** أهم من نانوثانية.
>
> ━━━━━━━━━━━━━━━
> بتختار لغة المشروع على أساس إيه — السرعة ولا الإنتاجية؟ 👇
>
> #Programming #SoftwareEngineering #ComputerScience #Coding

**برومبت الصورة:**
```
Create a highly detailed, professional educational infographic for LinkedIn
explaining why some programming languages are faster than others.

Style: Modern flat tech illustration, dark slate background (#0F172A) with
electric blue (#3B82F6), teal (#14B8A6), amber (#F59E0B), and a hint of red
(#EF4444). Premium, high-contrast educational poster.

Main concept: a vertical "spectrum / ladder" or a speedometer-style ranking
from FAST (top) to SLOW (bottom), with three labeled tiers:
- TOP tier "Closest to the metal — Fastest": C, C++, Rust. Icon: a race car
  / lightning bolt. Tag: "compiled, manual memory".
- MIDDLE tier "Balanced": Go, Java, C#. Icon: a balanced scale. Tag:
  "JIT + garbage collector".
- BOTTOM tier "Most abstracted — Slower (raw compute)": Python, Ruby, JS.
  Icon: a comfortable couch. Tag: "interpreted, dynamic types".

Add a key tradeoff arrow on the side: top arrow "More control" pointing up,
bottom arrow "More productivity / safety" pointing down.

Add a small callout: "Python is slow at raw math, but its libraries (NumPy)
are written in C".

Title at top: "Why Some Languages Are Faster". Clean sans-serif labels.
White/light-grey text. Keep ALL text short and correctly spelled. Aspect
ratio 1200x627. No watermarks, no gibberish text.
```

---

## البوست ٤ — رحلة الكود: من Source Code لـ Machine Code

> **بتكتب `print("hello")` وبتضغط Run… بس إيه اللي بيحصل بالظبط بين الضغطة دي وظهور الكلمة؟ 🚀**
>
> الرحلة دي بتمر بمراحل، وفهمها بيخليك تفهم رسايل الأخطاء (compile errors, linker errors) بدل ما تخاف منها.
>
> **مراحل تحويل كود C مثلاً لبرنامج شغّال:**
>
> **1. Preprocessing** — بيتعامل مع الـ `#include` و الـ macros، وبيجهّز ملف نصي نظيف.
>
> **2. Compilation** — بيحوّل الكود لـ **Assembly** (لغة قريبة جداً من الآلة بس لسه مقروءة):
> ```asm
> mov eax, 5
> add eax, 3
> ```
>
> **3. Assembly → Machine Code** — الـ assembler بيحوّل الـ assembly لـ **object file** (٠ و ١ فعلية).
>
> **4. Linking** — بيجمّع كل الـ object files + المكتبات مع بعض في ملف تنفيذي واحد (`.exe`). هنا بيظهر "linker error" لو في function مكتوبة بس مش متعرّفة.
>
> ```
> source.c → [preprocess] → [compile] → assembly →
>            [assemble] → object file → [link] → executable
> ```
>
> **ليه ده يفيدك عملياً؟**
> - **Syntax/Compile error** → غلط في الكود نفسه (مرحلة ٢).
> - **Linker error** ("undefined reference") → الكود مظبوط، بس فيه حاجة مش متوصّلة (مرحلة ٤).
> فهم ده بيوفر عليك ساعات في تصيّد الأخطاء.
>
> 💡 اللغات الـ interpreted بتختصر الرحلة دي وقت التشغيل، بس المبدأ موجود تحت في كل مكان.
>
> ━━━━━━━━━━━━━━━
> أنهي مرحلة كانت بتلخبطك قبل كده؟ 👇
>
> #Programming #ComputerScience #SoftwareEngineering #Compiler

**برومبت الصورة:**
```
Create a highly detailed, professional educational infographic for LinkedIn
showing the journey from source code to an executable program (the
compilation pipeline).

Style: Modern flat tech illustration, dark slate background (#0F172A) with
electric blue (#3B82F6), teal (#14B8A6), amber (#F59E0B) accents. Premium,
clean, like a polished pipeline diagram. High contrast.

Main element: a horizontal PIPELINE with 4-5 connected stages, each a labeled
node with an icon and an arrow to the next:
1. "Source Code" — a document icon with code lines (.c file).
2. "Preprocessor" — a filter/funnel icon (handles #include, macros).
3. "Compiler" — a gear icon, output shown as a small assembly snippet box
   (mov, add).
4. "Assembler" — output an "object file" icon (1s and 0s).
5. "Linker" — combine multiple object files + a library icon into one final
   "Executable (.exe)" icon at the end.

Below the pipeline, add two small error callouts pointing to the right stages:
- "Compile error -> your code" pointing at the Compiler stage.
- "Linker error: undefined reference" pointing at the Linker stage.

Title at top: "From Code to Machine". Clean sans-serif labels, monospace for
the assembly snippet. White/light-grey text. Keep ALL text short and
correctly spelled: Source Code, Preprocessor, Compiler, Assembler, Linker,
Executable. Aspect ratio 1200x627. No watermarks, no gibberish text.
```

---

## البوست ٥ — Static vs Dynamic Typing

> **ليه بتكتب `int x = 5` في Java، وفي Python بتكتب `x = 5` على طول؟ الفرق ده بيأثر على كل سطر بتكتبه ✍️**
>
> ده الفرق بين **Static Typing** و **Dynamic Typing** — والموضوع مش مجرد "كتابة أكتر ولا أقل".
>
> **Static Typing (أنواع ثابتة):**
> نوع المتغير بيتحدد **وقت الكتابة/الـ compile** ومبيتغيرش.
> - ✅ بيمسك أخطاء كتير **قبل** ما البرنامج يشتغل
> - ✅ الـ IDE بيساعدك أحسن (autocomplete دقيق)
> - ✅ أسرع في التنفيذ (النوع معروف)
> - ❌ كتابة أكتر شوية
> - أمثلة: **Java, C++, Dart, TypeScript, Rust**
>
> **Dynamic Typing (أنواع ديناميكية):**
> النوع بيتحدد **وقت التشغيل**، وممكن يتغير.
> - ✅ كتابة أسرع، مرونة عالية، نماذج أولية بسرعة
> - ❌ أخطاء النوع بتظهر **وقت التشغيل** (يمكن قدام المستخدم 😬)
> - أمثلة: **Python, JavaScript, Ruby**
>
> ```dart
> // Static (Dart): الغلط ده بيتمسك قبل التشغيل
> int x = 5;
> x = "hello";  // ❌ Compile error
>
> // Dynamic (Python): بيعدّي عادي، والمشكلة وقت التشغيل
> x = 5
> x = "hello"   # ✅ مفيش مشكلة... لحد ما تستخدمه غلط
> ```
>
> **حاجة مهمة:** الاتجاه العام في الصناعة بيميل للـ static (عشان كده ظهر TypeScript فوق JavaScript، و type hints في Python) — لإن مسك الأخطاء بدري بيوفر فلوس ووقت.
>
> 💡 ملحوظة: ده غير "strong vs weak typing" — موضوع تاني خالص (هنشرحه قدام).
>
> ━━━━━━━━━━━━━━━
> static ولا dynamic؟ وليه؟ 👇
>
> #Programming #SoftwareEngineering #TypeSystems #Coding

**برومبت الصورة:**
```
Create a highly detailed, professional educational infographic for LinkedIn
comparing Static Typing vs Dynamic Typing.

Style: Modern flat tech illustration, dark slate background (#0F172A) with
electric blue (#3B82F6), teal (#14B8A6), green (#22C55E) and red (#EF4444)
accents. Premium, structured, high contrast.

Split into two clearly labeled panels side by side.

LEFT PANEL — "STATIC TYPING":
- A code snippet box: "int x = 5;" then "x = \"hello\"" crossed out with a red
  X and a shield icon labeled "caught at compile time".
- Tags with check icons: "Errors caught early", "Better autocomplete",
  "Faster execution".
- Footer: "Java, C++, Dart, TypeScript, Rust".

RIGHT PANEL — "DYNAMIC TYPING":
- A code snippet box: "x = 5" then "x = 'hello'" both allowed with a green
  check, but a small red warning bug icon labeled "fails at runtime".
- Tags: "Faster to write", "Flexible", "Quick prototyping".
- Footer: "Python, JavaScript, Ruby".

Center divider with a small label: "When is the type decided?" and two arrows:
"compile time" (left) vs "runtime" (right).

Title at top: "Static vs Dynamic Typing". Clean sans-serif, monospace for
code. White/light-grey text. Keep ALL text short and correctly spelled.
Aspect ratio 1200x627. No watermarks, no gibberish text.
```

---

## البوست ٦ — إزاي الكمبيوتر بيخزّن النصوص؟ (ASCII / Unicode / UTF-8)

> **الكمبيوتر بيفهم أرقام بس. فإزاي بيخزّن حرف "A" أو "م" أو حتى 😀؟ القصة دي بتفسّر مشاكل الترميز اللي قابلتك أكيد 🔤**
>
> أكيد شفت نص عربي طلع رموز غريبة (Ù…Ø±) — ده اسمه mojibake، وسببه سوء فهم الترميز.
>
> **البداية — ASCII:**
> جدول بسيط بيربط كل حرف برقم: `A = 65`, `a = 97`, `0 = 48`. بـ ٧ bits = ١٢٨ رمز بس → كفى الإنجليزية وخلاص. مفيش عربي، مفيش emoji.
>
> **المشكلة:** العالم فيه آلاف الحروف (عربي، صيني، رموز…). ١٢٨ خانة مش كفاية أبداً.
>
> **الحل — Unicode:**
> معيار بيدّي **رقم فريد (code point)** لكل حرف في كل لغات الدنيا + الإيموجي. مثلاً "م" = U+0645، و 😀 = U+1F600.
>
> **بس إزاي نخزّن الأرقام الكبيرة دي بكفاءة؟ → UTF-8:**
> طريقة ترميز ذكية: الحروف الشائعة (إنجليزي) بتاخد **byte واحد** (متوافق مع ASCII!)، والحروف الأعقد بتاخد ٢–٤ bytes حسب الحاجة. → توفير مساحة + دعم كل اللغات.
>
> ```dart
> print('A'.codeUnitAt(0));   // 65  (ASCII)
> print('م'.runes.first);     // 1605 (Unicode)
> print('😀'.runes.first);    // 128512
> ```
>
> **ليه ده يفيدك؟**
> أغلب مشاكل "النص الظاهر غلط" سببها إن الملف/الـ API محفوظ بترميز وانت بتقراه بترميز تاني. **استخدم UTF-8 في كل مكان** وهتريّح نفسك.
>
> 💡 طول النص (length) مش دايماً = عدد الـ bytes. الإيموجي الواحد ممكن ياخد ٤ bytes!
>
> ━━━━━━━━━━━━━━━
> اتعقّدت قبل كده من مشكلة ترميز؟ احكيلنا 👇
>
> #Programming #ComputerScience #Unicode #SoftwareEngineering

**برومبت الصورة:**
```
Create a highly detailed, professional educational infographic for LinkedIn
explaining how computers store text: ASCII vs Unicode vs UTF-8.

Style: Modern flat tech illustration, dark slate background (#0F172A) with
electric blue (#3B82F6), teal (#14B8A6), amber (#F59E0B) accents. Premium,
clean, high contrast.

Layout as a progression (left to right or top to bottom), 3 stages:

1. "ASCII": a small table mapping characters to numbers: A=65, a=97, 0=48.
   Note "7 bits = 128 symbols, English only". Icon: a simple grid.
2. "UNICODE": show diverse characters each with a code point: "A = U+0041",
   Arabic letter "م = U+0645", and an emoji "😀 = U+1F600". Note "a unique
   number for every character in every language". Icon: a globe.
3. "UTF-8": show variable-length encoding — "A" using 1 byte (one small box),
   "م" using 2 bytes (two boxes), "😀" using 4 bytes (four boxes). Note
   "efficient: 1-4 bytes, ASCII-compatible".

Add a small 'before' warning card showing garbled text "Ù…Ø±" labeled
"wrong encoding = mojibake".

Title at top: "How Computers Store Text". Clean sans-serif labels, monospace
for code points. White/light-grey text. Keep ALL text short and correctly
spelled: ASCII, Unicode, UTF-8, byte. Aspect ratio 1200x627. No watermarks,
minimal text, no gibberish (except the intentional 'mojibake' example).
```

---

## البوست ٧ — الـ Bitwise Operations وسحرها

> **فيه عمليات في كل لغة برمجة، أسرع من أي حاجة تانية، ومعظم المبرمجين مبيستخدموهاش: الـ Bitwise Operations ⚡**
>
> دي عمليات بتشتغل على الـ bits مباشرة، فالمعالج بينفّذها في **دورة واحدة** تقريباً — أسرع من الضرب والقسمة العادية.
>
> **العمليات الأساسية:**
> ```
> &  (AND)  →  1 لو الاتنين 1
> |  (OR)   →  1 لو أي واحد 1
> ^  (XOR)  →  1 لو مختلفين
> ~  (NOT)  →  بيقلب الـ bits
> << >>     →  إزاحة لليمين/الشمال
> ```
>
> **حِيَل عملية بتستخدمها فعلاً:**
>
> **1. ضرب وقسمة على ٢ بسرعة الصاروخ:**
> ```dart
> x << 1   // = x * 2
> x >> 1   // = x ~/ 2
> ```
>
> **2. تعرف الرقم زوجي ولا فردي:**
> ```dart
> if (x & 1 == 0) // زوجي
> ```
>
> **3. الـ Bit Flags — تخزين كذا إعداد in متغير واحد:**
> ```dart
> const read = 1;    // 001
> const write = 2;   // 010
> const exec = 4;    // 100
> int perms = read | write;   // 011 → عنده read + write
> bool canWrite = perms & write != 0; // true
> ```
> ده بالظبط إزاي صلاحيات الملفات في Linux شغالة (chmod 755)!
>
> 💡 مش هتستخدمها كل يوم، بس فهمها بيفتحلك باب: الصلاحيات، الضغط، التشفير، والـ graphics كلها قايمة عليها.
>
> ━━━━━━━━━━━━━━━
> استخدمت bitwise في كود حقيقي قبل كده؟ فين؟ 👇
>
> #Programming #ComputerScience #SoftwareEngineering #Coding

**برومبت الصورة:**
```
Create a highly detailed, professional educational infographic for LinkedIn
explaining bitwise operations.

Style: Modern flat tech illustration, dark slate background (#0F172A) with
electric blue (#3B82F6), teal (#14B8A6), amber (#F59E0B) accents. Premium,
clean, high contrast.

Top section — a truth-table-style visual of the core operators, each with two
input bit rows and a result row shown as small 0/1 boxes:
- AND (&), OR (|), XOR (^), NOT (~), and shift (<< >>) with arrows showing
  bits sliding left/right.

Bottom section — two practical example cards:
1. "Fast x2 / ÷2": show "1010 << 1 = 10100" with a lightning bolt.
2. "Bit Flags": show three permission bits read=001, write=010, exec=100, and
   combining read|write = 011, with small lock/file icons (link to Linux
   chmod).

Use glowing 0/1 boxes to make the bit manipulation visually clear.

Title at top: "The Power of Bitwise". Clean sans-serif labels, monospace for
binary. White/light-grey text. Keep ALL text short and correctly spelled:
AND, OR, XOR, NOT, shift, flags. Aspect ratio 1200x627. No watermarks, no
gibberish text.
```

---

## البوست ٨ — Garbage Collection vs Manual Memory

> **في C لازم تنضّف الذاكرة بإيدك. في Java و Dart و Python فيه حد بيعملها عنك. مين الأحسن؟ السؤال غلط 🧹**
>
> كل برنامج بيحجز ذاكرة (memory) عشان يشتغل. السؤال: مين المسؤول إنه يفضّيها لما تخلص؟
>
> **Manual Memory Management (يدوي):**
> انت بتحجز وانت بتفضّي بإيدك. (C, C++)
> ```c
> int* p = malloc(sizeof(int)); // احجز
> free(p);                       // فضّي بإيدك
> ```
> - ✅ تحكم كامل + أداء أعلى + متوقّع (مفيش توقفات)
> - ❌ نسيت `free`؟ → **Memory Leak**. فضّيت بدري واستخدمت؟ → **crash / security bug**
>
> **Garbage Collection (تلقائي):**
> الـ runtime بيراقب أي object مفيش حد بيستخدمه، وبيفضّيه تلقائياً. (Java, Dart, Python, Go)
> - ✅ أمان، أخطاء ذاكرة أقل بكتير، تطوير أسرع
> - ❌ بياخد CPU، وممكن يعمل **توقفات بسيطة** (GC pauses) في لحظة مش متوقعة
>
> **الطريق التالت — Ownership (Rust):**
> Rust عملت حاجة عبقرية: الـ **compiler** بيتأكد من إدارة الذاكرة **وقت الـ compile** — أمان من غير garbage collector ومن غير توقفات. (منحنى تعلّم أعلى مقابل ده).
>
> ```
> Manual (C)      → انت المسؤول   → أسرع، أخطر
> GC (Java/Dart)  → الـ runtime    → أأمن، توقفات أحياناً
> Ownership(Rust) → الـ compiler   → آمن وسريع، صعب أكتر
> ```
>
> 💡 لو شغال بـ Dart/Flutter: الـ GC هو سبب إنك مبتكتبش `free`، وكمان سبب إن تقليل إنشاء الـ objects الزيادة بيحسّن الأداء.
>
> ━━━━━━━━━━━━━━━
> اشتغلت بإدارة ذاكرة يدوية قبل كده؟ إزاي كانت التجربة؟ 👇
>
> #Programming #ComputerScience #MemoryManagement #SoftwareEngineering

**برومبت الصورة:**
```
Create a highly detailed, professional educational infographic for LinkedIn
comparing memory management approaches: Manual vs Garbage Collection vs
Ownership.

Style: Modern flat tech illustration, dark slate background (#0F172A) with
electric blue (#3B82F6), teal (#14B8A6), amber (#F59E0B), red (#EF4444)
accents. Premium, structured, high contrast.

Three labeled columns:

1. "MANUAL (C, C++)": a developer character with a broom manually cleaning
   memory blocks. Code snippet "malloc() ... free()". Tags: green "full
   control / fast", red "leaks & crashes if you forget".

2. "GARBAGE COLLECTION (Java, Dart, Python)": an automated robot vacuum
   roaming among memory blocks, collecting unused ones (greyed/marked).
   Tags: green "safe / automatic", amber "GC pauses".

3. "OWNERSHIP (Rust)": a shield/compiler icon checking memory at compile time
   with a checkmark. Tags: green "safe AND fast", amber "steeper learning".

Title at top: "Who Cleans Up the Memory?". Clean sans-serif labels, monospace
for code. White/light-grey text. Keep ALL text short and correctly spelled:
Manual, Garbage Collection, Ownership, malloc, free. Aspect ratio 1200x627.
No watermarks, no gibberish text.
```

---

## البوست ٩ — Process vs Thread

> **بتفتح Chrome، فبيشتغل كـ Process. وكل تاب جواه بيشتغل كـ Thread. إيه الفرق بالظبط؟ 🧵**
>
> الفرق ده أساس فهم الأداء والـ multitasking وحتى ليه بعض البرامج بتـ crash تاب واحد من غير ما الباقي يقع.
>
> **الـ Process (العملية):**
> برنامج شغّال له **ذاكرته المستقلة تماماً**.
> - معزول: لو وقع، مبيأثرش على باقي الـ processes
> - تقيل في الإنشاء، والتواصل بينه وبين غيره مكلف (IPC)
> - مثال: كل تطبيق مفتوح على جهازك = process (أو أكتر)
>
> **الـ Thread (الخيط):**
> وحدة تنفيذ **جوه** الـ process، بتشارك نفس الذاكرة مع باقي الـ threads.
> - خفيف وسريع الإنشاء
> - التواصل بينهم سهل (نفس الذاكرة)
> - ❌ بس المشاركة دي خطر: لو اتنين عدّلوا نفس البيانات في نفس الوقت → **Race Condition**
>
> ```
> Process  =  بيت مستقل (مطبخ + حمام خاص)
> Thread   =  أوضة جوه نفس البيت (بتشارك المطبخ مع الباقي)
> ```
>
> **ليه ده مهم للمبرمج؟**
> - عايز عزل وأمان (تاب يقع لوحده)؟ → Processes
> - عايز سرعة وتشارك بيانات؟ → Threads (بس اتعامل مع الـ synchronization بحرص)
> - الـ Race Conditions و الـ Deadlocks كلها بتيجي من سوء إدارة الـ threads المشتركة.
>
> 💡 في Dart الموضوع مختلف بذكاء: الـ **Isolates** زي threads بس **مش بتشارك ذاكرة** → بتتجنب الـ race conditions من الأساس.
>
> ━━━━━━━━━━━━━━━
> اصطادك race condition قبل كده؟ احكيلنا القصة 👇
>
> #Programming #ComputerScience #Concurrency #SoftwareEngineering

**برومبت الصورة:**
```
Create a highly detailed, professional educational infographic for LinkedIn
comparing a Process vs a Thread.

Style: Modern flat tech illustration, dark slate background (#0F172A) with
electric blue (#3B82F6), teal (#14B8A6), amber (#F59E0B), red (#EF4444)
accents. Premium, structured, high contrast.

Use a clear "house" analogy as the central visual:
- "PROCESS" = a self-contained house with its own private memory (its own
  kitchen/utilities), drawn isolated from other houses. Label "isolated own
  memory", "heavy", "crash-safe".
- "THREAD" = multiple rooms INSIDE one house sharing the same kitchen
  (shared memory). Show 3 small worker icons in separate rooms but connected
  to one shared memory block in the middle. Label "shared memory",
  "lightweight", and a red warning "race conditions".

Add a small side note card: "Dart Isolates = threads that DON'T share memory".

Title at top: "Process vs Thread". Clean sans-serif labels. White/light-grey
text. Keep ALL text short and correctly spelled: Process, Thread, shared
memory, race condition. Aspect ratio 1200x627. No watermarks, no gibberish.
```

---

## البوست ١٠ — إزاي الـ CPU بينفّذ كودك فعلاً؟

> **كل سطر كود بتكتبه بيتحوّل في الآخر لتعليمات بسيطة جداً بينفّذها الـ CPU بالمليارات في الثانية. بس إزاي؟ 🧠**
>
> الـ CPU، مهما كان قوي، بيعمل حاجة واحدة بسيطة بشكل متكرر: دورة اسمها **Fetch–Decode–Execute**.
>
> **الدورة (بتتكرر مليارات المرات/الثانية):**
> 1. **Fetch** — يجيب التعليمة الجاية من الذاكرة (RAM)
> 2. **Decode** — يفهم التعليمة دي معناها إيه (اجمع؟ خزّن؟ قارن؟)
> 3. **Execute** — ينفّذها
> 4. يكرر ➰
>
> **مكوّنات لازم تعرفها:**
> - **Registers** — ذاكرة صغيرة جداً وسريعة جداً **جوه** الـ CPU (أسرع حاجة على الإطلاق)
> - **Cache (L1/L2/L3)** — ذاكرة وسيطة سريعة بتخزّن البيانات المتكررة
> - **RAM** — أكبر بكتير بس أبطأ من الـ cache
>
> **معلومة هتغيّر طريقة تفكيرك في الأداء — هرم السرعة:**
> ```
> Register  →  ~أسرع ١٠٠٠ مرة من RAM
> L1 Cache  →  سريع جداً
> RAM       →  أبطأ بكتير
> Disk/SSD  →  أبطأ بمراحل
> ```
> الفرق بين register و RAM رهيب! عشان كده **cache locality** (إنك توصل لبيانات قريبة من بعض) بتفرق في الأداء أكتر من تقليل عدد العمليات نفسه أحياناً.
>
> **ليه ده يفيدك؟**
> لما تمشي على array بالترتيب، الـ CPU بيتوقّع ويجيب البيانات الجاية للـ cache مقدماً (prefetching) → أسرع بكتير من القفز العشوائي في الذاكرة. ده اللي بيخلّي الـ arrays أسرع من الـ linked lists في الواقع رغم نفس الـ Big O.
>
> 💡 الكود السريع مش بس "خوارزمية أحسن" — كمان "ودود للذاكرة" (cache-friendly).
>
> ━━━━━━━━━━━━━━━
> أول مرة تسمع عن الـ Fetch-Decode-Execute؟ 👇
>
> #Programming #ComputerScience #CPU #SoftwareEngineering #Performance

**برومبت الصورة:**
```
Create a highly detailed, professional educational infographic for LinkedIn
explaining how a CPU executes code (the Fetch-Decode-Execute cycle) and the
memory speed hierarchy.

Style: Modern flat tech illustration, dark slate background (#0F172A) with
electric blue (#3B82F6), teal (#14B8A6), amber (#F59E0B) accents. Premium,
clean, high contrast.

LEFT side — the cycle: a circular loop diagram with 3 labeled stages and
arrows forming a cycle: "FETCH" (an arrow pulling an instruction from memory),
"DECODE" (a gear interpreting it), "EXECUTE" (a lightning bolt running it).
Center of the circle: a CPU chip icon. Caption: "billions of times per
second".

RIGHT side — the memory speed pyramid (a triangle), from top (smallest +
fastest) to bottom (largest + slowest):
- Top: "Registers (fastest)"
- "L1 / L2 / L3 Cache"
- "RAM"
- Bottom: "Disk / SSD (slowest)"
Add a vertical arrow on the side: top "Faster + Smaller", bottom "Slower +
Bigger".

Add a small callout: "Cache locality makes arrays faster than linked lists".

Title at top: "How the CPU Runs Your Code". Clean sans-serif labels.
White/light-grey text. Keep ALL text short and correctly spelled: Fetch,
Decode, Execute, Registers, Cache, RAM, Disk. Aspect ratio 1200x627. No
watermarks, no gibberish text.
```

---

## نصائح للنشر (تنطبق على السلسلة كلها)

- **التوقيت:** المحتوى التقني بيشتغل كويس الصبح (٨–١٠) أو بعد الضهر (٤–٦) بتوقيت جمهورك.
- **أول سطر = البطل:** الـ hook هو اللي بيوقف الـ scroll. كل البوستات هنا بتبدأ بسؤال أو معلومة صادمة.
- **نص الصورة:** لو Gemini كتب أي مصطلح غلط، قوله: "Fix the text, use only these exact words: …" أو سيب النص فاضي وضيفه في Canva.
- **التناسق البصري:** كل البرومبتات بنفس الألوان (`#0F172A` + أزرق/تركواز/أمبر) → السلسلة هتبان موحّدة واحترافية على بروفايلك.
- **التفاعل:** رد على أول كومنتات في أول ساعة — بيرفع الـ reach بشكل كبير.
- **carousel فكرة:** بعض المواضيع دي (زي رحلة الكود، أو هرم الذاكرة) ممكن تعملها carousel (كذا صورة) لو حابب تفاعل أعلى.
