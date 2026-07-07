# Backend performance request — slow conversation endpoints

Measured live on 2026-07-06 (Android emulator, real account with ~89 conversations),
using the app's HTTP `LoggingInterceptor` which times each request → response
(server processing + network, **before** any client-side JSON parsing).

## Measured latencies (24 requests, right after sign-in)

| Metric | Value |
|---|---|
| Fastest request | **782 ms** (nothing was under 300 ms) |
| Median | **1,353 ms** |
| Average | **2,527 ms** |
| Requests 800–1500 ms | 15 |
| Requests > 1500 ms | 7 |
| **Slowest** | **29,024 ms** |

## The two problem endpoints

1. **`GET /api/v1/conversations/`** (Chats list) — took **29 seconds** to return
   ~89 conversation summaries. This is the first request after login; the list
   is unusable until it lands (mitigated on the client by painting the offline
   cache first, but a fresh/cold account still waits).

2. **`GET /api/v1/conversations/<id>/`** (open a chat) — took **13.5 seconds**
   for a single conversation snapshot. Mitigated on the client by a
   cache-first paint for previously-opened chats, but the first open of any
   chat blocks on this.

## What the client already does (so this is NOT a client issue)

- Times measured are server+network only — client parsing happens off the UI
  isolate (`compute`) afterwards and is not included.
- List + chat both paint cached data instantly (stale-while-revalidate).
- Request volume on open is already minimized: the project·env enrichment is
  bounded to one screenful, snapshot prefetch is limited to the top 5, and the
  background poll runs at 20 s.

## Ask

Profile and optimize `GET /conversations/` and `GET /conversations/<id>/` on the
server. 13–29 s strongly suggests a per-conversation N+1 (or heavy per-row
computation/serialization) in the backend query. Two options that would help
the mobile client a lot:

1. Make `GET /conversations/` return in well under ~1 s for a few hundred rows,
   and **embed `project` / `environment` on each summary row** (so the client
   can drop its per-conversation enrichment fetches entirely).
2. Support real pagination (`limit` + `offset`/cursor) so the client can fetch a
   fast first page and load more on demand instead of pulling everything.
