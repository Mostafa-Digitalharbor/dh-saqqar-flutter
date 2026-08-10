# Saqqar Mobile — API Endpoints

كل الـ endpoints اللي بيتعامل معاها التطبيق، مجمّعة حسب الـ feature.

- **Base URL:** `https://saqqaar.com` (يتظبط وقت البناء عن طريق `--dart-define=SAQQAR_BASE_URL=...`)
- **التعريف المركزي للمسارات:** [lib/core/network/api_endpoints.dart](../lib/core/network/api_endpoints.dart) — أي تعديل في مسار يتعمل هنا في مكان واحد.
- معظم المسارات مثبتة على `/api/v1/` ما عدا الـ Email-OTP auth (مثبتة على `/api/auth/` بدون نسخة).
- عمود **Auth**: ✅ = محتاج Bearer token، ⬜ = عام (Public) من غير token.
- عمود **المصدر** بيوديك لتعريف الـ method اللي بتنادي الـ endpoint في الكود.

---

## 1) Auth — الجلسات (`/api/v1/auth/`)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| POST | `/api/v1/auth/register/` | تسجيل مستخدم جديد + إرجاع token | ⬜ | [auth_api.dart:29](../lib/features/auth/data/auth_api.dart#L29) |
| POST | `/api/v1/auth/login/` | تسجيل الدخول بالإيميل وكلمة المرور | ⬜ | [auth_api.dart:48](../lib/features/auth/data/auth_api.dart#L48) |
| POST | `/api/v1/auth/google/` | تبديل Google `id_token` بـ token (ربط تلقائي بالإيميل) | ⬜ | [auth_api.dart:66](../lib/features/auth/data/auth_api.dart#L66) |
| POST | `/api/v1/auth/apple/` | تبديل Apple `id_token` (`user` أول مرة بس) | ⬜ | [auth_api.dart:79](../lib/features/auth/data/auth_api.dart#L79) |
| POST | `/api/v1/auth/logout/` | تسجيل الخروج (إلغاء التوكن الحالي) | ✅ | [auth_api.dart:289](../lib/features/auth/data/auth_api.dart#L289) |
| GET | `/api/v1/auth/me/` | بيانات المستخدم الحالي + counts | ✅ | [auth_api.dart:308](../lib/features/auth/data/auth_api.dart#L308) |
| PATCH | `/api/v1/auth/me/` | تعديل بيانات الحساب (`first_name`/`last_name`) | ✅ | [auth_api.dart:322](../lib/features/auth/data/auth_api.dart#L322) |
| POST | `/api/v1/auth/password/` | تغيير كلمة المرور (token جديد + إلغاء باقي الأجهزة) | ✅ | [auth_api.dart:346](../lib/features/auth/data/auth_api.dart#L346) |
| POST | `/api/v1/account/delete/` | حذف الحساب وكل بياناته نهائيًا | ✅ | [auth_api.dart:299](../lib/features/auth/data/auth_api.dart#L299) |
| POST | `/api/v1/auth/web-session/` | تسليم جلسة لمرّة واحدة للمتصفح: `{next}` → `{ok, url}` قبل فتح checkout الويب | ✅ | [web_checkout.dart:127](../lib/features/billing/data/web_checkout.dart#L127) |

> **web-session:** بيرجّع `/auth/handoff/?t=<one-time-token>` عشان المتصفح يفتح والمستخدم مسجّل دخول بدل ما يوصل مجهول ويعمل حساب تاني. أي رد غير 200 (بما فيه 404 لو السيرفر لسه منزّلوش) بيتعامل كأنه "مش متاح" والتطبيق بيفتح صفحة `/pricing/` العادية — فمش هيكسر لو الـ endpoint اتأخّر. التطبيق كمان بيتحقق إن الـ host والـ scheme بتوع الرد نفس `baseUrl` قبل ما يفتحه، لأن الرابط شايل توكن دخول حيّ.

## 2) Email-OTP Auth — تسجيل/دخول بالكود (`/api/auth/`)

> ملاحظة: دي تحت namespace غير مُرقّم `/api/auth/` مش `/api/v1/auth/`.

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| POST | `/api/auth/signup/start/` | بدء التسجيل بإرسال كود للإيميل | ⬜ | [auth_api.dart:132](../lib/features/auth/data/auth_api.dart#L132) |
| POST | `/api/auth/signup/verify/` | التحقق من كود التسجيل | ⬜ | [auth_api.dart:145](../lib/features/auth/data/auth_api.dart#L145) |
| POST | `/api/auth/signup/resend/` | إعادة إرسال كود التسجيل | ⬜ | [auth_api.dart:159](../lib/features/auth/data/auth_api.dart#L159) |
| POST | `/api/auth/signup/complete/` | إكمال التسجيل + إرجاع session | ⬜ | [auth_api.dart:170](../lib/features/auth/data/auth_api.dart#L170) |
| POST | `/api/auth/login/email/start/` | بدء الدخول بالإيميل (إرسال كود) | ⬜ | [auth_api.dart:197](../lib/features/auth/data/auth_api.dart#L197) |
| POST | `/api/auth/login/email/verify/` | التحقق من كود الدخول → `{ token, user }` | ⬜ | [auth_api.dart:206](../lib/features/auth/data/auth_api.dart#L206) |
| POST | `/api/auth/login/email/resend/` | إعادة إرسال كود الدخول | ⬜ | [auth_api.dart:219](../lib/features/auth/data/auth_api.dart#L219) |
| POST | `/api/auth/password/reset/start/` | بدء استعادة كلمة المرور | ⬜ | [auth_api.dart:232](../lib/features/auth/data/auth_api.dart#L232) |
| POST | `/api/auth/password/reset/verify/` | التحقق → إرجاع `reset_token` | ⬜ | [auth_api.dart:243](../lib/features/auth/data/auth_api.dart#L243) |
| POST | `/api/auth/password/reset/resend/` | إعادة إرسال كود الاستعادة | ⬜ | [auth_api.dart:261](../lib/features/auth/data/auth_api.dart#L261) |
| POST | `/api/auth/password/reset/complete/` | تعيين كلمة مرور جديدة (`new_password`) + session | ⬜ | [auth_api.dart:274](../lib/features/auth/data/auth_api.dart#L274) |

## 3) Conversations — المحادثات (`/api/v1/conversations/`)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| GET | `/api/v1/conversations/` | قائمة المحادثات (`?limit=&include_archived=`) | ✅ | [conversations_api.dart:22](../lib/features/conversations/data/conversations_api.dart#L22) |
| POST | `/api/v1/conversations/` | إنشاء محادثة جديدة | ✅ | [conversations_api.dart:48](../lib/features/conversations/data/conversations_api.dart#L48) |
| GET | `/api/v1/conversations/{id}/` | Snapshot المحادثة + الرسائل (`?since=&before=&limit=`, polling) | ✅ | [conversations_api.dart:84](../lib/features/conversations/data/conversations_api.dart#L84) |
| PATCH | `/api/v1/conversations/{id}/` | تعديل المحادثة (العنوان/الأرشفة) | ✅ | [conversations_api.dart:152](../lib/features/conversations/data/conversations_api.dart#L152) |
| DELETE | `/api/v1/conversations/{id}/` | حذف المحادثة (cascade) | ✅ | [conversations_api.dart:186](../lib/features/conversations/data/conversations_api.dart#L186) |
| POST | `/api/v1/conversations/{id}/messages/` | إرسال رسالة | ✅ | [conversations_api.dart:293](../lib/features/conversations/data/conversations_api.dart#L293) |
| POST | `/api/v1/conversations/{id}/attachments/` | رفع مرفق (multipart) | ✅ | [conversations_api.dart:320](../lib/features/conversations/data/conversations_api.dart#L320) |
| GET | `/api/v1/conversations/{id}/attachments/{attachmentId}/status/` | حالة معالجة المرفق | ✅ | [conversations_api.dart:352](../lib/features/conversations/data/conversations_api.dart#L352) |
| POST | `/api/v1/conversations/{id}/stop/` | إيقاف تعاوني للـ agent (idempotent) | ✅ | [conversations_api.dart:195](../lib/features/conversations/data/conversations_api.dart#L195) |
| POST | `/api/v1/conversations/{id}/share/` | إنشاء/إعادة استخدام رابط مشاركة | ✅ | [conversations_api.dart:210](../lib/features/conversations/data/conversations_api.dart#L210) |
| DELETE | `/api/v1/conversations/{id}/share/` | إلغاء رابط المشاركة | ✅ | [conversations_api.dart:223](../lib/features/conversations/data/conversations_api.dart#L223) |
| POST | `/api/v1/conversations/{id}/credentials/active/` | تفعيل الـ credentials للمحادثة (legacy) | ✅ | [conversations_api.dart:232](../lib/features/conversations/data/conversations_api.dart#L232) |
| POST | `/api/v1/conversations/{id}/credentials/toggle/` | تبديل حالة الـ credentials | ✅ | [conversations_api.dart:245](../lib/features/conversations/data/conversations_api.dart#L245) |
| POST | `/api/v1/conversations/{id}/pending-actions/dismiss/` | تجاهل الـ pending actions | ✅ | [conversations_api.dart:267](../lib/features/conversations/data/conversations_api.dart#L267) |

## 4) Credentials — بيانات الاعتماد (`/api/v1/credentials/`)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| GET | `/api/v1/credentials/schemas/` | مخططات نماذج الإدخال (schema-driven) | ✅ | [credentials_api.dart:42](../lib/features/vault/data/credentials_api.dart#L42) |
| GET | `/api/v1/credentials/` | قائمة بيانات الاعتماد | ✅ | [credentials_api.dart:56](../lib/features/vault/data/credentials_api.dart#L56) |
| GET | `/api/v1/credentials/{name}/` | تفاصيل bundle بالأسرار المفكوكة | ✅ | [credentials_api.dart:66](../lib/features/vault/data/credentials_api.dart#L66) |
| POST | `/api/v1/credentials/test/` | اختبار الاتصال من غير تخزين | ✅ | [credentials_api.dart:85](../lib/features/vault/data/credentials_api.dart#L85) |
| POST | `/api/v1/credentials/databases/` | جلب قواعد بيانات Odoo المتاحة على URL | ✅ | [credentials_api.dart:137](../lib/features/vault/data/credentials_api.dart#L137) |
| POST | `/api/v1/credentials/` | إنشاء/تحديث (idempotent بالاسم) | ✅ | [credentials_api.dart:163](../lib/features/vault/data/credentials_api.dart#L163) |
| PATCH | `/api/v1/credentials/{name}/` | تعديل label/payload/metadata | ✅ | [credentials_api.dart:203](../lib/features/vault/data/credentials_api.dart#L203) |
| DELETE | `/api/v1/credentials/{name}/` | حذف نهائي | ✅ | [credentials_api.dart:228](../lib/features/vault/data/credentials_api.dart#L228) |

## 5) Projects & Environments — المشاريع والبيئات (`/api/v1/projects/`)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| GET | `/api/v1/projects/` | قائمة المشاريع + البيئات | ✅ | [projects_api.dart:21](../lib/features/vault/data/projects_api.dart#L21) |
| POST | `/api/v1/projects/` | إنشاء مشروع (الـ slug من السيرفر) | ✅ | [projects_api.dart:45](../lib/features/vault/data/projects_api.dart#L45) |
| POST | `/api/v1/projects/default/` | ضمان مشروع/بيئة افتراضية ("Use My Database") | ✅ | [projects_api.dart:35](../lib/features/vault/data/projects_api.dart#L35) |
| GET | `/api/v1/projects/{id}/` | تفاصيل مشروع | ✅ | [projects_api.dart:54](../lib/features/vault/data/projects_api.dart#L54) |
| PATCH | `/api/v1/projects/{id}/` | إعادة تسمية مشروع (الـ slug ثابت) | ✅ | [projects_api.dart:62](../lib/features/vault/data/projects_api.dart#L62) |
| DELETE | `/api/v1/projects/{id}/` | حذف مشروع (cascade) | ✅ | [projects_api.dart:71](../lib/features/vault/data/projects_api.dart#L71) |
| POST | `/api/v1/projects/{projectId}/environments/` | إنشاء بيئة | ✅ | [projects_api.dart:78](../lib/features/vault/data/projects_api.dart#L78) |
| GET | `/api/v1/environments/{id}/` | تفاصيل بيئة | ✅ | [projects_api.dart:100](../lib/features/vault/data/projects_api.dart#L100) |
| PATCH | `/api/v1/environments/{id}/` | تعديل بيئة | ✅ | [projects_api.dart:110](../lib/features/vault/data/projects_api.dart#L110) |
| DELETE | `/api/v1/environments/{id}/` | حذف بيئة (cascade) | ✅ | [projects_api.dart:133](../lib/features/vault/data/projects_api.dart#L133) |
| GET | `/api/v1/environments/{environmentId}/credentials/` | بيانات اعتماد البيئة (metadata) | ✅ | [projects_api.dart:140](../lib/features/vault/data/projects_api.dart#L140) |
| GET | `/api/v1/environments/{environmentId}/credentials/{kind}/` | بيانات اعتماد بنوع محدد (بالأسرار) | ✅ | [projects_api.dart:154](../lib/features/vault/data/projects_api.dart#L154) |
| PUT | `/api/v1/environments/{environmentId}/credentials/{kind}/` | حفظ/تحديث (upsert) | ✅ | [projects_api.dart:169](../lib/features/vault/data/projects_api.dart#L169) |
| DELETE | `/api/v1/environments/{environmentId}/credentials/{kind}/` | حذف بيانات اعتماد البيئة | ✅ | [projects_api.dart:191](../lib/features/vault/data/projects_api.dart#L191) |

## 6) Approvals — الموافقات (`/api/v1/approvals/`)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| GET | `/api/v1/approvals/` | قائمة الموافقات (`?status=&limit=&offset=` + `pending_count`) | ✅ | [approvals_api.dart:17](../lib/features/inbox/data/approvals_api.dart#L17) |
| POST | `/api/v1/approvals/{id}/decision/` | اتخاذ قرار (موافقة/رفض) | ✅ | [approvals_api.dart:39](../lib/features/inbox/data/approvals_api.dart#L39) |

## 7) Artifacts — المخرجات (`/api/v1/artifacts/`)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| GET | `/api/v1/artifacts/` | قائمة الـ artifacts مقسّمة (`?limit=&offset=`) | ✅ | [artifacts_api.dart:16](../lib/features/inbox/data/artifacts_api.dart#L16) |

## 8) Billing — الخطط والاستهلاك

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| GET | `/api/v1/plans/` | قائمة الخطط (عام؛ لو فيه token بيرجّع `current_plan`) | ⬜ | [plans_api.dart:17](../lib/features/billing/data/plans_api.dart#L17) |
| GET | `/api/v1/usage/` | استهلاك التوكنز + الحدود (يوم/أسبوع/شهر) + الخطة | ✅ | [usage_api.dart:23](../lib/features/billing/data/usage_api.dart#L23) |

## 9) Shares — المحادثات المشتركة (`/api/v1/shares/`)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| GET | `/api/v1/shares/{token}/` | عرض نص محادثة مشتركة (للقراءة فقط) | ⬜ | [shares_api.dart:16](../lib/features/share/data/shares_api.dart#L16) |

## 10) i18n — الترجمة (`/api/v1/i18n/`)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| GET | `/api/v1/i18n/{lang}.json` | جدول الـ strings الكامل للّغة (عن بُعد) | ⬜ | [remote_i18n_api.dart:20](../lib/core/i18n/remote_i18n_api.dart#L20) |

## 11) Voice — التفريغ الصوتي (`/api/v1/transcribe/`)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| POST | `/api/v1/transcribe/` | رفع صوت (multipart `audio`، m4a ≤25MB/≤120s) → نص عبر Whisper | ✅ | [transcribe_api.dart:32](../lib/features/chat/data/transcribe_api.dart#L32) |

## 12) Devices / Push — الأجهزة والإشعارات (`/api/v1/devices/`)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| GET | `/api/v1/devices/` | قائمة الأجهزة المسجّلة | ✅ | [devices_api.dart:71](../lib/features/push/data/devices_api.dart#L71) |
| POST | `/api/v1/devices/` | تسجيل جهاز (upsert بالـ push token) | ✅ | [devices_api.dart:87](../lib/features/push/data/devices_api.dart#L87) |
| DELETE | `/api/v1/devices/{id}/` | إلغاء تسجيل جهاز (idempotent) | ✅ | [devices_api.dart:111](../lib/features/push/data/devices_api.dart#L111) |

## 13) Health — فحص الاتصال (`/api/v1/health/`)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| GET | `/api/v1/health/` | فحص liveness/version → `{ ok, service, time, api }` | ⬜ | [api_endpoints.dart:181](../lib/core/network/api_endpoints.dart#L181) |

> ملاحظة: `health` مُعرّف في `ApiEndpoints` كـ pre-flight للاتصال، لكن مفيش method حاليًا بتناديه في كود Dart.

## 14) روابط الملفات الديناميكية (مش endpoints ثابتة)

المرفقات والـ artifacts بيرجّعوا في الـ responses حقل `url` **نسبي** (زي `/media/reports/...`)، والتطبيق بيحوّله لرابط كامل عن طريق `absoluteUrl` (`baseUrl + url`) وبعدين بيحمّله بالـ Bearer token. المسار بيتغيّر مع كل ملف فمش endpoint ثابت.

| العملية | الطريقة | المصدر |
|---------|---------|--------|
| تحميل ملف artifact | `_dio.download(absoluteUrl, …)` | [artifact_downloader.dart:137](../lib/features/inbox/data/artifact_downloader.dart#L137) |
| عرض صورة مرفقة | `Image.network(absoluteUrl)` | [attachment_chip.dart:294](../lib/features/chat/widgets/attachment_chip.dart#L294) |
| بناء الرابط الكامل | `absoluteUrl` getter (artifacts + attachments) | [artifact_models.dart:67](../lib/features/inbox/data/artifact_models.dart#L67) · [attachment_models.dart:55](../lib/features/conversations/data/attachment_models.dart#L55) |

---

# نقاط النهاية الجديدة (`API_MOBILE_NEW_ENDPOINTS.md`)

الأقسام دي اتضافت من الـ hand-off بتاع الباك-إند واتوصّلت في التطبيق (2026-07-23).

## 15) Saqqar Apps — الباقات الموجّهة (`/api/v1/apps/`)

المصدر: [apps_api.dart](../lib/features/apps/data/apps_api.dart) · UI: [apps_screen.dart](../lib/features/apps/view/apps_screen.dart)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| GET | `/api/v1/apps/` | قائمة الباقات (ZATCA, WhatsApp…) + `accent` + `env_required` | ✅ | [apps_api.dart:15](../lib/features/apps/data/apps_api.dart#L15) |
| POST | `/api/v1/apps/{slug}/launch/` | إنشاء محادثة متعلّمة بالباكدج → `conversation_id` | ✅ | [apps_api.dart:27](../lib/features/apps/data/apps_api.dart#L27) |

## 16) Managed Odoo Trial — التجربة المُدارة (`/api/v1/trial/`)

المصدر: [trial_api.dart](../lib/features/trial/data/trial_api.dart) · UI: [trial_screen.dart](../lib/features/trial/view/trial_screen.dart)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| POST | `/api/v1/trial/` | طلب تجربة (idempotent: تجربة واحدة لكل مستخدم) | ✅ | [trial_api.dart:18](../lib/features/trial/data/trial_api.dart#L18) |
| GET | `/api/v1/trial/status/` | متابعة الحالة بالـ polling؛ لما `ready` بترجّع **admin credentials** | ✅ | [trial_api.dart:31](../lib/features/trial/data/trial_api.dart#L31) |

## 17) Billing history & receipts — سجل الفواتير (`/api/v1/billing/`)

المصدر: [billing_history_api.dart](../lib/features/billing/data/billing_history_api.dart) · UI: [billing_history_screen.dart](../lib/features/billing/view/billing_history_screen.dart)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| GET | `/api/v1/billing/history/` | مدفوعات المستخدم + الرصيد (قراءة فقط، آمن للستور) | ✅ | [billing_history_api.dart:17](../lib/features/billing/data/billing_history_api.dart#L17) |
| GET | `/api/v1/billing/receipt/{ref}/` | تحميل إيصال PDF لصف مدفوع (عبر `ArtifactDownloader`) | ✅ | [billing_history_screen.dart:80](../lib/features/billing/view/billing_history_screen.dart#L80) |

> شاشة History **ظاهرة دايمًا على كل المنصّات** — `showBillingRecords` ثابت `true` وعن قصد مش ورا `showPaidUpsell` ([billing_visibility.dart:87](../lib/features/billing/data/billing_visibility.dart#L87)): إن التطبيق يوري المستخدم فلوس اتخصمت منه فعلًا ده معلومة حساب مش سطح شراء. للـ checkout (الشراء) شوف §21.

## 18) Artifact detail (`/api/v1/artifacts/{id}/`)

المصدر: [artifacts_api.dart](../lib/features/inbox/data/artifacts_api.dart) · UI: [artifact_details_sheet.dart](../lib/features/inbox/view/artifact_details_sheet.dart) (long-press على أي artifact في الـ chat rail)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| GET | `/api/v1/artifacts/{id}/` | تفاصيل artifact واحد | ✅ | [artifacts_api.dart:28](../lib/features/inbox/data/artifacts_api.dart#L28) |

## 19) §4.1 Meetings · Vexa — تفريغ الاجتماعات (`/api/v1/meetings/`)

المصدر: [meetings_api.dart](../lib/features/meetings/data/meetings_api.dart) · UI: [meetings_screen.dart](../lib/features/meetings/view/meetings_screen.dart)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| POST | `/api/v1/meetings/` | بدء تفريغ اجتماع | ✅ | [meetings_api.dart:18](../lib/features/meetings/data/meetings_api.dart#L18) |
| GET | `/api/v1/meetings/{id}/transcript` | جلب النص (polling) | ✅ | [meetings_api.dart:22](../lib/features/meetings/data/meetings_api.dart#L22) |
| POST | `/api/v1/meetings/{id}/stop` | إيقاف الاجتماع | ✅ | [meetings_api.dart:30](../lib/features/meetings/data/meetings_api.dart#L30) |
| POST | `/api/v1/meetings/{id}/summarize` | تلخيص | ✅ | [meetings_api.dart:34](../lib/features/meetings/data/meetings_api.dart#L34) |
| POST | `/api/v1/meetings/{id}/chat` | محادثة فوق النص | ✅ | [meetings_api.dart:38](../lib/features/meetings/data/meetings_api.dart#L38) |

## 20) §4.2 Direct data API — قراءة Odoo بدون agent (`/api/v1/environments/{envId}/…`)

المصدر: [odoo_data_api.dart](../lib/features/data_api/data/odoo_data_api.dart) · UI: [data_explorer_screen.dart](../lib/features/data_api/view/data_explorer_screen.dart) — **كل الـ 7 operations موصّلين** (operation dropdown + JSON body editor)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| POST | `/api/v1/environments/{envId}/odoo/search/` | بحث في السجلات | ✅ | [odoo_data_api.dart:20](../lib/features/data_api/data/odoo_data_api.dart#L20) |
| POST | `/api/v1/environments/{envId}/odoo/count/` | عدّ السجلات | ✅ | [odoo_data_api.dart:24](../lib/features/data_api/data/odoo_data_api.dart#L24) |
| POST | `/api/v1/environments/{envId}/odoo/read-group/` | تجميعات مجمّعة | ✅ | [odoo_data_api.dart:28](../lib/features/data_api/data/odoo_data_api.dart#L28) |
| POST | `/api/v1/environments/{envId}/odoo/read/` | قراءة بالـ id | ✅ | [odoo_data_api.dart:32](../lib/features/data_api/data/odoo_data_api.dart#L32) |
| POST | `/api/v1/environments/{envId}/odoo/fields/` | ميتاداتا الحقول | ✅ | [odoo_data_api.dart:36](../lib/features/data_api/data/odoo_data_api.dart#L36) |
| POST | `/api/v1/environments/{envId}/sql/` | SQL للقراءة فقط | ✅ | [odoo_data_api.dart:40](../lib/features/data_api/data/odoo_data_api.dart#L40) |
| GET | `/api/v1/report-entities/` | قائمة الكيانات لفلتر التقارير (`?conversation_id=` **مطلوب**، وإلا 400) | ✅ | [odoo_data_api.dart:48](../lib/features/data_api/data/odoo_data_api.dart#L48) |

## 21) §4.3 Billing checkout — Paymob (`/api/v1/billing/`)

المصدر: [checkout_api.dart](../lib/features/billing/data/checkout_api.dart) · UI: [checkout_screen.dart](../lib/features/billing/view/checkout_screen.dart)

> ⚠️ **الـ 3 endpoints دول مش بيتنادوا في التطبيق المنشور — على أي منصّة.** الـ route بتاع `/checkout` متسجّل بس `redirect` ثابت على `/pricing` ([app_router.dart:256](../lib/core/routing/app_router.dart#L256))، فأي deep link أو push قديم بيوصل لكتالوج الخطط مش لفورم دفع. البيع كله بيحصل على saqqaar.com عن طريق §1 `web-session` + `/pricing/`، عشان الشراء جوه التطبيق بيتعارض مع App Store 3.1.1 و Google Play Payments.
>
> الكلاس متسايب موصّل ومتختبر عشان الرجوع يبقى قلب مفتاح واحد مش إعادة كتابة عميل دفع.

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| GET | `/api/v1/billing/plans/` | الباقات (Paymob view) | ✅ | [checkout_api.dart:23](../lib/features/billing/data/checkout_api.dart#L23) |
| POST | `/api/v1/billing/checkout/` | بدء عملية شراء (`{plan, cycle}`) → رابط دفع + reference | ✅ | [checkout_api.dart:44](../lib/features/billing/data/checkout_api.dart#L44) |
| GET | `/api/v1/billing/payment/{ref}/status/` | متابعة حالة الدفع (polling) | ✅ | [checkout_api.dart:53](../lib/features/billing/data/checkout_api.dart#L53) |

---

### ملخّص

- الإجمالي: **91 عملية** (method + path) على **21 مجموعة**. العدد أكبر من عدد المسارات لأن فيه مسارات بتاخد أكتر من method (زي `/auth/me/` GET+PATCH و `/credentials/{name}/` GET+PATCH+DELETE).
- الـ endpoints الـ **Public** (⬜، من غير bearer): كل مسارات **Email-OTP** (`/api/auth/…`) + `register`/`login`/`google`/`apple` + `plans` + `shares/{token}` + `i18n/{lang}.json` + `health`. الباقي كله محتاج **Bearer** (✅).
- **الـ endpoints اللي مش بتتنادى من التطبيق دلوقتي:**
  - `GET /api/v1/health/` — معرّف في `ApiEndpoints` كـ pre-flight بس مفيش كود Dart بيناديه.
  - **Billing checkout (§21)** الـ 3 كلهم — الـ route بيعمل redirect دايم على `/pricing` (شوف §21).
- **§4.1/§4.2 payload schemas** مش موثّقة في الـ hand-off (بيحيل على `views_meetings.py` / `views_data_api.py`) — الشاشات اتبنت على contract معقول (أعراف Odoo/Vexa) وفيها بانر "Preview"؛ محتاج تأكيد الباك-إند على مفاتيح الطلب.

### اتفاقيات عامة على كل الطلبات

- **التوكن:** `Authorization: Bearer <token>` بيتحط أوتوماتيك في [auth_interceptor.dart](../lib/core/network/auth_interceptor.dart) — بس على **نفس الـ host** بتاع `baseUrl`، عشان رابط artifact راجع من سيرفر تاني ما يسرّبش التوكن. الطلبات اللي المفروض تمشي من غير توكن بتتعلّم بـ `extra['skipAuth'] = true`.
- **مفيش refresh endpoint.** الـ 401 معناها انتهاء الجلسة — بس التطبيق **مش** بيطلّع المستخدم على أي 401؛ لازم الرد يقول صراحة `auth: false` في الـ envelope، عشان 401 عابرة من proxy ما ترميش المستخدم على شاشة الدخول.
- **شكل الخطأ:** `{ ok: false, error: "..." }` — بيتحوّل لـ `ApiException` في الـ interceptor وبعدين لرسالة متـرجمة عن طريق [api_error_mapper.dart](../lib/core/network/api_error_mapper.dart).
- **الملفات (attachments / artifacts):** بترجع بحقل `url` **نسبي**، والتطبيق بيكمّله بـ `absoluteUrl` — شوف §14.

_تم التوليد من تحليل الكود — المصدر المرجعي للمسارات هو [api_endpoints.dart](../lib/core/network/api_endpoints.dart). لو اتغيّر مسار أو اتنقل سطر، حدّث الجدول ده._
