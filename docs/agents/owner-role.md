# Owner role rollout

`OWNER` is the highest Navio staff role. An Owner can grant and revoke `ADMIN`; an Admin can grant and revoke `MODERATOR` (and the default `USER` role through the API). The users page exposes the staff roles. No Navio API can grant or revoke `OWNER`, and Owner accounts cannot be banned through Navio. Keycloak remains the authority; `iam.user_roles` is only a display snapshot.

## Existing realms

The `.deploy/keycloak/navio-realm.json` change applies to **new realm imports only**. Keycloak does not update an existing realm from that file on restart. Before using the new UI in an existing environment, a trusted Keycloak operator must:

1. Create the `OWNER` realm role in the `navio` realm. *(Automated: `deploy.sh` creates it if missing.)*
2. Add `OWNER` to the `navio-web` client's role scope mappings so it appears in access tokens. *(Automated: `deploy.sh` adds it.)*
3. Assign `OWNER` directly to the intended operator account. Keep its normal `USER` role. No public signup or browser request may assign this role.
4. Have that account sign out and sign in again, then confirm its access token contains `OWNER` in `realm_access.roles`.
5. Add the role to Navio's display snapshot for that already provisioned profile. Keycloak remains the authority; this row only lets the users table show the Owner badge. Use the profile's `iam.users.id`, not the Keycloak subject:

   ```sql
   INSERT INTO iam.user_roles (user_id, role, granted_at)
   VALUES ('<navio-profile-uuid>', 'OWNER', now())
   ON CONFLICT (user_id, role) DO NOTHING;
   ```

   If an operator later removes `OWNER` in Keycloak, delete its display snapshot row as part of the same operator procedure. A Navio API cannot manage this role.

Deploy the IAM V6 migration and code before testing role changes. The migration widens only the `iam.user_roles` check constraint and is compatible with existing rows and previous images. Do not edit the applied V1 migration.

## Verification

- Owner opens Admin → Users and can grant and remove Administrator after supplying a reason.
- Administrator can grant and remove Moderator, but receives 403 for an Administrator change, including a direct API call.
- Moderator cannot change roles.
- An attempted `OWNER` grant or revoke through the Navio API receives 403.
- The user list shows the resulting colored role badge after refresh; the account history records the actor and reason.

Role changes update Keycloak immediately, but an already issued access token can retain its old role until it expires. IAM checks live Keycloak roles again for role mutations. Other privileged routes use the validated access token, so operational revocation across all services is bounded by the token lifetime (currently five minutes).
