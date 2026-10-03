"""Local, no-cost tests: all recognition and decoding calls are fake."""
import asyncio
import contextlib
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import wave

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from tools.audio_pipeline import install, review_speech as speech


class SpeechReviewTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(self.temp.name)
        self.source = self.base / 'take.wav'
        self.source.write_bytes(b'fixture audio')
        self.plan = {'jobs': [{'id': 'voice', 'install': {'speech': True, 'text': 'Keep the fire inside.'}}]}
        self.ledger = {'jobs': {'voice': {'status': 'complete', 'files': [str(self.source)]}}}
        self.digest = hashlib.sha256(self.source.read_bytes()).hexdigest()

    def tearDown(self):
        self.temp.cleanup()

    def test_default_thai_and_strict_english(self):
        self.assertEqual(speech.review_options(self.plan), ('tha', .10))
        self.assertEqual(speech.review_options(dict(self.plan, language_code='eng', max_cer=0)), ('eng', 0))
        for fields in ({'language_code': 'english'}, {'max_cer': float('nan')}, {'max_cer': -.1}, {'max_cer': 2}):
            with self.subTest(fields=fields), self.assertRaises(ValueError):
                speech.review_options(dict(self.plan, **fields))

    def test_case_unicode_punctuation_and_thai_marks(self):
        self.assertEqual(speech.clean('CAFÉ! “Straße.”'), speech.clean('cafe\u0301 strasse'))
        self.assertEqual(speech.clean('ลมกำลังจะเปลี่ยนทิศ เร็ว ๆ นี้'), speech.clean('ลมกำลังจะเปลี่ยนทิศเร็วๆนี้'))
        self.assertNotEqual(speech.clean('นี้'), speech.clean('นี'))
        result = speech.assess_transcript('Keep the fire inside.', 'KEEP THE FIRE INSIDE!', 'eng', 0, self.digest)
        self.assertTrue(result['accepted'])
        self.assertEqual(result['cer'], 0)
        self.assertFalse(speech.assess_transcript('Fire inside.', 'Fire outside.', 'eng', 0, self.digest)['accepted'])
        self.assertFalse(speech.assess_transcript('Fire.', '', 'eng', 0, self.digest)['accepted'])

    def test_legacy_thai_resume_and_manual_decisions(self):
        self.plan['jobs'][0]['install']['text'] = 'ระวังไฟลาม'
        old = {'voice': {'expected': 'ระวังไฟลาม', 'heard': 'ระวังไฟลาม', 'cer': 0, 'accepted': True, 'review': 'Legacy listened take'}}
        before = copy.deepcopy(old)
        self.assertEqual(speech.pending_reviews(self.plan, self.ledger, old), [])
        self.assertEqual(old, before)
        # A human mismatch override survives an unchanged strict plan.
        self.plan.update(language_code='eng', max_cer=0)
        self.plan['jobs'][0]['install']['text'] = 'Fire.'
        old = {'voice': dict(speech.assess_transcript('Fire.', 'Fires.', 'eng', 0, self.digest), accepted=True, manual_review='Listened and accepted pronunciation')}
        before = copy.deepcopy(old)
        self.assertEqual(speech.pending_reviews(self.plan, self.ledger, old), [])
        self.assertEqual(old, before)

    def test_tighter_threshold_reuses_transcript_without_accepting_mismatch(self):
        self.plan.update(language_code='eng', max_cer=0)
        old = {'voice': speech.assess_transcript('Keep the fire inside.', 'Keep a fire inside.', 'eng', .5, self.digest)}
        self.assertTrue(old['voice']['accepted'])
        self.assertEqual(speech.pending_reviews(self.plan, self.ledger, old), [])
        self.assertFalse(old['voice']['accepted'])
        self.assertEqual(old['voice']['max_cer'], 0)

    def test_changed_text_locale_or_source_invalidates_old_acceptance(self):
        old = {'voice': speech.assess_transcript('Keep the fire inside.', 'Keep the fire inside.', 'tha', .1, self.digest)}
        for changed in ('text', 'locale', 'source'):
            with self.subTest(changed=changed):
                plan, reviews = copy.deepcopy(self.plan), copy.deepcopy(old)
                if changed == 'text': plan['jobs'][0]['install']['text'] = 'New words.'
                if changed == 'locale': plan['language_code'] = 'eng'
                if changed == 'source': reviews['voice']['source_sha256'] = 'previous take'
                self.assertEqual(len(speech.pending_reviews(plan, self.ledger, reviews)), 1)
                self.assertFalse(reviews['voice']['accepted'])
                self.assertEqual(reviews['voice']['status'], 'pending')

    def test_missing_files_rejected_and_error_retry_is_explicit(self):
        self.source.unlink()
        reviews = {}
        self.assertEqual(speech.pending_reviews(self.plan, self.ledger, reviews), [])
        self.assertFalse(reviews['voice']['accepted'])
        self.assertEqual(reviews['voice']['status'], 'error')
        self.source.write_bytes(b'fixture audio')
        reviews['voice'] = speech.error_review('Keep the fire inside.', 'tha', .1, 'timeout', self.digest)
        self.assertEqual(speech.pending_reviews(self.plan, self.ledger, reviews), [])
        self.assertEqual(len(speech.pending_reviews(self.plan, self.ledger, reviews, retry_errors=True)), 1)
        self.assertEqual(speech.pending_reviews(self.plan, self.ledger, reviews), [])

    def test_fake_asr_receives_english_and_survives_provider_errors(self):
        self.plan.update(language_code='eng', max_cer=0)
        reviews = {}
        pending = speech.pending_reviews(self.plan, self.ledger, reviews)
        requests = []
        class FakeSession:
            async def call_tool(_, tool, arguments):
                requests.append((tool, arguments))
                return SimpleNamespace(content=[SimpleNamespace(type='text', text='KEEP THE FIRE INSIDE!')], isError=False)
        path = self.base / 'speech_review.json'
        with contextlib.redirect_stdout(io.StringIO()):
            asyncio.run(speech.review_pending(FakeSession(), pending, reviews, path, 'eng', 0))
        self.assertEqual(requests[0][1]['language_code'], 'eng')
        self.assertTrue(json.loads(path.read_text())['voice']['accepted'])
        for failure in ('tool', 'transport'):
            class FailingSession:
                async def call_tool(_, tool, arguments):
                    if failure == 'transport': raise TimeoutError('fixture timeout')
                    return SimpleNamespace(content=[SimpleNamespace(type='text', text='fixture provider error')], isError=True)
            with self.subTest(failure=failure), contextlib.redirect_stdout(io.StringIO()):
                asyncio.run(speech.review_pending(FailingSession(), pending, reviews, path, 'eng', 0))
            result = json.loads(path.read_text())['voice']
            self.assertFalse(result['accepted'])
            self.assertEqual(result['status'], 'error')
            self.assertIsNone(result['cer'])

    def test_fully_cached_main_needs_no_mcp_or_config(self):
        self.plan['output_directory'] = str(self.base)
        (self.base / 'ledger.json').write_text(json.dumps(self.ledger))
        reviews = {'voice': speech.assess_transcript('Keep the fire inside.', 'Keep the fire inside.', 'tha', .1, self.digest)}
        (self.base / 'speech_review.json').write_text(json.dumps(reviews))
        path = self.base / 'plan.json'
        path.write_text(json.dumps(self.plan))
        with patch.object(speech.Path, 'home', side_effect=AssertionError('must not read configuration')), contextlib.redirect_stdout(io.StringIO()):
            asyncio.run(speech.main(path))
        self.assertEqual(json.loads((self.base / 'speech_review.json').read_text()), reviews)


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(self.temp.name)
        self.previous = Path.cwd()
        os.chdir(self.base)
        self.batch = self.base / 'batch'
        self.batch.mkdir()
        self.source = self.base / 'take.wav'
        self.source.write_bytes(b'source fixture')
        self.plan = {'output_directory': str(self.batch), 'language_code': 'eng', 'jobs': [{'id': 'voice', 'install': {'file': 'en/tapoh_warning.wav', 'speech': True, 'text': 'Fire.', 'loop': False, 'rms_dbfs': -19}}]}
        (self.batch / 'ledger.json').write_text(json.dumps({'jobs': {'voice': {'status': 'complete', 'files': [str(self.source)]}}}))
        self.approval = {'accepted': True, 'expected': 'Fire.', 'language_code': 'eng', 'source_sha256': hashlib.sha256(self.source.read_bytes()).hexdigest()}
        (self.batch / 'speech_review.json').write_text(json.dumps({'voice': self.approval}))
        self.plan_path = self.base / 'plan.json'
        self.plan_path.write_text(json.dumps(self.plan))
        t = np.arange(install.SR // 2) / install.SR
        self.samples = (.35 * np.sin(2 * np.pi * 220 * t) + .01).astype('<f4')

    def tearDown(self):
        os.chdir(self.previous)
        self.temp.cleanup()

    def prepare(self, enabled):
        with patch.object(install.subprocess, 'run', return_value=SimpleNamespace(stdout=self.samples.tobytes())) as decoder, contextlib.redirect_stdout(io.StringIO()):
            install.prepare(self.plan_path, enabled)
        return decoder

    def test_relative_nested_path_and_absolute_traversal_rejection(self):
        self.assertEqual(install.safe_output('assets/audio', 'en/tapoh.wav'), Path('assets/audio/en/tapoh.wav'))
        for filename in ('/tmp/audio.wav', '../audio.wav', 'en/../../audio.wav', 'en/../audio.wav', 'C:/audio.wav', 'en\\audio.wav', '', '.', None):
            with self.subTest(filename=filename), self.assertRaises(ValueError):
                install.safe_output('assets/audio', filename)

    def test_symlink_escape_rejected(self):
        Path('assets/audio').mkdir(parents=True)
        outside = self.base / 'outside'
        outside.mkdir()
        Path('assets/audio/en').symlink_to(outside, target_is_directory=True)
        with self.assertRaises(ValueError):
            install.safe_output('assets/audio', 'en/voice.wav')

    def test_prepare_nested_candidate_does_not_install(self):
        self.prepare(False)
        candidate = self.batch / 'prepared/en/tapoh_warning.wav'
        self.assertTrue(candidate.exists())
        self.assertFalse(Path('assets/audio/en/tapoh_warning.wav').exists())
        self.assertFalse(json.loads((self.batch / 'installed_manifest.json').read_text())[0]['installed'])

    def test_install_creates_parent_normalizes_and_preserves_first_backup(self):
        self.prepare(True)
        target = Path('assets/audio/en/tapoh_warning.wav')
        with wave.open(str(target), 'rb') as audio:
            self.assertEqual((audio.getnchannels(), audio.getsampwidth(), audio.getframerate()), (1, 2, 44100))
            data = np.frombuffer(audio.readframes(audio.getnframes()), dtype='<i2') / 32767
        self.assertLessEqual(np.max(np.abs(data)), .7001)
        self.assertAlmostEqual(20 * np.log10(np.sqrt(np.mean(data * data))), -19, delta=.05)
        self.assertFalse((self.batch / 'backup/en/tapoh_warning.wav').exists())
        target.write_bytes(b'original installed bytes')
        self.prepare(True)
        backup = self.batch / 'backup/en/tapoh_warning.wav'
        self.assertEqual(backup.read_bytes(), b'original installed bytes')
        self.samples *= .5
        self.prepare(True)
        self.assertEqual(backup.read_bytes(), b'original installed bytes')
        row = json.loads((self.batch / 'installed_manifest.json').read_text())[0]
        self.assertTrue(row['installed'])
        self.assertEqual(row['sha256'], hashlib.sha256(target.read_bytes()).hexdigest())

    def test_rejected_speech_never_decodes_or_installs(self):
        (self.batch / 'speech_review.json').write_text(json.dumps({'voice': {'accepted': False, 'status': 'error'}}))
        decoder = self.prepare(True)
        decoder.assert_not_called()
        self.assertFalse(Path('assets/audio').exists())

    def test_stale_accepted_text_or_language_aborts_without_touching_production(self):
        target = Path('assets/audio/en/tapoh_warning.wav')
        target.parent.mkdir(parents=True)
        target.write_bytes(b'unchanged production')
        for field, changed in (('expected', 'Different wording.'), ('language_code', 'tha')):
            decision = dict(self.approval, **{field: changed})
            (self.batch / 'speech_review.json').write_text(json.dumps({'voice': decision}))
            with self.subTest(field=field), patch.object(install.subprocess, 'run') as decoder, self.assertRaisesRegex(ValueError, 'Stale or unbound speech approval'):
                install.prepare(self.plan_path, True)
            decoder.assert_not_called()
            self.assertEqual(target.read_bytes(), b'unchanged production')
            self.assertFalse((self.batch / 'prepared').exists())
            self.assertFalse((self.batch / 'backup').exists())

    def test_stale_source_bytes_abort_before_decoding(self):
        self.source.write_bytes(b'regenerated different take')
        with patch.object(install.subprocess, 'run') as decoder, self.assertRaisesRegex(ValueError, 'source_sha256 differs'):
            install.prepare(self.plan_path, True)
        decoder.assert_not_called()
        self.assertFalse(Path('assets/audio').exists())
        self.assertFalse((self.batch / 'prepared').exists())

    def test_missing_approved_source_fails_clearly(self):
        self.source.unlink()
        with patch.object(install.subprocess, 'run') as decoder, self.assertRaisesRegex(ValueError, 'cannot verify source bytes'):
            install.prepare(self.plan_path, True)
        decoder.assert_not_called()
        self.assertFalse(Path('assets/audio').exists())

    def test_legacy_thai_requires_explicit_binding_migration(self):
        self.plan.pop('language_code')
        self.plan_path.write_text(json.dumps(self.plan))
        legacy = {'accepted': True, 'expected': 'Fire.', 'heard': 'Fire.', 'cer': 0}
        for decision in (legacy, dict(legacy, language_code='tha')):
            (self.batch / 'speech_review.json').write_text(json.dumps({'voice': decision}))
            with self.subTest(decision=decision), patch.object(install.subprocess, 'run') as decoder, self.assertRaisesRegex(ValueError, 'explicitly migrate/review'):
                install.prepare(self.plan_path, True)
            decoder.assert_not_called()
        # The omitted plan locale defaults to Thai after an explicit review
        # records the real language and binds this exact source hash.
        migrated = dict(self.approval, language_code='tha')
        (self.batch / 'speech_review.json').write_text(json.dumps({'voice': migrated}))
        self.prepare(True)
        self.assertTrue(Path('assets/audio/en/tapoh_warning.wav').exists())

    def test_later_stale_approval_blocks_earlier_valid_install_in_same_batch(self):
        later = copy.deepcopy(self.plan['jobs'][0])
        later['id'] = 'later'
        later['install']['file'] = 'en/later.wav'
        self.plan['jobs'].append(later)
        self.plan_path.write_text(json.dumps(self.plan))
        ledger = json.loads((self.batch / 'ledger.json').read_text())
        ledger['jobs']['later'] = copy.deepcopy(ledger['jobs']['voice'])
        (self.batch / 'ledger.json').write_text(json.dumps(ledger))
        decisions = {'voice': self.approval, 'later': dict(self.approval, expected='Previous wording.')}
        (self.batch / 'speech_review.json').write_text(json.dumps(decisions))
        with patch.object(install.subprocess, 'run') as decoder, self.assertRaisesRegex(ValueError, 'approval for later'):
            install.prepare(self.plan_path, True)
        decoder.assert_not_called()
        self.assertFalse(Path('assets/audio').exists())
        self.assertFalse((self.batch / 'prepared').exists())

    def test_full_plan_validation_precedes_writes(self):
        self.plan['jobs'].append({'id': 'unsafe', 'install': {'file': '../escape.wav'}})
        self.plan_path.write_text(json.dumps(self.plan))
        with patch.object(install.subprocess, 'run') as decoder, self.assertRaises(ValueError):
            install.prepare(self.plan_path, True)
        decoder.assert_not_called()
        self.assertFalse((self.batch / 'prepared').exists())
        self.assertFalse(Path('assets/audio').exists())


if __name__ == '__main__':
    unittest.main()
