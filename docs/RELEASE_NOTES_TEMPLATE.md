# Release Notes Template

> Play Store caps release notes at **500 characters per language**.
> Keep them tight and benefit-focused. Bullet points work great; full
> paragraphs read as legalese.
>
> Per Play Console policy: don't list internal-only changes like
> "refactored auth controller". Write for users — what changed *for
> them*.

---

## 1.0.0 (first public release)

### English

```
Welcome to Saqqar — your AI copilot for Odoo.

• Chat with your live Odoo data in Arabic or English
• Generate Excel, PDF, and Word reports in seconds
• Manage multiple projects and environments
• Approval-gated writes keep production safe
• Secure on-device credential storage

Feedback: support@digitalharbor.com.sa
```

### العربية

```
أهلاً بك في صقار — مساعد أودو الذكي.

• تحدّث مع بيانات Odoo الحية بالعربي أو الإنجليزي
• صدّر تقارير Excel وPDF وWord في ثوان
• أدِر عدة مشاريع وبيئات
• الإجراءات الحساسة محمية بالموافقة
• حفظ آمن لبيانات الاعتماد على جهازك

ملاحظاتك: support@digitalharbor.com.sa
```

---

## Template for future releases

Pattern: 3–6 user-visible bullets, opened by a one-line lead, closed
by the support email. Group by theme (new, improvements, fixes).
Don't list every commit.

### English

```
What's new in 1.x.x:

• [User-visible new feature, ≤90 chars]
• [User-visible improvement, ≤90 chars]
• [User-visible fix, ≤90 chars]

Feedback: support@digitalharbor.com.sa
```

### العربية

```
الجديد في 1.x.x:

• [ميزة جديدة يراها المستخدم، ≤90 حرف]
• [تحسين يلمسه المستخدم، ≤90 حرف]
• [إصلاح يلاحظه المستخدم، ≤90 حرف]

ملاحظاتك: support@digitalharbor.com.sa
```

---

## Writing tips

- **Lead with the headline change.** "Faster chat scroll" beats
  "Performance improvements".
- **No version-number jargon in the bullets.** The version is shown
  separately by Play Store.
- **No company name in the notes.** Users already know who made the
  app; the contact line at the bottom is enough.
- **Skip the "Thank you for using Saqqar!"** filler. Real users
  recognize it as filler from any app.
- **Localize properly.** Don't run the English through Google
  Translate — write the Arabic from scratch with the same voice.

---

## Don't forget to bump pubspec.yaml first

Before building a new AAB, edit `pubspec.yaml`:

```yaml
version: 1.0.1+2  # name=1.0.1, code=2
```

Then rebuild:

```powershell
flutter build appbundle --release `
  --dart-define=SAQQAR_SENTRY_DSN=https://...
```

Upload the new AAB to Play Console with these release notes pasted
under `Production → Create new release → Release notes`.
