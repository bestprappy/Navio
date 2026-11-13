"""Offline safety checks for the opt-in maintained Guide expansion."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('upgrade', HERE / 'upgrade.py')
upgrade = importlib.util.module_from_spec(spec)
spec.loader.exec_module(upgrade)
sys_path = str(HERE)
import sys
sys.path.insert(0, sys_path)
import maintain


class UpgradeTests(unittest.TestCase):
    def setUp(self):
        self.before = json.loads((HERE / 'guides.json').read_text(encoding='utf-8'))
        self.after = json.loads((HERE / 'expanded-guides.json').read_text(encoding='utf-8'))

    def test_reviewed_batch_preserves_originals_and_has_varied_counts(self):
        pairs = upgrade.validate(self.before, self.after)
        self.assertEqual(len(pairs), 20)
        counts = [len(p['after']['content']['places']) for p in pairs]
        self.assertTrue(all(9 <= n <= 20 for n in counts))
        self.assertGreaterEqual(len(set(counts)), 5)

    def test_rejects_changed_original_place(self):
        changed = copy.deepcopy(self.after)
        first = next(iter(self.before[0]['guide']['content']['places']))
        changed[0]['guide']['content']['places'][first]['name'] = 'Replacement'
        with self.assertRaisesRegex(ValueError, 'original place'):
            upgrade.validate(self.before, changed)

    def test_rejects_lost_prose_and_unrelated_identity(self):
        changed = copy.deepcopy(self.after)
        changed[0]['guide']['content']['body'] = 'Replacement'
        with self.assertRaisesRegex(ValueError, 'original prose'):
            upgrade.validate(self.before, changed)
        changed = copy.deepcopy(self.after)
        changed[0]['id'] = '00000000-0000-0000-0000-000000000001'
        with self.assertRaisesRegex(ValueError, 'identity'):
            upgrade.validate(self.before, changed)

    def test_rejects_unmapped_or_duplicate_references(self):
        changed = copy.deepcopy(self.after)
        changed[0]['guide']['content']['body'] += '\n<div data-embed="guidePlace" data-place-id="fake"></div>'
        with self.assertRaisesRegex(ValueError, 'references'):
            upgrade.validate(self.before, changed)

    def test_default_is_rollback_and_no_insert_delete_or_publication_change(self):
        sql = upgrade.prepare_sql(upgrade.validate(self.before, self.after))
        self.assertTrue(sql.rstrip().endswith('ROLLBACK;'))
        self.assertNotIn('INSERT INTO iam.guides', sql)
        self.assertNotIn('DELETE FROM', sql)
        self.assertNotIn('published_at=', sql)
        self.assertIn('g.created_by IS NOT NULL', sql)
        self.assertIn('g.updated_by IS NOT NULL', sql)
        self.assertIn('FOR UPDATE OF g', sql)
        self.assertIn('IS DISTINCT FROM', sql)
        self.assertIn("g.status<>'PUBLISHED'", sql)

    def test_apply_requires_backup_acknowledgment_and_canary_is_scoped(self):
        pairs = upgrade.validate(self.before, self.after)
        with self.assertRaisesRegex(ValueError, 'backup'):
            upgrade.prepare_sql(pairs, apply=True)
        sql = upgrade.prepare_sql(pairs[:1], apply=True, backup_verified=True)
        self.assertTrue(sql.rstrip().endswith('COMMIT;'))
        self.assertNotIn(self.after[1]['id'], sql)

    def test_json_delimiter_injection_rejected(self):
        pairs = upgrade.validate(self.before, self.after)
        pairs[0]['after']['description'] = '$navio_expansion$'
        with self.assertRaisesRegex(ValueError, 'delimiter'):
            upgrade.prepare_sql(pairs)

    def test_unknown_icon_is_rejected_before_publication(self):
        changed = copy.deepcopy(self.after)
        changed[0]['guide']['content']['categories'][-1]['iconId'] = 'map'
        with self.assertRaisesRegex(ValueError, 'icon'):
            upgrade.validate(self.before, changed)

    def test_post_apply_verifier_preserves_other_guides_and_metadata(self):
        pairs = upgrade.validate(self.before, self.after)
        p = pairs[0]
        old = {'id':p['id'],'content':p['before']['content'],'version':3,
               'published_at':'original','updated_at':'old','name':'Keep'}
        other = {'id':'unrelated','content':{},'version':2,'published_at':'keep'}
        new = dict(old, content=p['after']['content'],version=4,updated_at='new')
        maintain.verify([old,other],[new,other],pairs[:1])
        with self.assertRaisesRegex(RuntimeError, 'non-target'):
            maintain.verify([old,other],[new,dict(other,version=3)],pairs[:1])
        with self.assertRaisesRegex(RuntimeError, 'metadata'):
            maintain.verify([old,other],[dict(new,published_at='changed'),other],pairs[:1])
        with self.assertRaisesRegex(RuntimeError, 'version'):
            maintain.verify([old,other],[dict(new,version=5),other],pairs[:1])


if __name__ == '__main__':
    unittest.main()
