# Live notifications: Kafka delivery and SSE

How a followed traveller's newly listed plan reaches an open browser, and what to do when part of the path is down. Implementation of Phases 7 and 8 of `docs/agents/notification-plan.md`.

## Path

```
Owner lists a plan on Explore under their name (Trip, one transaction)
  -> trip.trip_publication row + trip.outbox row (SharedPlanListed.v1)
  -> TripOutboxRelay (every 2 s) -> Kafka trip.events.v1, key = publication id
  -> Community TripEventsListener (group community-notifications)
  -> TripEventProcessor: dedupe by event id, ask Trip whether still listed,
     insert notif.processed_events + notif.notifications in one transaction
  -> after commit: NotificationStreamHub sends "inbox.changed" to the follower's streams
  -> browser: Next.js /api/notifications/stream -> gateway -> Community /v1/notifications/stream
  -> NotificationLiveProvider refetches unread count and newest unread items, shows a toast
```

Follows and new community posts never touch Kafka: Community creates those notifications in the same transaction as the follow or post, and signals the stream after commit.

## Rules that matter

| Rule | Where |
| --- | --- |
| Only a transition into "active, listed on Explore, has a byline" emits. Autosaves, private edits, link-only shares, anonymous listings, unlisting and updates to a plan that stays listed emit nothing. Relisting the same link emits again; Community's `plan:<token>` dedupe key keeps followers from hearing twice. | `PublicationEvents` (Trip) |
| Payload holds identifiers only: publication, trip, owner, token, revision, listedAt. Titles are read from Trip at delivery time. | `PublicationEvents` |
| An event id is fixed when staged; retries and replays resend the same id. | `trip.outbox.id` |
| A plan unlisted, revoked or made anonymous before delivery notifies nobody (`NOT_LISTED`). | `TripEventProcessor` |
| Only accounts following the owner at `listedAt` are notified. | `NotificationRepository.notifyFollowersOfPlan` |
| Events older than 3 days are recorded as `STALE` and not delivered, so a backlog never floods inboxes. | `navio.notifications.trip-events.max-age` |
| Blocks, per-person alerts, type preferences and the 3-per-hour burst cap apply as to every notification. | SQL in `NotificationRepository` |
| Stream frames carry no content; counts and items come from the authorised REST API. | `NotificationStreamHub` |
| A stream ends when its access token expires (30 min cap); 5 streams per account (oldest closed), 500 per instance (503 + `Retry-After`). | `navio.notifications.stream.*` |
| Toasts never move focus; on `/planner/<id>` the View link opens a new tab. Seeing a toast does not mark it read; opening it does. | `NotificationToaster` |
| One browser holds one stream (Web Locks); other tabs get signals over BroadcastChannel. | `NotificationLiveProvider` |

## Switches

| Property (env) | Default | Effect when off |
| --- | --- | --- |
| `navio.outbox.relay.enabled` (`TRIP_OUTBOX_RELAY_ENABLED`) | true | Events accumulate in `trip.outbox`; nothing is lost. |
| `navio.notifications.trip-events.enabled` (`COMMUNITY_TRIP_EVENTS_ENABLED`) | true | Consumer stops; offsets stay where they were and resume later. |
| `navio.notifications.stream.enabled` (`COMMUNITY_NOTIFICATION_STREAM_ENABLED`) | true | `/v1/notifications/stream` is gone (404). The inbox, bell polling (60 s) and refetch on focus keep working. |
| `navio.notifications.legacy-plan-announcements.enabled` (`COMMUNITY_LEGACY_PLAN_ANNOUNCEMENTS`) | false | `POST /v1/notifications/plan-shared` still verifies ownership and answers `{"notified":0}`. Turn on only if the Trip relay is off. |

## Health signals

Prometheus (scraped from each service's `/actuator/prometheus`):

- `navio_outbox_pending`, `navio_outbox_oldest_age_seconds` (Trip): a growing age means Kafka or the relay is down.
- `navio_outbox_stuck` (Trip): rows that stopped retrying after 12 attempts (backoff 2 s doubling to 10 min).
- `navio_notifications_events_quarantined` (Community): records waiting for an operator.
- `navio_notifications_streams_active` (Community): open streams on this instance.

Consumer lag: `kafka-consumer-groups --bootstrap-server kafka:9092 --describe --group community-notifications` inside the Kafka container.

## Runbooks

**Kafka down.** Publishing keeps working (an outage test returned 200 in 230 ms); events wait in `trip.outbox` with `last_error` set. When Kafka returns, rows drain as their backoff expires (at most 10 minutes). Nothing to do unless `navio_outbox_stuck` rises.

**Stalled or stuck outbox rows.** Inspect: `SELECT id, event_type, attempt_count, last_error FROM trip.outbox WHERE published_at IS NULL ORDER BY created_at;`. After fixing the cause, retry with the same event ids: `UPDATE trip.outbox SET attempt_count = 0, next_attempt_at = now() WHERE published_at IS NULL;`.

**Replay a published event** (for example after the consumer was off longer than topic retention): `UPDATE trip.outbox SET published_at = NULL, attempt_count = 0, next_attempt_at = now() WHERE id = '<event id>';`. Community recognises an event it already processed and notifies nobody twice. Published rows are kept 14 days.

**Poison or quarantined events.** A malformed record is quarantined at once; a valid one is retried for about 2.5 minutes (1 s doubling to 30 s) before quarantine. The partition then moves on. List them as a platform ADMIN or OWNER: `GET /v1/admin/notification-events`. Replay one: `POST /v1/admin/notification-events/{id}/replay`. A still-malformed record answers 422 and stays open.

**Stream buffered or cut by a proxy.** Frames must arrive incrementally. NGINX: `location = /api/notifications/stream` and `= /v1/notifications/stream` set `proxy_buffering off` and `proxy_read_timeout 65s`; heartbeats every 25 s keep the connection alive. Both Community and the Next.js route also send `X-Accel-Buffering: no`. Check with `curl -N` through the edge and look for `:hb` lines every 25 s.

**Sessions expiring.** The stream closes at token expiry; the browser reconnects through the Next.js route, which refreshes the Auth.js session. A refused reconnect (signed out) closes the EventSource and the provider backs off 5 s doubling to 5 minutes.

**Disable live delivery.** Set `COMMUNITY_NOTIFICATION_STREAM_ENABLED=false` and restart Community. The durable inbox is unaffected.

## Known limits

- Live hints reach streams held by the Community instance that committed the notification. Production runs one instance. Before scaling Community out, add a broadcast between instances (for example a Kafka topic each instance consumes with its own group); the inbox itself stays correct either way.
- Plan fan-out is one `INSERT ... SELECT` per event in one transaction. Fine for current follower counts; very large audiences would need paged fan-out jobs.
- Closed-app delivery (Web Push, email) is not built.
- The Next.js stream route was exercised by build and type checks and the Community endpoint end to end, but not yet through a signed-in browser session against the deployed stack.
