# Navio Team Guides, November 2026

Twenty additional curated Guides across 15 countries and territories. The
reviewed manifest contains 101 existing real place references, 40 populated
sections, introductions, tailored visitor tips and official reference links.
Each destination has one curated Guide. The four pre-existing published Guides
are outside this batch.

The content was authored for this collection. Destination identities and place
coordinates were reused from the existing maintained Navio Team publications.
Preparation and publication make no Google/provider requests. Photos, hours and
ratings continue to use the application's normal place-detail behaviour when
readers open a Guide.

## Scoped content maintenance

This is data maintenance using the existing `iam.guides` representation. It
requires no application release, service restart or database migration. Records
use the same Navio Team seed attribution as the original curated library.

Run only in the already authenticated VM maintenance session. Download these
files from a pinned, reviewed Git revision into a new private maintenance folder.
Use `umask 077`. Back up `iam.guides` with `pg_dump` before applying anything and
record a hash of the pre-existing records for comparison afterward. Keep backups
on the VM.

`python3 prepare.py > dry-run.sql` prepares a transaction ending in `ROLLBACK`.
Pass it to `psql -v ON_ERROR_STOP=1` through the existing private PostgreSQL
container. Review all twenty records before applying a canary.

`python3 prepare.py --only kyoto --apply > canary.sql` prepares the single canary.
After checking its public Guide response, prepare the entire batch with
`python3 prepare.py --apply > apply.sql` and run it the same way.

Stable UUIDs make an unchanged rerun idempotent. An existing destination,
unpublished batch record, changed document or missing palette colour aborts the
whole transaction. The script contains no UPDATE, DELETE or schema changes.
It holds a short table lock and stops on a lock timeout. Preserve changed records
for inspection instead of forcing a replacement.

After publication, verify all twenty public Guide documents, discovery/search
and existing-record hashes. Avoid opening live photo/map readers as part of
automated checks while provider usage is restricted. Browser layout checks can
use the real Guide documents with provider requests blocked.

## Coverage

Kyoto gardens and autumn, Osaka food and Nara, Sapporo summer and Otaru,
Seoul spring, Busan coast and evenings, Taipei small bites and Beitou,
Hong Kong harbour and design, Singapore hawkers and heritage, Ubud landscape,
Hanoi streets and food, Luang Prabang slow travel, Angkor architecture,
Chiang Mai forest temples, Chiang Rai visual culture, Hua Hin and Pranburi,
Paris art and gardens, Rome history, Barcelona design, Amsterdam spring,
London indoor culture and markets.
