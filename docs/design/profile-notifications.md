# Profile and notification implementation contract

Prepared 2026-10-31. Local implementation; no deployment authorized.

Reuse: existing avatar cropper, profile autosave, shadcn Base UI primitives,
social graph/report repositories and V8 migration, Trip profile pins/V24,
authenticated API proxy and TanStack Query keys. Preserve concurrent palette,
planner, password-policy and comment-connector work.

Visual direction: a travel cover above a portrait and left-aligned identity;
quiet settings with horizontal section navigation on phones. Retain Plus Jakarta
Sans. Reuse primary journey blue (#2477D4), people teal (#167D8D), plan violet
(#7851A9), nature green (#35784C), food gold (#B57A13), and ink (#203044) through
existing semantic variables and their dark variants. Interests carry their
category colors; unread rows have a visible dot and text as well as color.
Avoid repeating decorative cards: one cover/identity composition, then content
tabs. Forms use explicit saving for new public fields and retain the existing
separate display-name autosave. Banner cropping is 3:1, avatars remain square.

```
Desktop: cover / portrait + identity + follow / interests + connections / tabs
Mobile:  cover / portrait / identity / actions / scrollable tabs / content
Inbox:  title + unread filter + mark all / dated rows + individual read / more
```

Reliability contract: publication and outbox commit together; a bounded relay
uses SKIP LOCKED and waits for broker acknowledgment. Consumer stores durable
jobs before acknowledgment; batches resume using recipient UUID keys. Event-time
follow timestamps exclude later followers. Recipient/business-key uniqueness
protects the compatibility announcement endpoint. Current authority is checked
before delivery and on inbox reads. SSE carries only hints, with periodic durable
inbox reconciliation; no replay-cursor guarantee. Streams have bounded duration,
heartbeat, connection limits and authentication expiry. UI reconciliation never
invalidates planner state or navigates automatically.

Verification must distinguish mocks, real Postgres/Kafka, authenticated browser,
and deployed-proxy evidence. Optional Garage consent and substantial-update
announcements require separate explicit controls before being called complete.
