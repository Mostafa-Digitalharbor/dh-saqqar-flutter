# Google Play Publishing Guide — Saqqar Mobile

> **Audience:** Whoever is uploading the first release of Saqqar to the
> Google Play Console. Written assuming this is your **first ever**
> Play Store upload — every step is spelled out.

This guide walks you from a fresh checkout to a live Play Store
listing. Total reading time ~20 min, total execution time once
prerequisites are in hand ~2 hours.

---

## Pre-flight: what's already done in the codebase

The repo is production-ready. The work below is configuration on the
Play Console side + asset prep + the keystore generation. Nothing in
the code needs to change.

Already wired:
- Application ID = `sa.com.digitalharbor.saqqar` (Android + iOS)
- INTERNET + ACCESS_NETWORK_STATE permissions in main manifest
- Release signing config reads from `android/key.properties` (gitignored)
- Sentry crash reporting via `--dart-define=SAQQAR_SENTRY_DSN=…`
- App lifecycle pause for the chat polling (battery savings)
- Logging interceptor disabled in release builds
- `targetSdk` follows Flutter defaults (34+ — meets Aug 2024 Play
  Store requirement)

---

## Stage 1 — Generate the release keystore

The keystore signs every APK / AAB you ship. **If you lose it, you
can never update the app on Play Store again.**

### 1.1 Run keytool

From the project root, in PowerShell:

```powershell
keytool -genkey -v `
  -keystore android/saqqar-release.jks `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -alias saqqar
```

You'll be prompted for:

| Prompt | Answer |
|---|---|
| `Enter keystore password` | strong password (won't echo as you type — that's intentional) |
| `Re-enter new password` | same password |
| `What is your first and last name?` | `Digital Harbor` |
| `What is the name of your organizational unit?` | `Mobile` |
| `What is the name of your organization?` | `Digital Harbor` |
| `What is the name of your City or Locality?` | `Riyadh` (or actual HQ) |
| `What is the name of your State or Province?` | `Riyadh Region` |
| `What is the two-letter country code?` | `SA` |
| `Is CN=… correct?` | `yes` |
| `Enter key password for <saqqar>` | press Enter to reuse the keystore password |

> **`keytool` hides password input** — no `***`, no dots, no asterisks.
> Type carefully and press Enter. This is normal terminal security
> behavior, not a bug.

### 1.2 Back the keystore up — three places minimum

Right now, before anything else:

1. **Password manager** (1Password / Bitwarden) — entry with both
   keystore password + key password + alias + creation date
2. **Encrypted company drive** — copy `android/saqqar-release.jks`
3. **External USB drive** stored in a different physical location
   from the laptop

Losing the keystore = losing the ability to update the app on Play
Store, forever. Google won't help you recover. This is by design.

### 1.3 Create `android/key.properties`

```powershell
copy android\key.properties.example android\key.properties
```

Edit `android/key.properties` with a text editor:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=saqqar
storeFile=saqqar-release.jks
```

The `.gitignore` already blocks this file from source control —
**never commit it** and never paste it in Slack or email.

---

## Stage 2 — Create the Sentry project

(Skip this section if the company already has a Sentry account and
you're adding to it.)

### 2.1 Sign up / log in

Go to **sentry.io** with the company Google account.

### 2.2 Create a new project

- **Platform:** Flutter
- **Project name:** `saqqar-mobile`
- **Alert frequency:** Default ("Alert me on every new issue")
- **Team:** whatever team owns this app

### 2.3 Copy the DSN

Sentry shows it on the first screen:

```
https://abc123def456@o1234567.ingest.us.sentry.io/9876543
```

Save this in the password manager next to the keystore entry. You'll
pass it via `--dart-define` when you build the release.

---

## Stage 3 — Build the release App Bundle (AAB)

Play Store requires the **`.aab`** format, not `.apk`.

```powershell
flutter clean
flutter pub get

flutter build appbundle --release `
  --dart-define=SAQQAR_SENTRY_DSN=https://abc123def456@o1234567.ingest.us.sentry.io/9876543
```

Build takes 3–6 minutes. Output:

```
build/app/outputs/bundle/release/app-release.aab
```

### 3.1 Verify the AAB is signed with your release key

```powershell
keytool -printcert -jarfile build\app\outputs\bundle\release\app-release.aab
```

You should see:
- `Owner: CN=Digital Harbor, OU=Mobile, O=Digital Harbor, …`
- `Valid until: 2052-xx-xx` (~27 years from now)

If it says `jar is unsigned` — `key.properties` isn't wired. Re-check
the file path and re-run.

---

## Stage 4 — Prepare store listing assets

Create a `play-store-assets/` folder somewhere outside the repo to
collect everything. The Play Console will accept uploads from here.

### 4.1 App icon — `icon.png`

- **Dimensions:** 512 × 512 px
- **Format:** PNG (32-bit RGBA but with full alpha = 255)
- **Source:** resize `assets/img/saqqar-launcher.png` to 512×512

### 4.2 Feature graphic — `feature.png`

- **Dimensions:** 1024 × 500 px
- **Format:** PNG or JPG
- **Design notes:**
  - SAQQAR wordmark prominently centered or left-aligned
  - Brand-cyan gradient backdrop (matches the app's ambient backdrop)
  - No critical text near the right edge (Play crops it on small
    screens)

Use Figma or Canva — both have free 1024×500 templates labeled "Play
Feature Graphic".

### 4.3 Phone screenshots (at least 2, recommended 8)

- **Dimensions:** any portrait between 320 px and 3840 px on the
  longest side. 1080 × 2400 (Pixel 7 portrait) is a safe default.
- **Format:** PNG or JPG (no alpha)

Recommended shots:
1. Chat with a successful Odoo query + reply
2. Conversations list (with at least 3 conversations visible)
3. Vault → project detail with environments listed
4. An inline approval card mid-conversation
5. An artifact pill (Excel / PDF generated) inside the chat
6. Composer with deep-think + auto-approve toggles visible
7. Account screen showing language / theme settings
8. Sign-in screen (clean — sets a polished first impression)

Take them on a 1080×2400 emulator via `adb shell screencap -p`. For
extra polish, wrap each in a phone mockup using
[previewed.app](https://previewed.app/) (free tier supports 8
screenshots).

### 4.4 Promo video (optional but high-impact)

A 30-second YouTube video. Unlisted is fine. Show:
1. Open app → sign in (~3 sec)
2. Type a query in Arabic ("كم عدد العملاء النشطين") → agent responds (~10 sec)
3. Request an Excel export → approve → artifact ready (~12 sec)
4. End on the Saqqar logo + "Available on Google Play" (~5 sec)

Upload to YouTube as Unlisted, copy the URL — you'll paste it in the
Play Console listing.

---

## Stage 5 — Required compliance items

Every one of these must be in place before Play Console will let you
publish. None are skippable.

### 5.1 Privacy policy URL

Must be hosted on the company domain (`digitalharbor.com.sa`).
Bilingual (Arabic + English) recommended. There's a template in
[docs/PRIVACY_POLICY.md](./PRIVACY_POLICY.md) — review with legal,
host it at `digitalharbor.com.sa/privacy-saqqar` (or similar) before
filing the Play Console listing.

### 5.2 Data Safety form — critical to fill honestly

In Play Console: `App content → Data safety`.

Saqqar's truthful answers:

**Does your app collect or share any of the required user data
types?** → Yes.

**Personal info:**
- Email address: collected, not shared, required, "for account
  management"
- Name: collected (optional, in sign-up form), not shared, optional

**Messages:**
- Messages: collected (chat with the agent), not shared, required

**Files and docs:**
- Files and docs: collected (attachments), not shared, required

**App activity:**
- Crash logs: collected, **shared with Sentry**, optional, for
  diagnostics

**Device or other IDs:** No.

**Is data encrypted in transit?** Yes (HTTPS / TLS 1.2+).

**Can users request data deletion?** Yes —
`support@digitalharbor.com.sa`.

> **Don't lie here.** Google scans the APK and reverse-engineers it.
> A Data Safety mismatch = automatic suspension on detection.

### 5.3 Content rating questionnaire

In Play Console: `App content → Content ratings`.

Answers for Saqqar:
- Violence / sexual content / drugs / hate speech: **No** to all
- User-generated content: **Yes** (chat messages, but private to the
  account)
- Sharing of user location: **No**
- Digital purchases: **No**
- Web access from app: **Yes** (the agent fetches Odoo data)

Expected rating: **Everyone / PEGI 3**.

### 5.4 Target audience

`App content → Target audience and content`:
- **Target age group:** 18 and over (this is a business app)
- **Appeals to children:** No

This sidesteps COPPA / Designed for Families requirements.

### 5.5 App access (Google reviewer access)

`App content → App access`.

Saqqar requires a real Odoo backend to do anything meaningful. Provide
the reviewer access:

- **All app functionality is available without restrictions:** No
- **Provide instructions to access restricted parts:** Yes
- **Username:** `reviewer@digitalharbor.com.sa` (create a test
  account on saqqaar.com with a demo Odoo instance attached)
- **Password:** [the test account password]
- **Any other info:** "Sign in with the credentials above. The app
  connects to a demo Odoo instance pre-seeded with sample data. All
  features (chat, reports, vault) are available without further
  setup."

### 5.6 Ads, news, COVID-19, government, etc.

All **No**.

### 5.7 Government election & financial services declarations

All **No**.

---

## Stage 6 — Upload to Play Console (staged rollout)

The recommended path: **Internal testing → Production**. Skip Closed
testing since the company account is already trusted (not a brand-new
personal account).

### 6.1 Create the app entry

`All apps → Create app`:

- **App name:** `Saqqar — Odoo Copilot`
- **Default language:** English (United States)
- **App or game:** App
- **Free or paid:** Free
- Accept the declarations

### 6.2 Fill the Store listing

`Store presence → Main store listing`:

- **App name:** `Saqqar — Odoo Copilot` (max 30 chars)
- **Short description:** see [STORE_LISTING.md](./STORE_LISTING.md)
- **Full description:** see [STORE_LISTING.md](./STORE_LISTING.md)
- **App icon:** upload `icon.png`
- **Feature graphic:** upload `feature.png`
- **Phone screenshots:** upload 8 phone screenshots
- **App category:** Business
- **Tags:** Business → Productivity, Communication
- **Contact details:**
  - Email: `support@digitalharbor.com.sa`
  - Phone: (company support number)
  - Website: `https://digitalharbor.com.sa`
- **Privacy Policy:** `https://digitalharbor.com.sa/privacy-saqqar`

### 6.3 Add the Arabic translation

`Store presence → Store listings`:
- Click `Manage translations → Add your own translations`
- Select **Arabic** (`ar`)
- Paste the Arabic strings from
  [STORE_LISTING.md](./STORE_LISTING.md)

### 6.4 Internal testing release

`Testing → Internal testing → Create new release`:

- **Upload `app-release.aab`** (drag the file)
- **Release name:** `1.0.0 (1)` (auto-filled from the AAB)
- **Release notes:** copy from
  [RELEASE_NOTES_TEMPLATE.md](./RELEASE_NOTES_TEMPLATE.md)
- **Testers:** create an `Internal testers` list and add team Gmails

Click `Save → Review release → Start rollout to Internal testing`.

Google reviews internal-track releases in **2–24 hours**. The team
will get an opt-in link by email.

### 6.5 Burn down the test list

Spend at least 3 days on internal testing. During that window:
- Watch Sentry for any crashes
- Verify sign-in works on a real device (not just emulator)
- Confirm the Odoo deep-think flow syncs back to the web
- Test on at least one slow-internet connection
- Test in Arabic AND English

If anything fails: fix → bump `version` in `pubspec.yaml` to
`1.0.0+2` (or `1.0.1+2`) → rebuild AAB → upload as a new internal
release.

### 6.6 Production release

When internal testing is clean:

`Production → Create new release`:

- Re-upload the same AAB (Play knows it's already reviewed but the
  Production track needs its own submission)
- Reuse the release notes from internal
- **Rollout percentage:** start at **20%** for the first 3 days, then
  scale to 50% for 2 days, then 100%

Click `Review → Start rollout to production`.

Google's first production review can take **3–7 days** for a brand-new
app. Subsequent updates are usually approved within 24h.

---

## Stage 7 — Post-launch operations

### Watch Sentry daily for the first week

Open the Sentry dashboard at least once a day. Look for:
- **New issue spikes** — a regression slipped through testing
- **Error frequency growing** — a backend change broke a code path
- **Specific OS / device clusters** — a Samsung-only bug, an Android
  7-only bug, etc.

### Respond to reviews within 24h

Play Store's algorithm boosts apps with responsive developers. Use
the **Reviews** tab in Play Console; respond in the language of the
review (Arabic to Arabic, English to English).

### Plan the next release cadence

A healthy mobile app ships every 2–4 weeks. Each release:
- Bump `version` in `pubspec.yaml`: `1.0.0+1` → `1.0.1+2` (patch) or
  `1.1.0+2` (minor)
- Rebuild AAB
- Upload as a new Internal release, soak for 2–3 days, then promote
  to Production with a 20% → 100% rollout
- Update release notes per language

---

## Common mistakes that delay the first ship

1. **`com.example.*` application ID** — Play rejects the upload.
   (We're already on `sa.com.digitalharbor.saqqar` — non-issue.)
2. **Forgetting `--dart-define=SAQQAR_SENTRY_DSN=…`** — the app
   builds fine but no crashes reach Sentry. Test by intentionally
   triggering an error before going to Production.
3. **Privacy policy URL not live** — Play Console accepts the URL
   but the review fails. Host it before filing the listing.
4. **Data Safety form mismatch** — if you say "no data collected"
   and Sentry is wired, Google scans, mismatches, suspends.
5. **Screenshots with placeholder data** — `Test User`, `Lorem
   ipsum` etc. Always use realistic-looking but anonymized data.
6. **Forgetting reviewer access credentials** — Google can't sign
   in, app gets rejected as "non-functional".

---

## Reference: companion docs in this repo

- [PRIVACY_POLICY.md](./PRIVACY_POLICY.md) — privacy policy markdown,
  hand to legal then host on `digitalharbor.com.sa`
- [STORE_LISTING.md](./STORE_LISTING.md) — English + Arabic store
  text ready to copy-paste into Play Console
- [RELEASE_NOTES_TEMPLATE.md](./RELEASE_NOTES_TEMPLATE.md) — release
  notes shape for each version bump

---

## Things to avoid (account-protection)

These cause **automatic suspension**, not just rejection — once
triggered, the entire developer account can be banned:

1. **Trademarked names / logos** you don't own — don't put "Odoo" in
   the app icon, only mention it in description text
2. **Misleading screenshots** — Google's image classifier flags fake
   UI mockups
3. **Lying in Data Safety** — already covered
4. **Bypassing Google Play Billing** for any in-app purchase or
   subscription — Saqqar is free, so this is non-issue, BUT if you
   ever add subscriptions later, use Play Billing exclusively
5. **Multiple developer accounts from the same legal entity** — Play
   bans related accounts. The company has one account; stay on it
6. **Hidden permissions** — every permission in the AndroidManifest
   gets parsed. Remove anything unused; the current set
   (INTERNET, ACCESS_NETWORK_STATE, READ_MEDIA_*) is justified
7. **Background services** that the user doesn't expect — Saqqar
   doesn't have any (polling stops when app is backgrounded since the
   lifecycle observer landed)

For broader Play Store policy violations and how to appeal a
suspension, see
[support.google.com/googleplay/android-developer](https://support.google.com/googleplay/android-developer/answer/9888379).
