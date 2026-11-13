"""Prepare the reviewed Navio Team Guide batch for scoped VM maintenance.

This generates SQL only. The default transaction rolls back. It never contacts
Google or modifies an existing Guide, even when a destination conflicts.
"""

import argparse
import json
import re
import sys
import uuid
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--only', help='Prepare one manifest slug as a canary')
    parser.add_argument('--apply', action='store_true', help='Commit instead of rolling back')
    args = parser.parse_args()
    batch = json.loads(Path(__file__).with_name('guides.json').read_text(encoding='utf-8'))
    assert len(batch) == 20
    assert len({row['id'] for row in batch}) == 20
    assert len({row['guide']['destination']['providerPlaceId'] for row in batch}) == 20
    if args.only:
        batch = [row for row in batch if row['slug'] == args.only]
        if len(batch) != 1:
            parser.error('The requested slug is not in this reviewed batch')
    for row in batch:
        uuid.UUID(row['id'])
        fields = row['guide']
        assert 0 < len(fields['name']) <= 120
        assert re.fullmatch('[A-Z]{2}', fields['countryCode'])
        assert len(fields['description']) <= 4000
        assert 4 <= len(fields['content']['places']) <= 6
        assert len(fields['content']['body']) <= 200000
        assert fields['coverPlaceId'] in {p['id'] for p in fields['content']['places'].values()}
    payload = json.dumps(batch, ensure_ascii=False, separators=(',', ':'))
    assert '$navio_guides$' not in payload
    final = 'COMMIT' if args.apply else 'ROLLBACK'
    # Data comes exclusively from the reviewed manifest and stays a JSON value.
    sql = r"""\set ON_ERROR_STOP on
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
CREATE TEMP TABLE navio_guide_batch ON COMMIT DROP AS
SELECT value->>'id' AS id, value->>'slug' AS slug, value->'guide' AS fields
FROM jsonb_array_elements($navio_guides$PAYLOAD$navio_guides$::jsonb);
LOCK TABLE iam.guides IN SHARE ROW EXCLUSIVE MODE;
DO $check$
BEGIN
    IF EXISTS (
        SELECT 1 FROM navio_guide_batch d JOIN iam.guides g
          ON g.destination_provider=d.fields#>>'{destination,provider}'
         AND g.destination_place_id=d.fields#>>'{destination,providerPlaceId}'
        WHERE g.id<>d.id::uuid
    ) THEN
        RAISE EXCEPTION 'A Guide already exists for a requested destination. Nothing was changed.';
    END IF;
    IF EXISTS (
        SELECT 1 FROM navio_guide_batch d JOIN iam.guides g ON g.id=d.id::uuid
        WHERE jsonb_build_object(
            'name',g.name,'country',g.country,'countryCode',g.country_code,
            'destination',jsonb_build_object('provider',g.destination_provider,
                'providerPlaceId',g.destination_place_id,'name',g.destination_name,
                'lat',g.destination_lat,'lng',g.destination_lng),
            'description',g.description,'coverPlaceId',g.cover_place_id,'content',g.content
        ) IS DISTINCT FROM d.fields OR g.status<>'PUBLISHED'
    ) THEN
        RAISE EXCEPTION 'An existing batch Guide differs or was unpublished. Nothing was changed.';
    END IF;
    IF EXISTS (
        SELECT 1 FROM navio_guide_batch d,
        LATERAL jsonb_array_elements(d.fields#>'{content,categories}') c
        WHERE NOT EXISTS (SELECT 1 FROM iam.palette_colors p WHERE p.id=c->>'colorId')
    ) THEN
        RAISE EXCEPTION 'A requested palette colour does not exist. Nothing was changed.';
    END IF;
END
$check$;
INSERT INTO iam.guides (
    id,name,country,country_code,destination_provider,destination_place_id,
    destination_name,destination_lat,destination_lng,description,cover_place_id,
    content,status,version,published_at
)
SELECT d.id::uuid,d.fields->>'name',d.fields->>'country',d.fields->>'countryCode',
    d.fields#>>'{destination,provider}',d.fields#>>'{destination,providerPlaceId}',
    d.fields#>>'{destination,name}',(d.fields#>>'{destination,lat}')::double precision,
    (d.fields#>>'{destination,lng}')::double precision,d.fields->>'description',
    d.fields->>'coverPlaceId',d.fields->'content','PUBLISHED',0,now()
FROM navio_guide_batch d WHERE NOT EXISTS (SELECT 1 FROM iam.guides g WHERE g.id=d.id::uuid);
SELECT d.slug,g.id,g.status,(SELECT count(*) FROM jsonb_object_keys(g.content->'places')) AS places
FROM navio_guide_batch d JOIN iam.guides g ON g.id=d.id::uuid ORDER BY d.slug;
FINAL;
"""
    sys.stdout.reconfigure(encoding='utf-8')
    print(sql.replace('PAYLOAD', payload).replace('FINAL', final))


if __name__ == '__main__':
    main()
