# Keycloak realm setup

`navio-realm.json` is imported on Keycloak's **first** start (`--import-realm`).
An existing realm is left untouched, so console changes survive redeploys. To
re-import after editing, delete the realm first or run
`kc.sh import --file ... --override true`.

JSON has no comments, so the reasoning behind each choice lives here.

## The one setting that breaks everything if missed

The **`navio-api-audience` protocol mapper** on the `navio-web` client.

Keycloak does not put your API in the `aud` claim by default — it emits
`"aud": "account"`. Both the gateway and the user management service reject a
token whose audience is not `navio-api`. Without this mapper, **every request
fails with 401** and the cause is not obvious from the error, which is
deliberately generic.

Verify after import: decode an access token and confirm `aud` contains
`navio-api`.

## The second setting that breaks everything if missed

`navio-web` sets `fullScopeAllowed: false`, which is correct — but it means a
realm role reaches the token **only if that role is in the client's scope**. The
realm-level `scopeMappings` entry grants exactly `USER`, `MODERATOR` and `ADMIN`,
and `deploy.sh` reasserts it on every run.

Miss it and Keycloak omits `realm_access` from the access token entirely. Nothing
returns an error: the gateway still admits plain authenticated calls, so sign-in
works, `/v1/users/me` returns 200, and the only symptom is `"roles": []` on every
profile with every MODERATOR and ADMIN feature silently unreachable.

Do not "fix" this by setting `fullScopeAllowed: true`. That puts every role the
user holds — including `realm-management` roles on an operator account — into a
token held by browser-facing infrastructure.

Verify after import: decode an access token and confirm `realm_access.roles`
contains `USER`.

## Service account permissions

`navio-user-management` is a confidential client whose service account performs
Admin API calls: disabling an account on suspension, revoking its sessions, and
granting or revoking the three Navio realm roles.

It is granted exactly two `realm-management` client roles:

| Role | Why |
| --- | --- |
| `manage-users` | Enable/disable accounts, revoke sessions, assign realm roles |
| `view-users` | Read a user's current role mappings before changing them |

**Do not grant `realm-admin`.** That role can rewrite clients, mappers, and the
authentication flow. With it, a leaked client secret escalates from "can suspend
users" to full control of the realm — including minting tokens for any account.

## Client secret

The realm file uses Keycloak's environment placeholder
`"secret": "${KEYCLOAK_ADMIN_CLIENT_SECRET}"`. The production compose file
passes that value from `.deploy/.env`, so the imported confidential client and
the user-management service always use the same secret without committing it.
Use a different, randomly generated value in every environment.

## Why the web client is confidential

`navio-web` uses Auth.js as a server-side backend-for-frontend, so the
authorization code is exchanged by the Next.js server rather than browser
JavaScript. The client is therefore confidential and its
`KEYCLOAK_WEB_CLIENT_SECRET` must also be configured as
`AUTH_KEYCLOAK_SECRET` in the Next.js environment. The secret is held only by
the two servers and is never included in the browser bundle. Authorization code
+ PKCE remains enabled as an additional control.

Both `implicitFlowEnabled` and `directAccessGrantsEnabled` are off: implicit flow
returns tokens in the URL fragment where they leak through history and referrers,
and direct access grants require the app to handle the user's password.

## Email and password accounts

Email/password login and self-registration use Keycloak's browser-based
Authorization Code flow. The client starts that flow from its `/sign-in` and
`/sign-up` pages; it never receives or proxies a password. Keycloak validates the
password confirmation, applies the realm's brute-force controls, and enforces
this server-side password policy:

- at least 12 characters;
- must not contain the username or email address; and
- must not reuse any of the previous three passwords.

The `navio` login theme extends Keycloak's built-in `keycloak.v2` templates, so
validation and accessibility fixes continue to come from Keycloak while
`themes/navio/login/resources/css/navio.css` supplies Navio styling. Do not
replace this flow with Direct Access Grants: that would make the web app handle
raw passwords and would bypass browser-flow capabilities such as required
actions and identity brokering.

### Why `verifyEmail` is off

`verifyEmail` is deliberately `false` and `deploy.sh` reasserts that on every
run. It is not a convenience setting: with it on, Keycloak 26 removes the
password fields from the registration form entirely and defers credential
creation to an `UPDATE_PASSWORD` required action that only runs *after* the user
clicks a verification link. Without an `smtpServer` that link is never sent, so
registration ends at `SEND_VERIFY_EMAIL_ERROR` and leaves an account with no
credential — unable to log in, and holding its email address against a retry
because `duplicateEmailsAllowed` is false.

Turn it back on only in the same change that configures `smtpServer`. The deploy
smoke test asserts `name="password"` is present on the registration form, so
flipping one without the other fails the deploy rather than production.

## Token lifetimes and suspension

`accessTokenLifespan` is 300 seconds. This matters for moderation: disabling an
account in Keycloak stops *new* tokens being issued but does not invalidate one
already issued. Three controls close that gap together:

1. Suspension calls the Admin API `logout` endpoint, killing sessions and
   refresh tokens (`revokeRefreshToken: true` means a refresh token cannot be
   replayed).
2. The user management service re-checks ban state on every request, so its own
   endpoints reject a suspended caller immediately.
3. The short access-token lifespan bounds the window for any other service that
   only validates the token.

## Post-import checklist

- [ ] `aud` contains `navio-api` in a freshly issued access token
- [ ] `realm_access.roles` contains `USER` for a normal account — if the claim is
      missing entirely, the `navio-web` scope mappings are empty (see above)
- [ ] `KEYCLOAK_WEB_CLIENT_SECRET` matches the Next.js `AUTH_KEYCLOAK_SECRET`
- [ ] `KEYCLOAK_ADMIN_CLIENT_SECRET` is random, environment-specific, and only in `.env`
- [ ] Service account has `manage-users` + `view-users` only — not `realm-admin`
- [ ] New users receive the `USER` role (the import assigns it through
      `defaultRoles`; confirm it appears under `default-roles-navio`)
- [ ] Registration form still renders `password` and `password-confirm` — if not,
      `verifyEmail` has been switched on without SMTP (see above)
- [ ] The Google OAuth client authorises exactly
      `https://navio.sit.kmutt.ac.th/realms/navio/broker/google/endpoint`;
      anything else fails at Google with `redirect_uri_mismatch`
- [ ] `sslRequired` remains `all`, and the public issuer is reachable only over HTTPS
