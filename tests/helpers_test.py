"""Helper contracts: discovery must not expose resolved secrets or include excluded projects."""
import contextlib, io, json, os, pathlib, runpy, subprocess, sys, tempfile, unittest
from unittest.mock import patch
ROOT = pathlib.Path(__file__).resolve().parents[1]

class Helpers(unittest.TestCase):
    def test_compose_discovery_excludes_archives_and_never_emits_environment(self):
        with tempfile.TemporaryDirectory() as temp:
            base=pathlib.Path(temp); projects=base/'projects'; tools=base/'bin'; tools.mkdir(); projects.mkdir()
            for name in ['web','_archive/old','_backups/old','startup','.hidden/old']:
                folder=projects/name;folder.mkdir(parents=True);(folder/'compose.yaml').write_text('services: {}')
            docker=tools/'docker'
            docker.write_text('#!'+sys.executable+'\nimport json,os\nprint(json.dumps({"name":os.path.basename(os.getcwd()),"services":{"web":{"image":"nginx:alpine","environment":{"SECRET":"must-never-appear"}}}}))\n');docker.chmod(0o755)
            result=subprocess.run([sys.executable,str(ROOT/'contents/scripts/discover_compose.py'),str(projects)],env={**os.environ,'PATH':str(tools)+os.pathsep+os.environ['PATH']},capture_output=True,text=True,check=True)
            data=json.loads(result.stdout);self.assertEqual([s['project'] for s in data['services']],['web']);self.assertEqual(data['errors'],[]);self.assertNotIn('must-never-appear',result.stdout);self.assertNotIn('environment',result.stdout)
    def test_registry_metadata_retains_downloads_and_explicit_missing_values(self):
        response={'results':[{'repo_name':'library/nginx','star_count':42,'pull_count':123456,'is_official':True},{'repo_name':'example/web'}]}
        stream=io.StringIO()
        with patch('urllib.request.urlopen',return_value=io.StringIO(json.dumps(response))),patch.object(sys,'argv',['search_images.py','nginx']),contextlib.redirect_stdout(stream):
            runpy.run_path(str(ROOT/'contents/scripts/search_images.py'),run_name='__main__')
        data=json.loads(stream.getvalue());self.assertEqual(data[0]['pulls'],123456);self.assertTrue(data[0]['official']);self.assertIsNone(data[1]['pulls'])
    def test_event_wait_returns_the_first_event_quiet_timeout_and_failure(self):
        helper=str(ROOT/'contents/scripts/wait_events.py')
        def wait(seconds,cmd): return subprocess.run([sys.executable,'-I',helper,str(seconds),cmd],capture_output=True,text=True,timeout=20)
        event=wait(10,'echo start; echo die; sleep 30');self.assertEqual((event.returncode,event.stdout),(0,'start\n'))
        quiet=wait(1,'sleep 30');self.assertEqual((quiet.returncode,quiet.stdout),(0,''))
        failed=wait(10,'echo cannot connect >&2; exit 3');self.assertEqual(failed.returncode,3);self.assertIn('cannot connect',failed.stderr)
if __name__=='__main__':unittest.main()
