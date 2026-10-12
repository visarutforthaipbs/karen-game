import tempfile,unittest
from pathlib import Path
from generate_upload import generate
class UploadPreparation(unittest.TestCase):
 def test_missing_account_rejected_without_output(self):
  with tempfile.TemporaryDirectory() as t:
   out=Path(t)/'out'
   with self.assertRaises(ValueError):generate({'product':'base','app_id':None,'build_verified':False},out)
   self.assertFalse(out.exists())
 def test_preview_and_no_publish(self):
  with tempfile.TemporaryDirectory() as t:
   payload=Path(t)/'payload';payload.mkdir();(payload/'Game.exe').write_bytes(b'fixture')
   out=Path(t)/'out'
   generate({'product':'base','app_id':123,'build_verified':True,'depots':[{'id':456,'platform':'windows','content_root':str(payload)}]},out)
   content=(out/'app_build.vdf').read_text()
   self.assertIn('"Preview" "1"',content);self.assertNotIn('SetLive',content)
 def test_archives_rejected(self):
  with tempfile.TemporaryDirectory() as t:
   payload=Path(t)/'payload';payload.mkdir();(payload/'Game.exe').touch();(payload/'private.zip').touch()
   with self.assertRaises(ValueError):generate({'product':'demo','app_id':123,'build_verified':True,'depots':[{'id':456,'platform':'windows','content_root':str(payload)}]},Path(t)/'out')
if __name__=='__main__':unittest.main()
