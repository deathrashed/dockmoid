"""Docker Hub search metadata only; no pulls or container mutations."""
import json,sys,urllib.request,urllib.parse
query=sys.argv[1] if len(sys.argv)>1 else ''
url='https://hub.docker.com/v2/search/repositories/?'+urllib.parse.urlencode({'query':query,'page_size':50})
try:
    request=urllib.request.Request(url,headers={'User-Agent':'Dockmoid/2.4.0'})
    data=json.load(urllib.request.urlopen(request,timeout=20))
    print(json.dumps([{'name':r.get('repo_name',''),'description':r.get('short_description',''),'stars':r.get('star_count',0),'pulls':r.get('pull_count'),'official':bool(r.get('is_official',False))} for r in data.get('results',[])]))
except Exception as error:
    print('Docker Hub search unavailable: '+str(error),file=sys.stderr);sys.exit(1)
