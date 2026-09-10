# Navio — Community Roles and Authorization

**Status:** As-built audit of `server/community-service` + `server/api-gateway`, 2026-09-09
**Scope:** Group ownership, group editing, membership, and posting rights inside the `social` domain.
**Purpose:** Establish the agreed rule set *before* the backend changes for "only the owner can edit a community" and "only members can post" are written.

---

## 1. Where authorization actually happens

Authorization in Navio is split across three layers. Knowing which layer owns which decision matters, because two of the three are currently doing less than they look like they are.

| Layer | Component | Decides |
| --- | --- | --- |
| 1. Authentication | `api-gateway` → Keycloak JWT | *Who is calling.* Signature, issuer, expiry, and audience are all verified ([GatewaySecurityConfig.java:118-129](server/api-gateway/src/main/java/com/navio/apigateway/security/GatewaySecurityConfig.java#L118-L129)). |
| 2. Coarse route gate | `api-gateway` | *Whether the route needs a login at all.* Deny-by-default, with a short public allowlist ([GatewaySecurityConfig.java:87-95](server/api-gateway/src/main/java/com/navio/apigateway/security/GatewaySecurityConfig.java#L87-L95)). |
| 3. Resource authorization | `community-service` | *What this user may do to this group.* All group-scoped rules live here. |

### The identity contract

The gateway strips every client-supplied `X-User-Id`, `X-User-Roles`, and `X-User-Email` header unconditionally, then re-injects them from the validated token ([IdentityPropagationFilter.java:78-121](server/api-gateway/src/main/java/com/navio/apigateway/security/IdentityPropagationFilter.java#L78-L121)). `X-User-Id` is the Keycloak `sub`.

**This holds only while `community-service` is unreachable except through the gateway.** The service itself has no `spring-boot-starter-security` dependency and no `JwtDecoder` — it trusts `X-User-Id` completely. If port 8084 is ever exposed on a network an attacker can reach, every rule in this document collapses to "send whatever UUID you like". `user-management-service` does not have this weakness; it ignores `X-User-Id` and reads identity from the JWT itself.

Missing `X-User-Id` on a write route returns **401**, not 400 ([GlobalExceptionHandler.java:23-26](server/community-service/src/main/java/com/navio/communityservice/exception/GlobalExceptionHandler.java#L23-L26)).

---

## 2. The actor model

There are two independent role systems. They do not currently talk to each other.

### 2.1 Global roles (Keycloak)

`USER`, `MODERATOR`, `ADMIN` — allowlisted in [NavioRole.java](server/user-management-service/src/main/java/com/navio/usermanagementservice/security/NavioRole.java) and mirrored into `X-User-Roles`.

> **`community-service` never reads `X-User-Roles`.** A platform `ADMIN` has exactly the same rights inside a community group as an anonymous visitor who just signed up. This is deliberate per the `NavioRole` doc comment ("resource-scoped roles belong to the owning domain service"), but it means there is currently *no* staff override for an abandoned or abusive group.

### 2.2 Group-scoped roles (`social.group_memberships.role`)

| Role | Assigned by | Meaning today |
| --- | --- | --- |
| `admin` | Automatically, to the group creator only ([GroupService.java:33](server/community-service/src/main/java/com/navio/communityservice/service/GroupService.java#L33)) | Founder/owner |
| `moderator` | `PUT /v1/groups/{slug}/moderators` | Appointed staff |
| `member` | Default on join | Ordinary participant |

**`admin` and `moderator` are treated as identical everywhere.** `MODERATOR_ROLES = List.of("moderator", "admin")` and `requireModerator` is the only check in the service ([GroupAccessService.java:13-22](server/community-service/src/main/java/com/navio/communityservice/service/GroupAccessService.java#L13-L22)). Nothing anywhere asks "is this the founder?" — `groups.created_by_user_id` is stored and returned in the detail payload, but is never used in a decision.

### 2.3 Membership states (`social.group_memberships.state`)

| State | Set by | Effect |
| --- | --- | --- |
| `joined` | `POST /members/me` | Active member |
| `muted` | `PATCH /members/me` | Active member who silenced *their own* notifications. Still counts as active, still moderates. This is a personal preference, **not** a moderation penalty. |
| `left` | `DELETE /members/me` | Inactive; row retained so history and role survive a re-join |
| `banned` | **nothing** | Blocks join/leave/mute if present, but **no endpoint can ever set it** |

`ACTIVE_STATES = ("joined", "muted")` is the definition of "is a member" throughout.

---

## 3. Current capability matrix — groups

Legend: **✅** allowed · **❌** blocked · **⚠️** allowed but shouldn't be

| Capability | Endpoint | Anonymous | Signed-in non-member | Member | Moderator | Founder (`admin`) |
| --- | --- | :-: | :-: | :-: | :-: | :-: |
| Discover active groups | `GET /v1/groups` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Search active groups | `GET /v1/groups/search` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Read group detail | `GET /v1/groups/{slug}` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Read a **hidden** group | `GET /v1/groups/{slug}` | ❌ 404 | ❌ 404 | ❌ 404 | ✅ | ✅ |
| List my groups | `GET /v1/groups/mine` | ❌ 401 | ✅ (empty) | ✅ | ✅ | ✅ |
| Create a group | `POST /v1/groups` | ❌ 401 | ✅ | ✅ | ✅ | ✅ |
| Join / leave | `*/members/me` | ❌ 401 | ✅ | ✅ | ✅ | ⚠️ blocked if last mod |
| Mute / unmute self | `PATCH /members/me` | ❌ 401 | ❌ 403 | ✅ | ✅ | ✅ |
| **List members** | `GET /{slug}/members` | ❌ 401 | ❌ 403 | ❌ 403 | ✅ | ✅ |
| **Edit profile (incl. banner picture)** | `PATCH /{slug}/profile` | ❌ 401 | ❌ 403 | ❌ 403 | ✅ | ✅ |
| **Replace rules** | `PUT /{slug}/rules` | ❌ 401 | ❌ 403 | ❌ 403 | ✅ | ✅ |
| **Replace flairs** | `PUT /{slug}/flairs` | ❌ 401 | ❌ 403 | ❌ 403 | ✅ | ✅ |
| **Replace resources** | `PUT /{slug}/resources` | ❌ 401 | ❌ 403 | ❌ 403 | ✅ | ✅ |
| **Replace moderators** | `PUT /{slug}/moderators` | ❌ 401 | ❌ 403 | ❌ 403 | ⚠️ ✅ | ✅ |
| Rename group | *none* | ❌ | ❌ | ❌ | ❌ | ❌ **not possible** |
| Archive / delete group | *none* | ❌ | ❌ | ❌ | ❌ | ❌ **not possible** |
| Ban / unban a member | *none* | ❌ | ❌ | ❌ | ❌ | ❌ **not possible** |
| Transfer ownership | *none* | ❌ | ❌ | ❌ | ❌ | ❌ **not possible** |

### What "edit their community, such as adding a picture" means today

`PATCH /v1/groups/{slug}/profile` is moderator-gated and can change: `description`, `country`, `places`, `tags`, `summary`, `bannerUrl`, `bannerMediaId` ([GroupContentService.java:22-43](server/community-service/src/main/java/com/navio/communityservice/service/GroupContentService.java#L22-L43)).

So **the core of the requirement is already satisfied**: a random user genuinely cannot edit someone else's group. What is missing is spelled out in §5.

---

## 4. Current capability matrix — posts

**There is no post surface. At all.**

`social.groups.post_count` exists as a column, the API docs route `/v1/posts/**` to this service, and [Navio Database.md §11.2-11.8](docs/database/Navio%20Database.md) fully specifies `posts`, `comments`, `post_votes`, `comment_votes`, `post_views`, `bookmarks`, and `reports`. But migration `V2__create_social_group_tables.sql` stops at group tables, and the service has exactly one controller (`GroupController`).

| Capability | Status |
| --- | --- |
| Create a post | Not implemented |
| Comment / reply | Not implemented |
| Vote | Not implemented |
| Bookmark | Not implemented |
| Report | Not implemented |
| Moderate (hide/remove) content | Not implemented |

**Consequence for this task:** the rule *"a user who has not joined a group cannot post in it"* has nowhere to live yet. It cannot be "fixed" — the posting feature has to be built, and the membership gate is one clause inside it. This is a build, not a patch, and it should be sized accordingly.

---

## 5. Findings

Ordered by severity. Each is a real gap against the two rules requested, or against the trust model those rules assume.

### F1 — A moderator can strip the founder of the group (privilege escalation) · **High**

`replaceModerators` collects everyone with `role IN ('moderator','admin')` as `previous`, then demotes to `member` anyone not in the submitted list ([GroupModerationService.java:36-38](server/community-service/src/main/java/com/navio/communityservice/service/GroupModerationService.java#L36-L38)). The founder's `admin` row is in that set.

**Attack:** founder appoints a moderator → that moderator sends `PUT /moderators` with only their own id → the founder becomes a plain `member` and permanently loses the ability to edit their own community. There is no recovery path, because no endpoint can restore a moderator and no platform admin override exists.

This directly contradicts *"the user that created the community can edit their community; other people cannot."*

### F2 — `community-service` performs no token validation of its own · **High**

No security starter, no `JwtDecoder`, no `SecurityFilterChain`. Every authorization decision rests on a header. The gateway defends this correctly today, but the service has zero defence in depth, and it is the only Navio service in that position. One misconfigured Docker port publish, one debug route, one future direct service-to-service call, and group ownership is bypassable with `curl -H 'X-User-Id: <founder-uuid>'`.

### F3 — No posting authorization exists because posting does not exist · **High (scope)**

See §4. The requested rule requires implementing `social.posts` + a `PostController` before it has any surface to attach to.

### F4 — `archived` groups are still fully writable · **Medium**

`visible()` blocks only `status = 'hidden'` ([GroupAccessService.java:31-34](server/community-service/src/main/java/com/navio/communityservice/service/GroupAccessService.java#L31-L34)). An `archived` group still accepts joins, profile edits, rule replacement, and moderator changes. Archive currently means "hidden from discovery lists" and nothing more.

### F5 — `banned` is unreachable state · **Medium**

The DB constraint allows it and `join`/`leave` both honour it ([GroupMembershipService.java:21,36](server/community-service/src/main/java/com/navio/communityservice/service/GroupMembershipService.java#L21-L36)), but nothing can set it. Moderators have no removal tool whatsoever — they can edit the group's cosmetics but cannot act on a person. Once posting ships, this becomes the primary missing moderation lever.

### F6 — Founder identity is stored but never authoritative · **Medium**

`groups.created_by_user_id` is immutable and surfaced in `GroupDetailResponse`, but participates in no decision. The `admin` role on the membership row is the *de facto* owner marker, and per F1 it is mutable by others. Owner and moderator need to be genuinely distinct capabilities.

### F7 — `bannerMediaId` accepts any UUID with no ownership or existence check · **Medium**

`setBannerMediaId` takes a bare `UUID` with no validation ([UpdateGroupProfileRequest.java:33-35](server/community-service/src/main/java/com/navio/communityservice/dto/UpdateGroupProfileRequest.java#L33-L35)), there is no `media` table in any migration, and no upload endpoint exists despite `navio.community.media.storage-path` being configured. "Adding a picture" today means pasting an external URL. When media lands, this field needs an existence + uploader-ownership check or one group can reference another's asset.

### F8 — `bannerUrl` allows any external host · **Low**

`@Pattern(regexp = "https?://[^\\s]+")` correctly blocks `javascript:` and `data:`, but permits any origin. A moderator can point a community banner at a host that logs every viewer's IP. Consider an allowlist or a proxy/CDN rewrite once media upload exists.

### F9 — Group name and slug can never be changed · **Low**

Both are `updatable = false` ([Group.java:19-22](server/community-service/src/main/java/com/navio/communityservice/model/Group.java#L19-L22)). Immutable slugs are a defensible choice (stable URLs); an immutable **display name** is probably not what users expect from "edit my community".

### F10 — No platform-staff override · **Low (by design, worth a decision)**

Per §2.1, a global `ADMIN` cannot act on any group. Combined with F1 and F5, a hijacked or abandoned group has no remedy short of direct SQL.

---

## 6. Target rule set

The rules below are what the implementation should enforce. Rows marked **NEW** are changes from §3.

### 6.1 Group editing

| Action | Owner (`admin`) | Moderator | Member | Non-member | Platform `ADMIN` |
| --- | :-: | :-: | :-: | :-: | :-: |
| Edit description / summary / tags / places / country | ✅ | ✅ | ❌ | ❌ | ✅ **NEW** |
| Edit banner picture | ✅ | ✅ | ❌ | ❌ | ✅ **NEW** |
| Rename group (display name) | ✅ **NEW** | ❌ **NEW** | ❌ | ❌ | ✅ **NEW** |
| Replace rules / flairs / resources | ✅ | ✅ | ❌ | ❌ | ✅ **NEW** |
| Appoint or remove moderators | ✅ | ❌ **NEW** | ❌ | ❌ | ✅ **NEW** |
| Be demoted by a moderator | ❌ **NEW (fixes F1)** | — | — | — | — |
| Transfer ownership | ✅ **NEW** | ❌ | ❌ | ❌ | ✅ **NEW** |
| Archive the group | ✅ **NEW** | ❌ | ❌ | ❌ | ✅ **NEW** |
| Ban / unban a member | ✅ **NEW** | ✅ **NEW** | ❌ | ❌ | ✅ **NEW** |
| Ban the owner | ❌ **NEW** | ❌ **NEW** | ❌ | ❌ | ✅ **NEW** |

**Core split:** moderators curate *content and people*; the owner controls *identity and the moderator roster*. That is the smallest change that makes "other people cannot edit my community" true in the sense the user means it.

### 6.2 Posting

| Action | Owner | Moderator | Member (`joined`/`muted`) | Non-member | `left` | `banned` | Anonymous |
| --- | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| Read posts in an active group | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Create a post** | ✅ | ✅ | ✅ | ❌ **403** | ❌ 403 | ❌ 403 | ❌ 401 |
| **Comment / reply** | ✅ | ✅ | ✅ | ❌ 403 | ❌ 403 | ❌ 403 | ❌ 401 |
| Vote | ✅ | ✅ | ✅ | ❌ 403 | ❌ 403 | ❌ 403 | ❌ 401 |
| Edit own post/comment | ✅ | ✅ | ✅ | — | — | ❌ | — |
| Delete own post/comment (`deleted_by_user`) | ✅ | ✅ | ✅ | — | ✅ | ❌ | — |
| Remove anyone's post (`deleted_by_mod`) | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Post in an `archived` group | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Bookmark / report | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ 401 |

Decisions embedded above, called out so they can be argued with:

1. **Read is public, write is member-only.** Matches the existing group model, where detail is anonymous-readable. Public discussions stay indexable and shareable.
2. **`muted` members can post.** `muted` is a self-applied notification preference, not a penalty (§2.3). Blocking it would be a bug.
3. **`left` members cannot post.** Re-joining is one idempotent call away.
4. **Bookmarking is not posting.** It is a private, non-visible action, so it does not require membership.
5. **Reporting does not require membership.** Requiring it would let a group suppress reports by keeping people out.
6. **The membership check re-reads the DB per write.** It is never taken from the request body or from a client-supplied flag.

### 6.3 Status interaction

| Group status | Read | Join | Post | Moderate | Edit profile |
| --- | :-: | :-: | :-: | :-: | :-: |
| `active` | everyone | ✅ | members | mods | mods/owner |
| `archived` | everyone | ❌ **NEW** | ❌ **NEW** | ❌ **NEW** | owner only **NEW** |
| `hidden` | mods only | ❌ | mods only | mods | mods/owner |

---

## 7. Suggested implementation order

1. **Fix F1 first — it is a two-line change and a real escalation.** Separate `requireOwner` from `requireModerator` in `GroupAccessService`, gate `replaceModerators` on ownership, and never demote a row whose `user_id = groups.created_by_user_id`.
2. **Add `requireActiveMember`** to `GroupAccessService` alongside the existing `requireModerator`. It is the single seam the posting rules hang from, and writing it now means the post feature has nowhere to get it wrong.
3. **Block writes on non-`active` groups** in `GroupAccessService.lock` (F4).
4. **Add ban/unban** (`PATCH /v1/groups/{slug}/members/{userId}`), moderator-gated, owner-immune (F5).
5. **Add owner-only rename + archive + transfer** (F6, F9) — requires dropping `updatable = false` on `Group.name` and a `V3` migration only if slug behaviour changes.
6. **Then** build `social.posts` behind `requireActiveMember` (F3). This is the large piece and should be its own phase.
7. **Consider adding resource-server security to `community-service`** (F2) so the header is corroborated rather than trusted.
8. Media ownership (F7) and banner host policy (F8) when the media module lands.

Each of 1–5 is independently shippable and testable against the existing `GroupServiceTest` / `GroupModerationServiceTest` suites.

---

## 8. Verified sources

| Claim | Source |
| --- | --- |
| Gateway JWT validation and header stripping | `api-gateway/.../GatewaySecurityConfig.java`, `IdentityPropagationFilter.java` |
| All group authorization rules | `community-service/.../service/GroupAccessService.java`, `GroupContentService.java`, `GroupModerationService.java`, `GroupMembershipService.java`, `GroupService.java` |
| Route surface | `community-service/.../controller/GroupController.java` |
| Roles, states, constraints | `community-service/.../db/migration/V2__create_social_group_tables.sql` |
| Global role model | `user-management-service/.../security/NavioRole.java`, `config/SecurityConfig.java` |
| No security dependency in community-service | `community-service/pom.xml` |
| Planned post schema | `docs/database/Navio Database.md` §11.2–11.8 |
| Documented endpoint list | `docs/api/Navio Api Documentation.md` lines 2318–2331 |
