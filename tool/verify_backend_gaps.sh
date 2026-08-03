#!/usr/bin/env bash
# Verify — against the LIVE backend — which of the gaps in
# docs/MOBILE_BACKEND_GAPS_CORE.md are still real.
#
# Those gaps were reproduced against a mock built from what the mobile code
# says the backend does. That is a strong signal, not proof: some may already
# be fixed. Run this before asking anyone to build anything.
#
# Usage:
#   1. Sign in on the web at saqqaar.com, open DevTools → Network, copy the
#      Authorization header value (the part after "Bearer ").
#   2. TOKEN=<paste> bash tool/verify_backend_gaps.sh
#
# Nothing here writes. Every call is a GET.

set -uo pipefail
BASE="${BASE:-https://saqqaar.com}"
: "${TOKEN:?set TOKEN=<bearer token> first}"
AUTH=(-H "Authorization: Bearer $TOKEN")

pass() { printf '  \033[32m✓ FIXED\033[0m   %s\n' "$1"; }
fail() { printf '  \033[31m✗ OPEN\033[0m    %s\n' "$1"; }
info() { printf '  \033[33m·\033[0m %s\n' "$1"; }

jqv() { python3 -c "import sys,json;d=json.load(sys.stdin);print($1)" 2>/dev/null || echo "?"; }

echo "── §3  Does GET /conversations/ carry per-row context? ─────────────"
LIST=$(curl -s "${AUTH[@]}" --max-time 30 "$BASE/api/v1/conversations/?limit=5")
ROW=$(echo "$LIST" | jqv "json.dumps(d.get('conversations',[{}])[0])")
for f in project environment files_count pending_approvals is_running; do
  if echo "$ROW" | grep -q "\"$f\""; then pass "list row has '$f'"; else fail "list row missing '$f'  → N+1 enrichment still needed"; fi
done

CONV_ID=$(echo "$LIST" | jqv "d.get('conversations',[{}])[0].get('id','')")
echo
echo "── conversation under test: ${CONV_ID:-<none>} ─────────────────────"
[ -z "$CONV_ID" ] && { echo "no conversations on this account — stop here"; exit 0; }

echo
echo "── §1  Does the snapshot honour ?limit= ? ──────────────────────────"
for L in 40 200; do
  N=$(curl -s "${AUTH[@]}" --max-time 60 "$BASE/api/v1/conversations/$CONV_ID/?limit=$L" | jqv "len(d.get('messages',[]))")
  info "asked limit=$L → got $N messages"
done
info "if both numbers are the SAME and small, the cap is real (gap §1 open)"

echo
echo "── §1b Is the paged messages endpoint implemented? ─────────────────"
# Specced in docs/backend-api-contract.md §GET /conversations/{id}/messages/
# back in May. If this returns 200 the whole paging gap is a CLIENT fix.
CODE=$(curl -s -o /tmp/_msgs.json -w "%{http_code}" "${AUTH[@]}" --max-time 30 \
  "$BASE/api/v1/conversations/$CONV_ID/messages/?limit=50")
if [ "$CODE" = "200" ]; then
  pass "GET .../messages/ returns 200 — has_more=$(jqv "d.get('has_more','?')" < /tmp/_msgs.json), results=$(jqv "len(d.get('results',[]))" < /tmp/_msgs.json)"
  info "→ §1 becomes a MOBILE task, no backend work needed"
else
  fail "GET .../messages/?limit= returned $CODE — cursor paging not available"
  info "→ ask backend for it; it is already specced in backend-api-contract.md"
fi

echo
echo "── §4  Does the snapshot carry conversation.plan? ──────────────────"
SNAP=$(curl -s "${AUTH[@]}" --max-time 60 "$BASE/api/v1/conversations/$CONV_ID/")
if echo "$SNAP" | grep -q '"plan"'; then pass "snapshot has 'plan' → quota banner works"; else fail "snapshot has no 'plan' → no quota warning in chat"; fi
if echo "$SNAP" | grep -q '"deep_think"'; then pass "snapshot has 'deep_think'"; else fail "snapshot has no 'deep_think' (backend-requests.md §1)"; fi

echo
echo "── §6  Do approvals carry human labels? ────────────────────────────"
APR=$(curl -s "${AUTH[@]}" --max-time 30 "$BASE/api/v1/approvals/?status=pending&limit=5")
CNT=$(echo "$APR" | jqv "len(d.get('approvals',[]))")
if [ "$CNT" = "0" ]; then
  info "no pending approvals on this account — cannot check model_label/record_count"
else
  if echo "$APR" | grep -q '"model_label"'; then pass "approvals carry 'model_label'"; else fail "approvals missing 'model_label' → card shows raw JSON"; fi
  if echo "$APR" | grep -q '"record_count"'; then pass "approvals carry 'record_count'"; else fail "approvals missing 'record_count'"; fi
fi

echo
echo "── §7  Is there a pin endpoint? ────────────────────────────────────"
CODE=$(curl -s -o /dev/null -w "%{http_code}" "${AUTH[@]}" --max-time 20 "$BASE/api/v1/conversations/$CONV_ID/pin/")
if [ "$CODE" = "404" ]; then fail "no pin endpoint (405 would mean it exists, wrong verb)"; else info "GET .../pin/ → $CODE (investigate)"; fi

echo
echo "── §8  Does logout reject a missing token? ─────────────────────────"
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST --max-time 20 "$BASE/api/v1/auth/logout/")
if [ "$CODE" = "401" ]; then pass "logout without token → 401"; else fail "logout without token → $CODE (should be 401)"; fi

echo
echo "Done. Anything marked OPEN is worth asking for; anything FIXED, delete"
echo "from docs/MOBILE_BACKEND_GAPS_CORE.md before sending it on."
