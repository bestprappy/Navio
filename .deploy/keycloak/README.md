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
`/sign-up` pages; it never receives or proxies a password. Keycloak renders the
credential fields, validates the email and password confirmation, applies the
realm's brute-force controls, and enforces this server-side password policy:

- at least 12 characters;
- must not contain the username or email address; and
- must not reuse any of the previous three passwords.

The `navio` login theme extends Keycloak's built-in `keycloak.v2` templates, so
validation and accessibility fixes continue to come from Keycloak while
`themes/navio/login/resources/css/navio.css` supplies Navio styling. Do not
replace this flow with Direct Access Grants: that would make the web app handle
raw passwords and would bypass browser-flow capabilities such as required
actions and identity brokering.

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
- [ ] `realm_access.roles` contains `USER` for a normal account
- [ ] `KEYCLOAK_WEB_CLIENT_SECRET` matches the Next.js `AUTH_KEYCLOAK_SECRET`
- [ ] `KEYCLOAK_ADMIN_CLIENT_SECRET` is random, environment-specific, and only in `.env`
- [ ] Service account has `manage-users` + `view-users` only — not `realm-admin`
- [ ] New users receive the `USER` role (the import assigns it through
      `defaultRoles`; confirm it appears under `default-roles-navio`)
- [ ] SMTP configured, since `verifyEmail` is on and unverified users cannot log in
- [ ] `sslRequired` remains `all`, and the public issuer is reachable only over HTTPS
