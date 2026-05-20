# Web Client — `deep_think` toggle sync bug

> **TL;DR:** الباك إند والموبايل شغالين تمام. المشكلة في `static/odoo_agent/app.js` — الـtoggle بتاع "التفكير العميق" بيقرأ قيمته من `localStorage` فقط ومش بيتحدّث من `conversation.deep_think` اللي بترجع من السيرفر بعد كل GET. السطرين بتوع hydration الموجودين لـ`auto_approve` ناقصين لـ`deep_think`.

---

## السلوك الحالي

- على الموبايل: أكبس deep think → السيرفر بيستلم ويخزن صح (متأكدين من اللوجز).
- على الويب: أكبس deep think → الويب بيبعت `PATCH /api/conversations/<id>/` بـbody `{ "deep_think": true }` → السيرفر بيرد 200 OK ومعاه الـconversation كاملة فيها `"deep_think": true` (مأكد من DevTools).
- **لكن:** أعمل refresh للويب (أو افتح الشات من جديد) → الـtoggle بيرجع OFF حتى لو السيرفر مخزّن ON.
- نفس الكلام في الاتجاه التاني: لما أكبسه على الموبايل وأرجع للويب وأعمل refresh → الويب بيظهر القيمة القديمة من `localStorage`، مش القيمة الحقيقية من السيرفر.

النتيجة من وجهة نظر المستخدم: **التفكير العميق بيبان كأنه مش بيتزامن بين الجهازين**، رغم إنه على السيرفر متزامن فعلاً.

---

## الـscope اللي اتأكد منه

| الطبقة | الحالة | الدليل |
|---|---|---|
| الموبايل بيبعت PATCH صح | ✅ شغّال | لوج Dio بيوريّ `{ "deep_think": true/false }` |
| السيرفر بيخزّن وبيرجّع الـecho صح | ✅ شغّال | PATCH response بيرجّع `"deep_think": <new value>` |
| السيرفر بيرجّع القيمة في GET snapshot | ✅ شغّال | لوج `getSnapshot` بيوريّها على الـtop-level |
| الموبايل بيقرأ القيمة ويعكسها في الـUI | ✅ شغّال | `Conversation.deepThink` بتُستخدم لتغذية الـtoggle |
| الويب بيبعت PATCH صح | ✅ شغّال | Payload في DevTools: `{ "deep_think": false }`، Response: `"deep_think": false` |
| **الويب بيقرأ القيمة من الـconversation snapshot ويعكسها على الـtoggle** | ❌ **هنا الـbug** | الـtoggle بيرجع لقيمة `localStorage` بعد الـrefresh |

---

## الكود اللي فيه المشكلة

في `odoo_agent/static/odoo_agent/app.js`، داخل `bindEvents()`:

```javascript
if (elements.deepThinkToggle) {
    const storedDT = window.localStorage.getItem("saqqar.deepThink") === "1";
    state.deepThink = storedDT;
    elements.deepThinkToggle.checked = storedDT;   // ← localStorage فقط

    elements.deepThinkToggle.addEventListener("change", async () => {
        state.deepThink = elements.deepThinkToggle.checked;
        if (state.conversation && state.conversation.conversation) {
            state.conversation.conversation.deep_think = state.deepThink;
        }
        window.localStorage.setItem("saqqar.deepThink", state.deepThink ? "1" : "0");
        if (state.conversationId) {
            try {
                await api(`/api/conversations/${state.conversationId}/`, {
                    method: "PATCH",
                    body: JSON.stringify({ deep_think: state.deepThink }),
                });
            } catch (_e) {}
        }
    });
}
```

**المشكلة:** الـbinding ده بيشتغل مرة واحدة عند تحميل الصفحة الأول. بيقرأ من `localStorage` ويضع القيمة على الـcheckbox. مفيش أي مكان تاني في الكود بيحدّث `elements.deepThinkToggle.checked` من `state.conversation.conversation.deep_think` بعد ما الـsnapshot تيجي من السيرفر.

في المقابل، `auto_approve` شغّال لأن في كود hydration بيـsync `autoApproveToggle.checked` من `state.conversation.conversation.auto_approve` بعد كل `loadConversation()` / GET للـconversation.

---

## الفيكس المطلوب

في الفنكشن اللي بتـrender الـconversation (أو داخل `loadConversation()` بعد ما الـsnapshot تتحط في `state.conversation`)، أضف نفس الـhydration اللي معمول لـ`auto_approve` لكن لـ`deep_think`:

```javascript
// Hydrate deep-think toggle from the server-authoritative value so the
// switch reflects what the conversation is actually using (mirroring
// auto_approve hydration). Keep localStorage as a local cache for the
// first paint before the snapshot arrives, but the server value wins
// whenever it's present.
if (elements.deepThinkToggle && state.conversation?.conversation) {
    const serverDT = !!state.conversation.conversation.deep_think;
    elements.deepThinkToggle.checked = serverDT;
    state.deepThink = serverDT;
    window.localStorage.setItem("saqqar.deepThink", serverDT ? "1" : "0");
}
```

ضعه في نفس المكان اللي فيه السطر:
```javascript
elements.autoApproveToggle.checked = state.conversation.conversation.auto_approve;
```
(أو ما يعادله — أينما كان الكود ده موجود).

---

## خطوات الاختبار بعد الفيكس

### اختبار ١ — Mobile → Web

1. على الموبايل، افتح شات وكبّس deep think → ON.
2. على الويب، افتح نفس الشات (أو اعمل refresh).
3. **النتيجة المتوقعة:** الـtoggle على الويب يبان ON تلقائياً.

### اختبار ٢ — Web → Mobile

1. على الويب، كبّس deep think → ON.
2. على الموبايل، افتح نفس الشات (أو استنّى لحد ١٥ ثانية لو هو فاتح أصلاً، عشان الـpolling يلتقط القيمة الجديدة).
3. **النتيجة المتوقعة:** الـtoggle على الموبايل يبان ON.

### اختبار ٣ — Refresh on Web

1. على الويب، كبّس deep think → ON.
2. اعمل refresh للصفحة (F5).
3. **النتيجة المتوقعة:** الـtoggle يفضل ON بعد الـrefresh (دلوقتي بيرجع OFF — ده الـbug).

---

## ملاحظات إضافية

- المسار اللي الويب بيبعت عليه `/api/conversations/<id>/` (مش `/api/v1/`) — شغّال صح، الباك إند بيقبل deep_think على المسارين. مش محتاج تتغيّر.
- الـbackend whitelist بيشيل أي حاجة برّا `title / is_archived / auto_approve / deep_think / environment_id` — ده مظبوط، مفيش تغيير مطلوب.
- الموبايل بقى بيبعت `{ "deep_think": value }` على الـtop-level بس (شيلنا الـ`context` المُكرّر) — مطابق للعقد.
- بعد الفيكس، الـlocalStorage على الويب يفضل لو عايزينه كـcache للـfirst-paint قبل ما السنابشوت تيجي، لكن قيمة السيرفر هي المرجع.
