# Navio Team Guides, November 2026

## Maintained expansion: 13 November

`guides.json` remains the original expected-content manifest. Do not replace it
or rerun the original INSERT workflow to expand existing records.
`expanded-guides.json` contains the reviewed replacement content for the same
twenty identities: **219 distinct-within-Guide mapped places, 77 populated
sections**, with varied totals from **9 to 19**. The four older original Guides
and all traveler-authored Guides are outside this update.

| Guide | Places | Guide | Places |
| --- | ---: | --- | ---: |
| Kyoto | 19 | Osaka & Nara | 9 |
| Sapporo & Otaru | 12 | Seoul | 12 |
| Busan | 9 | Taipei | 13 |
| Hong Kong | 11 | Singapore | 10 |
| Ubud | 9 | Hanoi | 9 |
| Luang Prabang | 9 | Siem Reap | 10 |
| Chiang Mai | 15 | Chiang Rai | 10 |
| Hua Hin & Pranburi | 10 | Paris | 11 |
| Rome | 10 | Barcelona | 9 |
| Amsterdam | 11 | London | 11 |

Original prose, mapped place records, category/list order, cover and references
remain intact. Added groups provide specific choices and reading context; they
are not a requirement to visit everything or a compressed one-day itinerary.
Outlying excursions are explicitly labelled. No hotel/city-anchor padding or
invented coordinates was used to meet the minimum.

Most additions reuse real mapped places in existing maintained Navio plans.
Twelve missing venue records were resolved with bounded, cached normal
autocomplete/detail requests and their location/country reviewed. The public
Places discovery switch was not enabled or changed. Official destination and
venue links remain in each Guide. This publication workflow makes **no provider
requests**; normal reader photos/details still follow existing application
behaviour and are not a new API-cost countermeasure.

### Exact in-place update

1. Run only in the existing authenticated VM session; do not expose service
   ports or change SSH access. Download the bundle from a full reviewed Git SHA.
2. `python3 run_expansion.py --revision <full-sha>` checks every downloaded file,
   runs the nine offline tests, creates and verifies a private custom-format
   **whole IAM schema backup**, records the before-state, and runs the complete
   SQL dry run ending in ROLLBACK. It changes no Guide content.
3. Review the reported private `backups/<timestamp>/dry-run.log`, then run the
   same pinned command with `--apply`. This creates another verified backup,
   repeats the full dry run, applies Kyoto as a canary, verifies it, then applies
   and verifies the full batch. Re-running an already completed batch is a no-op.
4. Keep backups on the VM. Share only the compact `result.json` or success
   output, never the database archive or full before-state.

The SQL locks only matching rows, requires the original null-owned curated
identities to remain PUBLISHED, checks every old field against the original or
already-upgraded manifest, and checks palette colours. Changed, missing,
unpublished or administrator-edited Guides abort the entire transaction. The
only updates are content, version and updated_at. Identity, original publish
time, owner, cover, saved links, readership, ratings and comments are preserved.
There is no INSERT, DELETE, migration, deployment or service restart.

For a manually reviewed maintenance session, `upgrade.py` can also generate SQL
directly. Its default is ROLLBACK; `--apply` requires the SHA256 of the verified
private backup through `--backup-sha256`. `--only kyoto` limits a canary.

Validation: nine offline safety tests; eight disposable PostgreSQL checks
(rollback, canary, rerun, all-target preservation, changed-content and unpublished
rejection, missing identity); all twenty frontend schemas/read models/editor
round trips; desktop Kyoto/Chiang Mai and mobile Ubud readers without external
provider requests, overflow or runtime errors. **Preparation/test success does
not mean the VM data has already been updated.** Record the live result before
claiming publication complete.

Bundle maintainers: stage the five files first, then run
`python checksum_bundle.py` and stage `expansion-checksums.json`. Checksums must
come from Git's staged bytes, since Windows working copies may contain CRLF
while the pinned download contains LF. Verify the manifest against the final
committed Git blobs before providing a VM command.

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
