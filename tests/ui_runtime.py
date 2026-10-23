import os,pathlib,json,tempfile,xml.etree.ElementTree as ET
os.environ['QT_QPA_PLATFORM']='offscreen';os.environ['QT_QUICK_BACKEND']='software';os.environ['QT_QUICK_CONTROLS_STYLE']='org.kde.desktop'
from PySide6.QtWidgets import QApplication
from PySide6.QtGui import QPalette,QColor
from PySide6.QtQuick import QQuickView
from PySide6.QtCore import QUrl,QTimer,QObject,QMetaObject,Qt,QPoint,QPointF,qInstallMessageHandler
from PySide6.QtTest import QTest
project=pathlib.Path(__file__).resolve().parents[1]
out=pathlib.Path(tempfile.mkdtemp(prefix='dockmoid-ui-'))
config={}
for entry in ET.parse(project/'contents/config/main.xml').getroot().findall('.//{*}entry'):
 default=entry.find('{*}default'); value=default.text if default is not None and default.text is not None else ''
 typ=entry.attrib['type'].lower()
 if typ=='bool':value=value.lower()=='true'
 elif typ in ['int','uint','longlong','ulonglong']:value=int(value or 0)
 elif typ=='double':value=float(value or 0)
 config[entry.attrib['name']]=value
config.update(defaultViewMode=0,defaultDetailLevel=0,sortRole='name',sortAscending=True,showHeader=True,showStatusBar=True,coloredServiceIcons=True,customIcons='',customIconFiles='{}',checkImageUpdates=True)
config_qml='\n'.join('property var '+key+': '+json.dumps(value) for key,value in config.items())
records=[]
names=['caddy','deemix','lidarr','navidrome','pihole','portainer','slskd','syncthing','beets','cliproxyapi','dockge','dozzle','flaresolverr','homepage','metube','obsidian']
PERF=int(os.environ.get('DOCKMOID_UI_PERF','0') or 0)
if PERF>len(names):names=names+['svc%03d'%i for i in range(len(names),PERF)]
RUN=lambda i:(i<8) if not PERF else (i%3!=0)
for i,name in enumerate(names):
 r={key:'' for key in 'id name image command createdAt runningFor state status health localVolumes networks mounts ports size platform project service composeFiles composeWorkDir composeProfile cpu mem memU blockio netio pids restartPolicy sortKey'.split()}
 r.update(id=f'{i:012x}',name=name,image=f'example/{name}:latest',command='/entrypoint',state='running' if RUN(i) else 'exited',status='Up 2 hours (healthy)' if RUN(i) else 'Exited (0) 2 days ago',health='healthy' if RUN(i) else 'none',isRunning=RUN(i),project=name,service=name,composeFiles=f'/example/{name}/compose.yaml',composeWorkDir=f'/example/{name}',cpu='2.4%' if i<8 else '',mem='1.2%' if i<8 else '',cpuPct=2.4 if i<8 else 0,memPct=1.2 if i<8 else 0,networks='media_net',mounts=('/home/example/docker/'+name+'/config,/home/example/media/music,/mnt/long storage path/container-data/'+name if i<8 else ''),ports=('127.0.0.1:8080->80/tcp, [::]:8443->443/tcp' if i<8 else ''),memU=('138 MiB / 16 GiB' if i<8 else ''),localVolumes='0',runningFor='2 hours' if i<8 else '2 days',size='0 B',platform='linux/amd64',restartPolicy='unless-stopped',pinned=False,probe='',updateAvailable=i<3,sortKey=name)
 records.append(r)
icon_dir=project/'contents/assets/library'
files=[p.name for p in icon_dir.iterdir() if p.suffix in ['.svg','.png','.webp']]

# Fictional demonstration data; no engine runner is connected.
for i,r in enumerate(records):
 if 12<=i<16:r.update(id='configured:demo:'+r['name'],state='not-created',status='Undeployed',isRunning=False)
config['toolbarStyle']=3
# DOCKMOID_UI_SECTIONS=1 keeps the default state order, so the list shows its section headings.
if os.environ.get('DOCKMOID_UI_SECTIONS'):config['sortRole']='sortKey'
config_qml='\n'.join('property var '+key+': '+json.dumps(value) for key,value in config.items())
qml='''import QtQuick
import "'''+(project/'contents/ui/Backend').as_uri()+'''" as Backend
import "'''+(project/'contents/ui/Views').as_uri()+'''" as Views
import "'''+(project/'contents/lib').as_uri()+'''/icons.js" as Icons
Rectangle {
 id:root; width:932; height:700; color:"#292e32"
 function i18n(s) { for(var n=1;n<arguments.length;n++) s=s.replace('%'+n,arguments[n]); return s }
 function i18np(s,p,n) { var out=n===1?s:p; for(var a=2;a<arguments.length;a++)out=out.replace('%'+(a-1),arguments[a]);return out }
 QtObject {id:config;'''+config_qml+'''}
 property QtObject plasmoid: QtObject {property var configuration:config}
 QtObject { id:applet; function toggleDetached(){} function configure(){} }
 Backend.DockerBackend {id:backend;cfg:config;runner:null}
 Views.PopupView {id:popup;anchors.fill:parent;backend:backend;applet:applet}
 function enableCompose(){backend.endpointHost="unix:///var/run/docker.sock";backend.composeAvailable=true}
 function toolbar(style){config.toolbarStyle=style}
 function everything(){popup.selectView(0);popup.selectDetail(3)}
 function grid(){popup.selectView(3)}
 function tick(){var r=backend.records;for(var i=0;i<r.length;i++){if(r[i].isRunning){r[i].cpuPct=(r[i].cpuPct*7+i)%9;r[i].cpu=r[i].cpuPct.toFixed(2)+'%';r[i].memPct=(r[i].memPct*5+i)%7;r[i].mem=r[i].memPct.toFixed(2)+'%'}}backend.syncModel();backend.recomputeTotals();backend.revision++}
 function typeSearch(t){popup.searchText=t}
 function showPage(name){popup.selectView(0);if(name==='doctor')popup.showDoctor(0);else if(name==='resources')popup.showResources();else if(name==='deploy')popup.showDeployment();else if(name==='deploy-form')popup.showDeployment(1);else if(name==='deploy-results'){popup.showDeployment();backend.deployment.searchPerformed=true;backend.deployment.results=[{name:'linuxserver/sonarr',stars:1903,pulls:2372530000,official:false,description:'A Sonarr container, brought to you by LinuxServer.io.'},{name:'linuxserver/radarr',stars:1802,pulls:2372530000,official:false,description:'A Radarr container, brought to you by LinuxServer.io.'},{name:'nginx',stars:20500,pulls:1000000000,official:true,description:'Official build of Nginx.'},{name:'linuxserver/qbittorrent',stars:1687,pulls:346571000,official:false,description:''},{name:'example/very-long-repository-name-for-layout',stars:3,pulls:null,official:false,description:'A deliberately long description that should wrap onto a second line and then be elided after it so every card keeps the same height.'}]}else if(name==='activity')popup.showActivity();else if(name==='detail')popup.showDetail('000000000000',0);else if(name==='detail1')popup.showDetail('000000000009',0)}
 function presentation(mode,level){popup.selectView(mode);popup.selectDetail(level)}
 function level(){return popup.detailLevel}
 function mode(){return popup.viewMode}
 function minimal(){popup.selectView(0);popup.selectDetail(0)}
 // DOCKMOID_UI_MENU=1 prints a container's menu as an indented tree.
 function menuTree(id,state){var rec=backend.findRecord(id);if(state)rec=Object.assign({},rec,{state:state,isRunning:state==='running'});var comp=Qt.createComponent("'''+(project/'contents/ui/components/ContainerActions.qml').as_uri()+'''");if(comp.status!==Component.Ready)return comp.errorString();var m=comp.createObject(root,{backend:backend,record:rec,dialogs:null});m.rebuild();var out=[];function walk(menu,depth){for(var i=0;i<menu.count;i++){var it=menu.itemAt(i);if(!it)continue;var sub=it.subMenu;var label=sub?sub.title+' >':(it.label!==undefined?it.label:(it.text||'---'));if(it.isSectionHeader)label='['+label+']';out.push('  '.repeat(depth)+label);if(sub)walk(sub,depth+1)}}walk(m,0);m.destroy();return out.join('\n')}
 function search(){popup.searchText='nav';popup.openSearch()}
 function clearSearch(){popup.searchText=''}
 Component.onCompleted: {
  backend.records='''+json.dumps(records)+'''
  backend.engineActive=true;backend.engineKnown=true;backend.endpointHost='unix:///var/run/docker.sock';backend.composeAvailable=true;backend.buildxAvailable=true
  backend.iconLibraryDir='''+json.dumps(str(icon_dir))+''';backend.iconEntries=Icons.parseLibrary('''+json.dumps('\n'.join(files))+''');backend.iconCount=16000;backend.iconRevision++
  backend.activity=[{time:Date.now(),kind:'crashed',id:'000000000002',name:'lidarr',text:'lidarr exited with code 1'},{time:Date.now()-60000,kind:'restarting',id:'000000000001',name:'deemix',text:'deemix is restarting'},{time:Date.now()-180000,kind:'recovered',id:'000000000000',name:'caddy',text:'caddy is healthy again'},{time:Date.now()-900000,kind:'started',id:'000000000003',name:'navidrome',text:'navidrome started'},{time:Date.now()-1200000,kind:'stopped',id:'',name:'beets',text:'beets stopped'}]
  backend.resourceUpdatedAt={images:Date.now()+1e9,volumes:Date.now()+1e9,networks:Date.now()+1e9}
  backend.resourceLists={images:[{id:'sha256:a1',ref:'caddy:2',repository:'caddy',tag:'2',size:'94.6MB',created:'2 weeks ago',containers:1},{id:'sha256:a2',ref:'amir20/dozzle:latest',repository:'amir20/dozzle',tag:'latest',size:'98.8MB',created:'10 days ago',containers:0},{id:'sha256:a3',ref:'ghcr.io/home-assistant/home-assistant:stable',repository:'ghcr.io/home-assistant/home-assistant',tag:'stable',size:'3.4GB',created:'12 days ago',containers:2}],volumes:[{name:'dozzle_data',driver:'local',size:'1.147kB',links:0},{name:'komodo_keys',driver:'local',size:'464B',links:2}],networks:[{name:'media_net',driver:'bridge',scope:'local'},{name:'host',driver:'host',scope:'local',builtin:true}]}
  backend.applySort();backend.recomputeTotals();backend.syncModel();backend.revision++;backend.updateCount=3;backend.lastUpdatedMs=Date.now()
 }
}'''

app=QApplication([]);pal=app.palette()
for role,color in [(QPalette.Window,'#292e32'),(QPalette.WindowText,'#eff0f1'),(QPalette.Base,'#24292d'),(QPalette.Text,'#eff0f1'),(QPalette.Button,'#31363b'),(QPalette.ButtonText,'#eff0f1')]:pal.setColor(role,QColor(color))
app.setPalette(pal);messages=[];qInstallMessageHandler(lambda t,c,m:messages.append(m))
qml=qml[:-1]+'''function previewTarget(){function find(item){if(item.containerKey && item.visible && item.width>0 && item.height>0)return item;for(let child of item.children){const found=find(child);if(found)return found}return null}const item=find(root);if(!item)return '{}';const p=item.mapToItem(root,60,14);return JSON.stringify({x:p.x,y:p.y,id:item.containerKey})} function previewSelected(){return backend.previewRecordId} }'''
file=out/'Preview.qml';file.write_text(qml)
view=QQuickView();view.setResizeMode(QQuickView.SizeRootObjectToView);view.setSource(QUrl.fromLocalFile(str(file)));assert view.status()!=QQuickView.Error,[e.toString() for e in view.errors()];view.resize(1050,760);view.show();failures=[]
def safe(fn):
 def run():
  try:fn()
  except BaseException as e:failures.append(repr(e));app.quit()
 return run
def popup():return [x for x in view.rootObject().findChildren(QObject) if x.metaObject().className().startswith('PopupView')][0]
def capture(name):view.grabWindow().save(str(out/name))
cases=[(w,m,l) for w in [360,1050] for m in [0,1,2,3] for l in range(4)]
checks=[]
def menus():
 # Every lazily built menu must open when asked; a silent failure here once left the toolbar dead.
 found=[x for x in view.rootObject().findChildren(QObject) if x.metaObject().className().startswith('LazyMenu')]
 assert len(found)>=6,('lazy menus',len(found))
 for m in found:
  m.popup(popup(),0,0);QTest.qWait(250)
  if not m.property('opened'):failures.append(('menu did not open',m.objectName() or str(m)))
  m.close();QTest.qWait(100)
def step(index=0):
 if index==len(cases):
  menus()
  if os.environ.get('DOCKMOID_UI_PAGES'):pages(0)
  else:app.quit()
  return
 w,m,l=cases[index];view.resize(w,760);view.rootObject().presentation(m,l)
 QTest.mouseMove(view,QPoint(w-3,757))  # keep the pointer off the toolbar, whose tooltip would cover the first row
 home=view.rootObject().findChild(QObject,"homeSectionPage");home.updateSetting("previewMode","selection")
 QTimer.singleShot(300,safe(lambda:check(index,w,m,l)))
def check(index,w,m,l):
 assert popup().width()>0
 if os.environ.get('DOCKMOID_UI_CAPTURE_DIR'):
  folder=pathlib.Path(os.environ['DOCKMOID_UI_CAPTURE_DIR']);folder.mkdir(parents=True,exist_ok=True);view.grabWindow().save(str(folder/f'before-click-w{w}-m{m}-l{l}.png'))
 target=json.loads(view.rootObject().previewTarget());assert target, (w,m,l,'no preview target')
 QTest.mouseClick(view,Qt.LeftButton,Qt.NoModifier,QPoint(round(target['x']),round(target['y'])));app.processEvents()
 assert view.rootObject().previewSelected()==target['id'], (w,m,l,'selection preview')
 image=view.grabWindow();assert not image.isNull()
 if os.environ.get('DOCKMOID_UI_CAPTURE_DIR'):
  folder=pathlib.Path(os.environ['DOCKMOID_UI_CAPTURE_DIR']);folder.mkdir(parents=True,exist_ok=True);image.save(str(folder/f'w{w}-m{m}-l{l}.png'))
 checks.append([w,m,l]);step(index+1)
PAGES=[(n,w) for n in (os.environ.get('DOCKMOID_UI_ONLY') or 'doctor,resources,deploy,deploy-results,deploy-form,detail,detail1,activity,dock-logs,dock-events,dock-compose,dock-preview').split(',') for w in [1050,360]]
def pages(i):
 if i==len(PAGES):app.quit();return
 n,w=PAGES[i];view.resize(w,760)
 if n.startswith('dock-'):
  home=view.rootObject().findChild(QObject,"homeSectionPage");home.setDock("page",n[5:]);home.setDock("expanded",True)
  if n=='dock-preview':QTest.mouseClick(view,Qt.LeftButton,Qt.NoModifier,QPoint(120,200))
 else:view.rootObject().showPage(n)
 def grab():
  folder=pathlib.Path(os.environ.get('DOCKMOID_UI_CAPTURE_DIR') or out);folder.mkdir(parents=True,exist_ok=True)
  view.grabWindow().save(str(folder/f'page-{n}-w{w}.png'));view.rootObject().presentation(0,1);(view.rootObject().findChild(QObject,'homeSectionPage').setDock('page','preview') if n.startswith('dock-') else None);QTimer.singleShot(150,safe(lambda:pages(i+1)))
 QTimer.singleShot(700,safe(grab))

def perf():
 from PySide6.QtCore import QElapsedTimer,QMetaObject,Q_ARG
 root=view.rootObject();res={}
 def settle(ms=60):
  QTest.qWait(ms);app.processEvents()
 def timed(fn,runs=1):
  t=QElapsedTimer();t.start()
  for _ in range(runs):fn();app.processEvents()
  return t.elapsed()/runs
 settle(500)
 res['objects']=len(root.findChildren(QObject));print('objects',res['objects'],flush=True)
 if os.environ.get('DOCKMOID_UI_PERF_DUMP'):
  rowsx=[x for x in root.findChildren(QObject) if x.property('containerKey') not in (None,'') and x.property('detailLevel') is not None]
  if rowsx:print('ROWS',len(rowsx),'objects in first row',len(rowsx[0].findChildren(QObject))+1,flush=True)
  from collections import Counter
  c=Counter(x.metaObject().className().split('_QMLTYPE')[0].split('_QML_')[0] for x in root.findChildren(QObject));print('TOP',c.most_common(30),flush=True)
  pv=[x for x in root.findChildren(QObject) if x.metaObject().className().startswith('PopupView')][0]
  rows=[]
  def walk(o,depth):
   for ch in o.children():
    n=len(ch.findChildren(QObject))+1
    rows.append((n,depth,ch.metaObject().className().split('_QML')[0],ch.objectName()))
  walk(pv,0)
  rows.sort(reverse=True);print('PV_CHILDREN',rows[:14],flush=True)
  # one level down for the biggest
  big=sorted([(len(ch.findChildren(QObject))+1,ch) for ch in pv.children()],key=lambda t:-t[0])[:2]
  for n,ch in big:
   sub=sorted([(len(g.findChildren(QObject))+1,g.metaObject().className().split('_QML')[0],g.objectName()) for g in ch.children()],reverse=True)[:8];print('INSIDE',ch.metaObject().className().split('_QML')[0],n,sub,flush=True)
 res['containers']=len(records)
 call=lambda name,*a:QMetaObject.invokeMethod(root,name)
 res['tick_ms']=round(timed(lambda:call('tick'),30),1);print('tick',res['tick_ms'],flush=True)
 for label,fn in [('list',lambda:root.presentation(0,1)),('table',lambda:root.presentation(1,1)),('grid',lambda:root.presentation(3,1)),('groups',lambda:root.presentation(2,1)),('list_again',lambda:root.presentation(0,1))]:
  print('switch',label,flush=True);res['switch_to_'+label+'_ms']=round(timed(fn),1);settle(400);res['objects_'+label]=len(root.findChildren(QObject))
 res['tick_ms_after']=round(timed(lambda:call('tick'),30),1)
 def typing():
  for t in ['s','sv','svc','svc0','svc01']:
   QMetaObject.invokeMethod(root,'typeSearch',Q_ARG('QVariant',t));app.processEvents()
  QMetaObject.invokeMethod(root,'typeSearch',Q_ARG('QVariant',''))
 res['type_5_chars_ms']=round(timed(typing),1)
 import json;print('PERF',json.dumps(res));app.quit()
def menu_dump():
 for rid in ['000000000000','000000000009']:
  view.rootObject().enableCompose();print('--- menu for',rid);print(view.rootObject().menuTree(rid,''),flush=True)
 print('--- menu for 000000000001 as paused');print(view.rootObject().menuTree('000000000001','paused'),flush=True)
 app.quit()
if os.environ.get('DOCKMOID_UI_MENU'):QTimer.singleShot(800,safe(menu_dump))
elif os.environ.get('DOCKMOID_UI_PERF'):QTimer.singleShot(1500,safe(perf))
else:QTimer.singleShot(500,safe(step))
app.exec()
errors=[m for m in messages if any(e in m for e in ['TypeError','ReferenceError','Cannot assign','Unable to assign','Required property','Binding loop'])]
(out/'runtime.log').write_text('\n'.join(messages));print('Production QML demo cases:',len(checks),'failures:',failures,'errors:',errors)
assert (os.environ.get('DOCKMOID_UI_PERF') or os.environ.get('DOCKMOID_UI_MENU') or len(checks)==32) and not failures and not errors
