"""Read Compose service identities only. Never emit environment, secrets or config bodies."""
import json, os, pathlib, subprocess, sys
root = pathlib.Path(sys.argv[1]).expanduser().resolve()
projects = []; errors = []
for folder, dirs, files in os.walk(root):
    dirs[:] = sorted(d for d in dirs if d not in {'_archive', '_backups', 'startup', '.git', 'node_modules'} and not d.startswith('.'))
    relative = pathlib.Path(folder).relative_to(root)
    if len(relative.parts) > 2:
        dirs[:] = []; continue
    filename = next((n for n in ('compose.yaml', 'compose.yml', 'docker-compose.yaml', 'docker-compose.yml', 'compose.json', 'docker-compose.json') if n in files), None)
    if not filename: continue
    # Do not walk configuration/data trees beneath an identified project.
    dirs[:] = []
    path = pathlib.Path(folder) / filename
    try:
        # --profile '*' keeps services behind profiles (optional by design) in the
        # result; Compose before 2.20 rejects the wildcard, so retry without it.
        base = ['docker','compose','-f',str(path)]
        result = subprocess.run(base+['--profile','*','config','--format','json'], cwd=folder, capture_output=True, text=True, timeout=20)
        if result.returncode:
            result = subprocess.run(base+['config','--format','json'], cwd=folder, capture_output=True, text=True, timeout=20)
        if result.returncode:
            errors.append(str(path) + ': Compose configuration could not be resolved'); continue
        config = json.loads(result.stdout)
        project = config.get('name', pathlib.Path(folder).name)
        for service, value in config.get('services', {}).items():
            projects.append({'project':project,'service':service,'name':value.get('container_name') or service,'image':value.get('image',''),'composeFiles':str(path),'composeWorkDir':folder,'profiles':value.get('profiles',[]),'missingBindPaths':[mount.get('source','') for mount in value.get('volumes',[]) if isinstance(mount,dict) and mount.get('type')=='bind' and (not os.path.exists(mount.get('source','')) or not os.access(mount.get('source',''),os.R_OK) or (os.path.isdir(mount.get('source','')) and not os.access(mount.get('source',''),os.X_OK)))],'links':[{'key':key,'label':label,'url':str((value.get('labels') or {}).get(key,''))} for key,label in [('org.opencontainers.image.source','Source repository'),('org.opencontainers.image.documentation','Documentation'),('org.opencontainers.image.url','Project'),('org.opencontainers.image.releases','Release notes'),('org.opencontainers.image.issues','Issue tracker')] if isinstance(value.get('labels'),dict) and (value.get('labels') or {}).get(key)]})
    except (OSError, ValueError, subprocess.TimeoutExpired):
        errors.append(str(path) + ': Compose discovery failed')
print(json.dumps({'services':projects,'errors':errors}))
