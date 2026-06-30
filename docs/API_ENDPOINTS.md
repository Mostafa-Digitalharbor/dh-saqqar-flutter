# Saqqar Mobile — API Endpoints

كل الـ endpoints اللي بيتعامل معاها التطبيق، مجمّعة حسب الـ feature.

- **Base URL:** `https://saqqaar.com` (يتظبط وقت البناء عن طريق `--dart-define=SAQQAR_BASE_URL=...`)
- **التعريف المركزي:** [lib/core/network/api_endpoints.dart](../lib/core/network/api_endpoints.dart)
- معظم المسارات مثبتة على `/api/v1/` ما عدا الـ Email-OTP auth (مثبتة على `/api/auth/`).
- عمود **Auth**: ✅ = محتاج Bearer token، ⬜ = عام (Public) من غير token.

---

## 1) Auth — الجلسات (`/api/v1/auth/`)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| POST | `/api/v1/auth/register/` | تسجيل مستخدم جديد | ⬜ | [auth_api.dart:36](../lib/features/auth/data/auth_api.dart#L36) |
| POST | `/api/v1/auth/login/` | تسجيل الدخول | ⬜ | [auth_api.dart:51](../lib/features/auth/data/auth_api.dart#L51) |
| POST | `/api/v1/auth/logout/` | تسجيل الخروج | ✅ | [auth_api.dart:219](../lib/features/auth/data/auth_api.dart#L219) |
| GET | `/api/v1/auth/me/` | بيانات المستخدم الحالي | ✅ | [auth_api.dart:226](../lib/features/auth/data/auth_api.dart#L226) |
| PATCH | `/api/v1/auth/me/` | تعديل بيانات الحساب | ✅ | [auth_api.dart:247](../lib/features/auth/data/auth_api.dart#L247) |
| POST | `/api/v1/auth/password/` | تغيير كلمة المرور (بيرجّع token جديد ويلغي باقي الأجهزة) | ✅ | [auth_api.dart:267](../lib/features/auth/data/auth_api.dart#L267) |

## 2) Email-OTP Auth — تسجيل/دخول بالكود (`/api/auth/`)

> ملاحظة: دي تحت namespace غير مُرقّم `/api/auth/` مش `/api/v1/auth/`.

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| POST | `/api/auth/signup/start/` | بدء التسجيل بإرسال كود للإيميل | ⬜ | [auth_api.dart:66](../lib/features/auth/data/auth_api.dart#L66) |
| POST | `/api/auth/signup/verify/` | التحقق من كود التسجيل | ⬜ | [auth_api.dart:82](../lib/features/auth/data/auth_api.dart#L82) |
| POST | `/api/auth/signup/resend/` | إعادة إرسال كود التسجيل | ⬜ | [auth_api.dart:93](../lib/features/auth/data/auth_api.dart#L93) |
| POST | `/api/auth/signup/complete/` | إكمال التسجيل | ⬜ | [auth_api.dart:118](../lib/features/auth/data/auth_api.dart#L118) |
| POST | `/api/auth/login/email/start/` | بدء الدخول بالإيميل | ⬜ | [auth_api.dart:131](../lib/features/auth/data/auth_api.dart#L131) |
| POST | `/api/auth/login/email/verify/` | التحقق من كود الدخول | ⬜ | [auth_api.dart:143](../lib/features/auth/data/auth_api.dart#L143) |
| POST | `/api/auth/login/email/resend/` | إعادة إرسال كود الدخول | ⬜ | [auth_api.dart:153](../lib/features/auth/data/auth_api.dart#L153) |
| POST | `/api/auth/password/reset/start/` | بدء استعادة كلمة المرور | ⬜ | [auth_api.dart:166](../lib/features/auth/data/auth_api.dart#L166) |
| POST | `/api/auth/password/reset/verify/` | التحقق من كود الاستعادة | ⬜ | [auth_api.dart:180](../lib/features/auth/data/auth_api.dart#L180) |
| POST | `/api/auth/password/reset/resend/` | إعادة إرسال كود الاستعادة | ⬜ | [auth_api.dart:191](../lib/features/auth/data/auth_api.dart#L191) |
| POST | `/api/auth/password/reset/complete/` | إكمال إعادة التعيين | ⬜ | [auth_api.dart:207](../lib/features/auth/data/auth_api.dart#L207) |

## 3) Conversations — المحادثات (`/api/v1/conversations/`)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| GET | `/api/v1/conversations/` | قائمة المحادثات | ✅ | [conversations_api.dart:26](../lib/features/conversations/data/conversations_api.dart#L26) |
| POST | `/api/v1/conversations/` | إنشاء محادثة جديدة | ✅ | [conversations_api.dart:49](../lib/features/conversations/data/conversations_api.dart#L49) |
| GET | `/api/v1/conversations/{id}/` | تفاصيل محادثة + الرسائل (polling) | ✅ | [conversations_api.dart:69](../lib/features/conversations/data/conversations_api.dart#L69) |
| PATCH | `/api/v1/conversations/{id}/` | تعديل المحادثة (مثل إعادة التسمية) | ✅ | [conversations_api.dart:109](../lib/features/conversations/data/conversations_api.dart#L109) |
| DELETE | `/api/v1/conversations/{id}/` | حذف المحادثة | ✅ | [conversations_api.dart:121](../lib/features/conversations/data/conversations_api.dart#L121) |
| POST | `/api/v1/conversations/{id}/messages/` | إرسال رسالة | ✅ | [conversations_api.dart:240](../lib/features/conversations/data/conversations_api.dart#L240) |
| POST | `/api/v1/conversations/{id}/attachments/` | رفع مرفق | ✅ | [conversations_api.dart:272](../lib/features/conversations/data/conversations_api.dart#L272) |
| GET | `/api/v1/conversations/{id}/attachments/{attachmentId}/status/` | حالة معالجة المرفق | ✅ | [conversations_api.dart:290](../lib/features/conversations/data/conversations_api.dart#L290) |
| POST | `/api/v1/conversations/{id}/stop/` | إيقاف تعاوني للـ agent (idempotent) | ✅ | [conversations_api.dart:130](../lib/features/conversations/data/conversations_api.dart#L130) |
| POST | `/api/v1/conversations/{id}/share/` | إنشاء رابط مشاركة للمحادثة | ✅ | [conversations_api.dart:145](../lib/features/conversations/data/conversations_api.dart#L145) |
| DELETE | `/api/v1/conversations/{id}/share/` | إلغاء رابط المشاركة | ✅ | [conversations_api.dart:158](../lib/features/conversations/data/conversations_api.dart#L158) |
| POST | `/api/v1/conversations/{id}/credentials/active/` | تفعيل الـ credentials للمحادثة | ✅ | [conversations_api.dart:170](../lib/features/conversations/data/conversations_api.dart#L170) |
| POST | `/api/v1/conversations/{id}/credentials/toggle/` | تبديل حالة الـ credentials | ✅ | [conversations_api.dart:184](../lib/features/conversations/data/conversations_api.dart#L184) |
| POST | `/api/v1/conversations/{id}/pending-actions/dismiss/` | تجاهل الـ pending actions | ✅ | [conversations_api.dart:212](../lib/features/conversations/data/conversations_api.dart#L212) |

## 4) Credentials — بيانات الاعتماد (`/api/v1/credentials/`)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| GET | `/api/v1/credentials/schemas/` | مخططات نماذج الإدخال (schema-driven) | ✅ | [credentials_api.dart:32](../lib/features/vault/data/credentials_api.dart#L32) |
| GET | `/api/v1/credentials/` | قائمة بيانات الاعتماد | ✅ | [credentials_api.dart:46](../lib/features/vault/data/credentials_api.dart#L46) |
| GET | `/api/v1/credentials/{name}/` | تفاصيل بيانات اعتماد | ✅ | [credentials_api.dart:56](../lib/features/vault/data/credentials_api.dart#L56) |
| POST | `/api/v1/credentials/test/` | اختبار الاتصال من غير تخزين | ✅ | [credentials_api.dart:79](../lib/features/vault/data/credentials_api.dart#L79) |
| POST | `/api/v1/credentials/` | إنشاء بيانات اعتماد | ✅ | [credentials_api.dart:139](../lib/features/vault/data/credentials_api.dart#L139) |
| PATCH | `/api/v1/credentials/{name}/` | تعديل بيانات اعتماد | ✅ | [credentials_api.dart:172](../lib/features/vault/data/credentials_api.dart#L172) |
| DELETE | `/api/v1/credentials/{name}/` | حذف بيانات اعتماد | ✅ | [credentials_api.dart:187](../lib/features/vault/data/credentials_api.dart#L187) |

## 5) Projects & Environments — المشاريع والبيئات (`/api/v1/projects/`)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| GET | `/api/v1/projects/` | قائمة المشاريع | ✅ | [projects_api.dart:22](../lib/features/vault/data/projects_api.dart#L22) |
| POST | `/api/v1/projects/` | إنشاء مشروع | ✅ | [projects_api.dart:46](../lib/features/vault/data/projects_api.dart#L46) |
| POST | `/api/v1/projects/default/` | ضمان مشروع/بيئة افتراضية ("Use My Database") | ✅ | [projects_api.dart:36](../lib/features/vault/data/projects_api.dart#L36) |
| GET | `/api/v1/projects/{id}/` | تفاصيل مشروع | ✅ | [projects_api.dart:55](../lib/features/vault/data/projects_api.dart#L55) |
| PATCH | `/api/v1/projects/{id}/` | تعديل مشروع | ✅ | [projects_api.dart:63](../lib/features/vault/data/projects_api.dart#L63) |
| DELETE | `/api/v1/projects/{id}/` | حذف مشروع | ✅ | [projects_api.dart:72](../lib/features/vault/data/projects_api.dart#L72) |
| POST | `/api/v1/projects/{projectId}/environments/` | إنشاء بيئة | ✅ | [projects_api.dart:85](../lib/features/vault/data/projects_api.dart#L85) |
| GET | `/api/v1/environments/{id}/` | تفاصيل بيئة | ✅ | [projects_api.dart:101](../lib/features/vault/data/projects_api.dart#L101) |
| PATCH | `/api/v1/environments/{id}/` | تعديل بيئة | ✅ | [projects_api.dart:123](../lib/features/vault/data/projects_api.dart#L123) |
| DELETE | `/api/v1/environments/{id}/` | حذف بيئة | ✅ | [projects_api.dart:134](../lib/features/vault/data/projects_api.dart#L134) |
| GET | `/api/v1/environments/{environmentId}/credentials/` | بيانات اعتماد البيئة | ✅ | [projects_api.dart:143](../lib/features/vault/data/projects_api.dart#L143) |
| GET | `/api/v1/environments/{environmentId}/credentials/{kind}/` | بيانات اعتماد بنوع محدد | ✅ | [projects_api.dart:158](../lib/features/vault/data/projects_api.dart#L158) |
| PUT | `/api/v1/environments/{environmentId}/credentials/{kind}/` | حفظ/تحديث بيانات اعتماد البيئة | ✅ | [projects_api.dart:181](../lib/features/vault/data/projects_api.dart#L181) |
| DELETE | `/api/v1/environments/{environmentId}/credentials/{kind}/` | حذف بيانات اعتماد البيئة | ✅ | [projects_api.dart:195](../lib/features/vault/data/projects_api.dart#L195) |

## 6) Approvals — الموافقات (`/api/v1/approvals/`)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| GET | `/api/v1/approvals/` | قائمة الموافقات (`?status=pending` + `pending_count`) | ✅ | [approvals_api.dart:22](../lib/features/inbox/data/approvals_api.dart#L22) |
| POST | `/api/v1/approvals/{id}/decision/` | اتخاذ قرار (موافقة/رفض) | ✅ | [approvals_api.dart:50](../lib/features/inbox/data/approvals_api.dart#L50) |

## 7) Artifacts — المخرجات (`/api/v1/artifacts/`)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| GET | `/api/v1/artifacts/` | قائمة الـ artifacts | ✅ | [artifacts_api.dart:17](../lib/features/inbox/data/artifacts_api.dart#L17) |

## 8) Plans / Pricing — الخطط والأسعار (`/api/v1/plans/`)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| GET | `/api/v1/plans/` | قائمة الخطط (عام؛ لو فيه token بيرجّع `current_plan`) | ⬜ | [plans_api.dart:18](../lib/features/billing/data/plans_api.dart#L18) |

## 9) Shares — المحادثات المشتركة (`/api/v1/shares/`)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| GET | `/api/v1/shares/{token}/` | عرض نص محادثة مشتركة | ⬜ | [shares_api.dart:17](../lib/features/share/data/shares_api.dart#L17) |

## 10) i18n — الترجمة (`/api/v1/i18n/`)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| GET | `/api/v1/i18n/{lang}.json` | ملف ترجمة عن بُعد | ⬜ | [remote_i18n_api.dart:21](../lib/core/i18n/remote_i18n_api.dart#L21) |

## 11) Voice — التفريغ الصوتي (`/api/v1/transcribe/`)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| POST | `/api/v1/transcribe/` | رفع صوت (multipart `audio`، ≤25MB/≤120s) → نص عبر Whisper | ✅ | [transcribe_api.dart:56](../lib/features/chat/data/transcribe_api.dart#L56) |

## 12) Devices / Push — الأجهزة والإشعارات (`/api/v1/devices/`)

| Method | Path | الوصف | Auth | المصدر |
|--------|------|-------|:----:|--------|
| GET | `/api/v1/devices/` | قائمة الأجهزة المسجّلة | ✅ | [devices_api.dart:72](../lib/features/push/data/devices_api.dart#L72) |
| POST | `/api/v1/devices/` | تسجيل جهاز (push token) | ✅ | [devices_api.dart:92](../lib/features/push/data/devices_api.dart#L92) |
| DELETE | `/api/v1/devices/{id}/` | إلغاء تسجيل جهاز | ✅ | [devices_api.dart:105](../lib/features/push/data/devices_api.dart#L105) |

---

_تم التوليد من تحليل الكود — المصدر المرجعي هو [api_endpoints.dart](../lib/core/network/api_endpoints.dart). لو اتغيّر مسار، حدّث الملف ده._
