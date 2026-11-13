"""Prepare an exact, in-place update of the twenty maintained Navio Team Guides.

Offline SQL generation only; defaults to ROLLBACK. Never contacts a provider.
The unchanged original manifest is the expected-content guard, not a new seed.
"""
import argparse
from collections import Counter
import json
import math
from pathlib import Path
import re
import sys
import uuid

HERE = Path(__file__).resolve().parent
DELIMITER = '$navio_expansion$'
ICON_IDS = {'landmark','utensils','bed','coffee','wine','shopping','trees','waves',
            'mountain','camera','ticket','music','train','charging','baby','heart'}


def validate(before, after):
    known = {row['slug']: row for row in before}
    if len(before) != 20 or len(known) != 20 or len(after) != 20:
        raise ValueError('Expected exactly twenty maintained Guide identities')
    seen = set()
    result = []
    for row in after:
        original = known.get(row['slug'])
        if (not original or row['id'] != original['id'] or row['source'] != 'CURATED'
                or row['slug'] in seen):
            raise ValueError('Unknown or duplicate maintained Guide identity')
        uuid.UUID(row['id'])
        seen.add(row['slug'])
        old, new = original['guide'], row['guide']
        if {k:v for k,v in old.items() if k != 'content'} != {k:v for k,v in new.items() if k != 'content'}:
            raise ValueError('Guide identity, cover and publication metadata must remain unchanged')
        oldc, newc = old['content'], new['content']
        places = newc['places']
        if not 9 <= len(places) <= 20:
            raise ValueError('Expanded Guides must have nine to twenty places')
        for pid, place in oldc['places'].items():
            if places.get(pid) != place:
                raise ValueError('An original place was changed or removed')
        if (newc['categories'][:len(oldc['categories'])] != oldc['categories']
                or any(newc['lists'].get(k) != v for k,v in oldc['lists'].items())):
            raise ValueError('Original categories and lists must be preserved')
        marker = '## Official references'
        oldstart, oldend = oldc['body'].split(marker, 1)
        if not newc['body'].startswith(oldstart) or marker+oldend not in newc['body']:
            raise ValueError('The original prose and references must be preserved')
        if len(newc['body']) > 200000:
            raise ValueError('Guide document exceeds editor limit')
        refs = re.findall(r'data-embed="guidePlace" data-place-id="([^"]+)"', newc['body'])
        if Counter(refs) != Counter({key:1 for key in places}):
            raise ValueError('All place references must occur exactly once')
        category_ids = [c['id'] for c in newc['categories']]
        if any(c['iconId'] not in ICON_IDS for c in newc['categories']):
            raise ValueError('Unknown Guide category icon')
        list_refs = re.findall(r'data-embed="placeList" data-list-id="([^"]+)"', newc['body'])
        if (len(set(category_ids)) != len(category_ids) or set(category_ids) != set(newc['lists'])
                or Counter(list_refs) != Counter({key:1 for key in newc['lists']})):
            raise ValueError('Category/list references are incomplete or duplicated')
        provider_ids = set()
        for key, place in places.items():
            pid = place['providerPlaceId']
            if (key != pid or pid in provider_ids or place['id'] != 'GOOGLE:'+pid
                    or place['provider'] != 'GOOGLE' or not place.get('name') or not place.get('address')):
                raise ValueError('Invalid or duplicate mapped place identity')
            provider_ids.add(pid)
            if not (math.isfinite(place['lat']) and -90 <= place['lat'] <= 90
                    and math.isfinite(place['lng']) and -180 <= place['lng'] <= 180):
                raise ValueError('Invalid mapped coordinates')
        result.append({'id':row['id'], 'slug':row['slug'], 'before':old, 'after':new})
    return result


def prepare_sql(pairs, *, apply=False, backup_verified=False):
    if apply and not backup_verified:
        raise ValueError('A verified private backup is required before apply')
    payload = json.dumps(pairs, ensure_ascii=False, separators=(',', ':'))
    if DELIMITER in payload:
        raise ValueError('Unsafe SQL JSON delimiter in content')
    sql = r"""\set ON_ERROR_STOP on
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
CREATE TEMP TABLE navio_guide_expansion ON COMMIT DROP AS
SELECT value->>'id' AS id,value->>'slug' AS slug,
       value->'before' AS before,value->'after' AS after
FROM jsonb_array_elements($navio_expansion$PAYLOAD$navio_expansion$::jsonb);
SELECT g.id FROM iam.guides g JOIN navio_guide_expansion d ON g.id=d.id::uuid
ORDER BY g.id FOR UPDATE OF g;
DO $guard$
BEGIN
    IF EXISTS (SELECT 1 FROM navio_guide_expansion d LEFT JOIN iam.guides g ON g.id=d.id::uuid
               WHERE g.id IS NULL) THEN
        RAISE EXCEPTION 'A maintained Guide is missing. Nothing changed.';
    END IF;
    IF EXISTS (
        SELECT 1 FROM navio_guide_expansion d JOIN iam.guides g ON g.id=d.id::uuid
        WHERE g.status<>'PUBLISHED' OR g.published_at IS NULL
           OR g.created_by IS NOT NULL OR g.updated_by IS NOT NULL
           OR (jsonb_build_object(
               'name',g.name,'country',g.country,'countryCode',g.country_code,
               'destination',jsonb_build_object('provider',g.destination_provider,
                   'providerPlaceId',g.destination_place_id,'name',g.destination_name,
                   'lat',g.destination_lat,'lng',g.destination_lng),
               'description',g.description,'coverPlaceId',g.cover_place_id,'content',g.content
           ) IS DISTINCT FROM d.before AND jsonb_build_object(
               'name',g.name,'country',g.country,'countryCode',g.country_code,
               'destination',jsonb_build_object('provider',g.destination_provider,
                   'providerPlaceId',g.destination_place_id,'name',g.destination_name,
                   'lat',g.destination_lat,'lng',g.destination_lng),
               'description',g.description,'coverPlaceId',g.cover_place_id,'content',g.content
           ) IS DISTINCT FROM d.after)
    ) THEN
        RAISE EXCEPTION 'Guide ownership, publication or expected content changed. Nothing changed.';
    END IF;
    IF EXISTS (
        SELECT 1 FROM navio_guide_expansion d,
        LATERAL jsonb_array_elements(d.after#>'{content,categories}') c
        WHERE NOT EXISTS (SELECT 1 FROM iam.palette_colors p WHERE p.id=c->>'colorId')
    ) THEN
        RAISE EXCEPTION 'An expansion palette colour is missing. Nothing changed.';
    END IF;
END
$guard$;
UPDATE iam.guides g SET content=d.after->'content',version=g.version+1,updated_at=now()
FROM navio_guide_expansion d WHERE g.id=d.id::uuid
AND g.content IS DISTINCT FROM d.after->'content';
SELECT d.slug,g.id,g.version,
    (SELECT count(*) FROM jsonb_object_keys(g.content->'places')) AS places
FROM navio_guide_expansion d JOIN iam.guides g ON g.id=d.id::uuid ORDER BY d.slug;
FINAL;
"""
    return sql.replace('PAYLOAD', payload).replace('FINAL', 'COMMIT' if apply else 'ROLLBACK')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--only', help='Single reviewed slug for canary')
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--backup-sha256', help='Hash of verified private pre-update backup')
    args = parser.parse_args()
    if args.apply and not re.fullmatch('[0-9a-fA-F]{64}', args.backup_sha256 or ''):
        parser.error('--apply requires --backup-sha256 from the verified private backup')
    pairs = validate(json.loads((HERE/'guides.json').read_text(encoding='utf-8')),
                     json.loads((HERE/'expanded-guides.json').read_text(encoding='utf-8')))
    if args.only:
        pairs = [p for p in pairs if p['slug'] == args.only]
        if len(pairs) != 1:
            parser.error('Unknown maintained Guide slug')
    sys.stdout.reconfigure(encoding='utf-8')
    if args.apply:
        print('-- Verified private backup SHA256: '+args.backup_sha256)
    print(prepare_sql(pairs, apply=args.apply, backup_verified=bool(args.backup_sha256)))


if __name__ == '__main__':
    main()
