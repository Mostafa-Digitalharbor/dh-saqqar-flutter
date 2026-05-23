# Privacy Policy — Saqqar Mobile

> **Hand-off note for legal review:** This is a working draft that
> mirrors what the app actually does today (verified against the
> codebase). Have legal counsel review before posting publicly. Host
> the approved version at `https://digitalharbor.com.sa/privacy-saqqar`
> (or a comparable URL on the company domain).

**Effective date:** [date]
**Operated by:** Digital Harbor (digitalharbor.com.sa)
**Contact:** support@digitalharbor.com.sa

---

## 1. What this policy covers

This policy describes what data the **Saqqar** mobile app collects,
how we use it, who we share it with, and how long we keep it. It
applies only to the Saqqar mobile app on Android and iOS.

By using Saqqar, you agree to the practices described here. If you
do not agree, do not use the app.

---

## 2. Information we collect

### 2.1 Account information

To use Saqqar you create an account on the Saqqar platform
(saqqaar.com). We collect:

- **Email address** — used as your login identifier
- **Password** — stored securely as a one-way hash; we never see your
  plaintext password
- **Display name** (optional) — shown in the app and to your team
  members

### 2.2 Conversation content

Saqqar is a chat-based interface to Odoo. The messages you send and
the agent's replies are stored on the Saqqar backend
(saqqaar.com) so you can resume conversations across devices. We
keep:

- **Your messages** — text you type into the chat composer
- **Agent replies** — including tool calls (which Odoo records were
  read, which reports were generated)
- **Attachments** — files you upload via the attachment button
  (PDFs, spreadsheets, images)
- **Generated artifacts** — Excel / PDF / Word files produced by the
  agent

### 2.3 Odoo credentials you supply

To let the agent query your Odoo instance, you provide credentials
(URL, database, username, password, or SSH key) per environment.
These credentials:

- Are **encrypted at rest** on the Saqqar backend
- Are decrypted only at the moment a tool call needs them, then
  discarded from memory
- Are **never logged**, never sent to Sentry, and never displayed in
  the UI after entry
- Are stored on-device only in the OS-provided secure storage
  (Android Keystore / iOS Keychain)

### 2.4 Diagnostic information (crash reports)

When the app crashes or hits an unexpected error, we send anonymized
diagnostic data to **Sentry** (sentry.io), our error monitoring
provider, including:

- The error message and stack trace
- The screen / feature where it happened (e.g. "ChatScreen.send")
- The app version and Android / iOS version
- A coarse device model (e.g. "Pixel 7" — never a device fingerprint)

We **do not** send: your IP address, your email, your conversation
contents, your Odoo credentials, or any data that could personally
identify you to Sentry.

### 2.5 Connectivity state

The app reads whether the device is online or offline, to show the
offline banner. This stays on-device — we don't transmit it.

### 2.6 What we DO NOT collect

- Your location (GPS or otherwise)
- Your contacts list
- Your photo gallery (we only see images you explicitly attach)
- Your SMS or call history
- Browsing history outside the app
- Advertising identifiers

---

## 3. How we use your information

| Purpose | Data used |
|---|---|
| Authenticate you to the backend | Email, password hash |
| Connect to your Odoo instance | Odoo credentials |
| Show your conversation history across devices | Messages, attachments, artifacts |
| Diagnose crashes and fix bugs | Sentry diagnostic data |
| Send you product communication (only if you opt in) | Email |

We never sell your data. We never use your conversation content for
advertising or to train any AI model. We never share your data with
third parties for marketing.

---

## 4. Sharing with third parties

We share data only with the service providers we need to run the
product:

| Provider | What we share | Why |
|---|---|---|
| **Sentry** (Germany / EU, GDPR-aligned) | Crash diagnostic data only — never PII | App stability monitoring |
| **Cloud hosting provider** | Encrypted account + conversation data | Running the saqqaar.com backend |

> Sentry processes our crash reports in the European Union
> (Frankfurt). The data we send is limited to anonymized stack
> traces, screen names, app version, and coarse device model — see
> §2.4 for the exact list. Sentry's privacy policy:
> https://sentry.io/privacy/

We do not share with marketing networks, analytics aggregators, or
advertising platforms.

If the law requires (court order, government subpoena), we may share
data with authorities. We will notify you unless prohibited.

---

## 5. Data retention

| Data | Retained for |
|---|---|
| Account (email, password) | Until you delete your account |
| Conversation messages and attachments | Until you delete the conversation, or you delete your account |
| Odoo credentials | Until you remove them from the vault, or you delete your account |
| Sentry crash reports | 30 days, then automatically purged |

When you delete your account, all of the above is permanently removed
from our database within 30 days. Encrypted backups age out within 90
days.

---

## 6. Your rights

You can, at any time:

- **Access** your data — email `support@digitalharbor.com.sa` for an
  export
- **Correct** your account information — directly in the Account
  screen
- **Delete** your data — delete individual conversations / credentials
  from the app, or email `support@digitalharbor.com.sa` to delete the
  entire account
- **Export** your conversation history — email
  `support@digitalharbor.com.sa`
- **Withdraw consent** — by deleting the app and emailing
  `support@digitalharbor.com.sa` to delete the server-side data

We respond to data requests within **30 days**.

---

## 7. Security

We protect your data with industry-standard practices:

- **Encryption in transit** — TLS 1.2+ on all API calls
- **Encryption at rest** — Odoo credentials encrypted server-side;
  on-device credentials in Android Keystore / iOS Keychain
- **Authentication** — bearer tokens revocable per device; sign-out
  invalidates the token immediately
- **Approval gating** — destructive actions (writes, deletes) require
  your explicit in-app approval before they touch your live Odoo

No system is 100% secure. If we discover a breach affecting your
account, we will notify you within 72 hours.

---

## 8. Children

Saqqar is a business productivity tool intended for users **18 years
and older**. We do not knowingly collect data from anyone under 18.
If you believe a minor has created an account, email
`support@digitalharbor.com.sa` and we will delete it.

---

## 9. International transfers

Saqqar is operated from Saudi Arabia. Our cloud infrastructure is
hosted in [region — specify before publishing]. If you use the app
from outside Saudi Arabia, you consent to your data being processed
in our hosting region.

---

## 10. Changes to this policy

We may update this policy. We'll notify you in the app (or via
email) at least 14 days before any material change takes effect. The
"Effective date" at the top reflects the current version.

---

## 11. Contact

For any privacy question, data request, or complaint:

**Digital Harbor**
Email: support@digitalharbor.com.sa
Website: https://digitalharbor.com.sa
Address: [company address — fill before publishing]

---

# سياسة الخصوصية — صقار للموبايل

> **ملاحظة للمراجعة القانونية:** هذه مسودة عمل تعكس ما يفعله التطبيق
> فعلياً (تم التحقق من الكود). يُرجى مراجعتها قانونياً قبل النشر.
> الإصدار المُعتمد يُنشر على:
> `https://digitalharbor.com.sa/privacy-saqqar`

**تاريخ السريان:** [التاريخ]
**المُشغِّل:** Digital Harbor (digitalharbor.com.sa)
**التواصل:** support@digitalharbor.com.sa

---

## ١. نطاق هذه السياسة

تصف هذه السياسة البيانات التي يجمعها تطبيق **صقار** للموبايل،
وكيفية استخدامها، ومع من نشاركها، ومدة الاحتفاظ بها. تنطبق فقط على
تطبيق صقار على Android و iOS.

باستخدامك التطبيق، فأنت توافق على هذه الممارسات. إذا لم توافق، لا
تستخدم التطبيق.

---

## ٢. المعلومات التي نجمعها

### ٢.١ معلومات الحساب

لاستخدام صقار، تنشئ حساباً على منصة صقار (saqqaar.com). نجمع:

- **عنوان البريد الإلكتروني** — يُستخدم كمُعرّف لتسجيل الدخول
- **كلمة المرور** — تُخزَّن بشكل آمن كـhash أحادي الاتجاه؛ نحن لا
  نرى كلمتك السرية الفعلية
- **اسم العرض** (اختياري) — يُعرض في التطبيق ولأعضاء فريقك

### ٢.٢ محتوى المحادثات

صقار واجهة محادثة لـOdoo. الرسائل التي ترسلها وردود الوكيل تُحفظ
على خادم صقار (saqqaar.com) لتتمكن من استئناف المحادثات عبر الأجهزة.
نحفظ:

- **رسائلك** — النصوص التي تكتبها
- **ردود الوكيل** — بما فيها استدعاءات الأدوات (أي سجلات Odoo
  قُرئت، أي تقارير تم إنشاؤها)
- **المرفقات** — الملفات التي ترفعها (PDF، جداول، صور)
- **المخرجات** — ملفات Excel / PDF / Word التي أنشأها الوكيل

### ٢.٣ بيانات اعتماد Odoo التي تقدمها

ليتمكن الوكيل من الاستعلام من نظام Odoo الخاص بك، تقدم بيانات
اعتماد (URL، قاعدة بيانات، مستخدم، كلمة مرور، أو مفتاح SSH) لكل
بيئة. هذه البيانات:

- **مُشفَّرة أثناء التخزين** على خادم صقار
- تُفكّ تشفيرها فقط لحظة استخدامها، ثم تُمسح من الذاكرة
- **لا تُسجَّل أبداً** ولا تُرسَل إلى Sentry ولا تُعرض في الواجهة
  بعد الإدخال
- تُخزَّن على الجهاز فقط داخل التخزين الآمن من نظام التشغيل (Android
  Keystore / iOS Keychain)

### ٢.٤ معلومات التشخيص (تقارير الأعطال)

عند تعطل التطبيق أو حدوث خطأ غير متوقع، نرسل بيانات تشخيصية
مجهولة إلى **Sentry** (sentry.io)، مزوّد مراقبة الأخطاء لدينا، تشمل:

- رسالة الخطأ ومسار التتبع
- الشاشة / الميزة التي حدث فيها (مثل "ChatScreen.send")
- إصدار التطبيق وإصدار Android / iOS
- موديل الجهاز التقريبي (مثل "Pixel 7" — وليس بصمة جهاز)

**لا نرسل**: عنوان IP الخاص بك، بريدك الإلكتروني، محتوى محادثاتك،
بيانات Odoo، أو أي بيانات تعرّفك شخصياً لـSentry.

### ٢.٥ حالة الاتصال

يقرأ التطبيق ما إذا كان الجهاز متصلاً بالإنترنت لإظهار شارة عدم
الاتصال. تبقى هذه المعلومة على الجهاز فقط.

### ٢.٦ ما لا نجمعه

- موقعك (GPS أو غيره)
- قائمة جهات اتصالك
- مكتبة الصور (نرى فقط الصور التي ترفعها صراحةً)
- سجل الرسائل النصية أو المكالمات
- سجل التصفح خارج التطبيق
- مُعرِّفات الإعلانات

---

## ٣. كيف نستخدم معلوماتك

نستخدم البيانات فقط لتشغيل المنتج: تسجيل دخولك، الاتصال بنظام Odoo
الخاص بك، عرض محادثاتك عبر الأجهزة، وتشخيص الأعطال. لا نبيع بياناتك
أبداً. لا نستخدم محتوى محادثاتك للإعلانات أو لتدريب أي نموذج ذكاء
اصطناعي. لا نشاركها مع أطراف ثالثة لأغراض تسويقية.

---

## ٤. المشاركة مع أطراف ثالثة

نشارك البيانات فقط مع مزودي الخدمات الضروريين:

- **Sentry** (ألمانيا، الاتحاد الأوروبي، متوافق مع GDPR) — بيانات
  تشخيص الأعطال فقط، بدون أي بيانات شخصية. تُعالَج تقارير الأعطال
  في مركز بيانات فرانكفورت. سياسة Sentry: https://sentry.io/privacy/
- **مزود الاستضافة السحابية** — بيانات الحساب والمحادثات المُشفَّرة

لا نشارك مع شبكات الإعلانات أو منصات التحليلات.

---

## ٥. مدة الاحتفاظ بالبيانات

- الحساب: حتى تحذف حسابك
- المحادثات والمرفقات: حتى تحذفها يدوياً أو تحذف حسابك
- بيانات Odoo: حتى تزيلها من الخزنة أو تحذف حسابك
- تقارير Sentry: 30 يوماً، ثم تُحذف تلقائياً

عند حذف حسابك، تُمحى كل البيانات نهائياً خلال 30 يوماً.

---

## ٦. حقوقك

يمكنك في أي وقت:

- **الاطلاع** على بياناتك — راسلنا على
  `support@digitalharbor.com.sa`
- **التصحيح** — مباشرة من شاشة الحساب
- **الحذف** — من داخل التطبيق أو بمراسلتنا
- **التصدير** — راسلنا
- **سحب الموافقة** — احذف التطبيق وراسلنا لحذف بياناتك من الخادم

نستجيب لطلبات البيانات خلال **30 يوماً**.

---

## ٧. الأمان

- **تشفير أثناء النقل** — TLS 1.2+ في كل اتصالات الـAPI
- **تشفير أثناء التخزين** — بيانات Odoo مُشفَّرة على الخادم
- **مصادقة** — رموز bearer قابلة للإلغاء لكل جهاز؛ تسجيل الخروج
  يُلغي الرمز فوراً
- **حماية الإجراءات** — أي إجراء حذف أو تعديل يحتاج موافقتك الصريحة
  قبل تطبيقه على Odoo الخاص بك

في حال اكتشاف اختراق يؤثر على حسابك، سنبلغك خلال 72 ساعة.

---

## ٨. الأطفال

صقار أداة إنتاجية للأعمال موجّهة للمستخدمين **١٨ سنة فأكبر**. لا
نجمع بيانات قاصرين عن قصد.

---

## ٩. التحويلات الدولية

صقار يُشغَّل من المملكة العربية السعودية. البنية التحتية السحابية
لدينا في [المنطقة — تُحدَّد قبل النشر].

---

## ١٠. التغييرات على هذه السياسة

قد نُحدِّث هذه السياسة. سنُبلغك داخل التطبيق (أو بالبريد) قبل أي
تغيير جوهري بـ١٤ يوماً على الأقل.

---

## ١١. التواصل

**Digital Harbor**
البريد الإلكتروني: support@digitalharbor.com.sa
الموقع: https://digitalharbor.com.sa
العنوان: [عنوان الشركة — يُملأ قبل النشر]
