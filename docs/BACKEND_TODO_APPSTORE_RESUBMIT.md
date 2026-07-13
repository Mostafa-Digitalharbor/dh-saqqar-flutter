# Backend TODO — Apple Sign-In fix

## What to add

Add this bundle ID to the Apple allowlist:

```
sa.com.digitalharbor.saqqarapp
```

## Where

**Saqqar admin → `/settings/apple/` → Native app IDs**

Add the value above (keep the existing `com.saqqar.ai.web` — do not remove it).

## Why

Native Sign in with Apple sends an identity token whose `aud` = the app's bundle ID
(`sa.com.digitalharbor.saqqarapp`). The backend only accepts `com.saqqar.ai.web`
today, so `POST /api/v1/auth/apple/` rejects the token with **401** and sign-in fails.
Adding the bundle ID to the allowlist fixes it.

> بالعربي: ضيف `sa.com.digitalharbor.saqqarapp` في أدمن Saqqar → `/settings/apple/`
> → Native app IDs. ده اللي بيخلي Apple Sign-In يشتغل (حالياً بيرجّع 401).
