"""Exercise the documented release-pair builder, not just the legacy manifest path."""
import json,pathlib,subprocess,tempfile,unittest,xml.etree.ElementTree as ET,zipfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
class ReleaseArchive(unittest.TestCase):
    def test_archives_contain_helpers_docs_and_consistent_versions(self):
        version=json.loads((ROOT/'metadata.json').read_text())['KPlugin']['Version']
        self.assertEqual(ET.parse(ROOT/'packaging/dockmoid.plasmoid.appdata.xml').find('.//release').get('version'),version)
        with tempfile.TemporaryDirectory() as temp:
            dest=pathlib.Path(temp)/'release'
            subprocess.run([str(ROOT/'package-release.sh'),str(dest)],check=True,capture_output=True,text=True)
            subprocess.run(['sha256sum','-c','SHA256SUMS'],cwd=dest,check=True,capture_output=True)
            with zipfile.ZipFile(dest/f'dockmoid-{version}.plasmoid') as z:
                names=z.namelist()
                for name in ['metadata.json','LICENSE','THIRD_PARTY_NOTICES.md','contents/scripts/discover_compose.py','contents/scripts/search_images.py','contents/ui/Views/DoctorPage.qml']:
                    self.assertIn(name,names)
                self.assertFalse(any(p.startswith('.git/') or '/__pycache__/' in p or p.endswith('.env') for p in names))
            with zipfile.ZipFile(dest/f'dockmoid-{version}-source.zip') as z:
                for name in ['README.md','docs/STORE_LISTING.md','docs/USER_GUIDE.md','SECURITY.md','tests/helpers_test.py','.github/workflows/check.yml']:
                    self.assertIn(f'dockmoid-{version}/'+name,z.namelist())
if __name__=='__main__':unittest.main()
