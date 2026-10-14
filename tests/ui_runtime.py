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
for i,name in enumerate(names):
 r={key:'' for key in 'id name image command createdAt runningFor state status health localVolumes networks mounts ports size platform project service composeFiles composeWorkDir composeProfile cpu mem memU blockio netio pids restartPolicy sortKey'.split()}
 r.update(id=f'{i:012x}',name=name,image=f'example/{name}:latest',command='/entrypoint',state='running' if i<8 else 'exited',status='Up 2 hours (healthy)' if i<8 else 'Exited (0) 2 days ago',health='healthy' if i<8 else 'none',isRunning=i<8,project=name,service=name,composeFiles=f'/example/{name}/compose.yaml',composeWorkDir=f'/example/{name}',cpu='2.4%' if i<8 else '',mem='1.2%' if i<8 else '',cpuPct=2.4 if i<8 else 0,memPct=1.2 if i<8 else 0,networks='media_net',mounts=('/home/example/docker/'+name+'/config,/home/example/media/music,/mnt/long storage path/container-data/'+name if i<8 else ''),ports=('127.0.0.1:8080->80/tcp, [::]:8443->443/tcp' if i<8 else ''),memU=('138 MiB / 16 GiB' if i<8 else ''),localVolumes='0',runningFor='2 hours' if i<8 else '2 days',size='0 B',platform='linux/amd64',restartPolicy='unless-stopped',pinned=False,probe='',updateAvailable=i<3,sortKey=name)
 records.append(r)
icon_dir=project/'contents/assets/library'
files=[p.name for p in icon_dir.iterdir() if p.suffix in ['.svg','.png','.webp']]

# Fictional demonstration data; no engine runner is connected.
for i,r in enumerate(records):
 if i>=12:r.update(id='configured:demo:'+r['name'],state='not-created',status='Not created',isRunning=False)
config['toolbarStyle']=3
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
 function showPage(name){popup.selectView(0);if(name==='doctor')popup.showDoctor(0);else if(name==='resources')popup.showResources();else if(name==='deploy')popup.showDeployment();else if(name==='activity')popup.showActivity();else if(name==='detail')popup.showDetail('000000000000',0);else if(name==='detail1')popup.showDetail('000000000009',0)}
 function presentation(mode,level){popup.selectView(mode);popup.selectDetail(level)}
 function level(){return popup.detailLevel}
 function mode(){return popup.viewMode}
 function minimal(){popup.selectView(0);popup.selectDetail(0)}
 function search(){popup.searchText='nav';popup.openSearch()}
 function clearSearch(){popup.searchText=''}
 Component.onCompleted: {
  backend.records='''+json.dumps(records)+'''
  backend.engineActive=true;backend.engineKnown=true;backend.endpointHost='unix:///var/run/docker.sock';backend.composeAvailable=true;backend.buildxAvailable=true
  backend.iconLibraryDir='''+json.dumps(str(icon_dir))+''';backend.iconEntries=Icons.parseLibrary('''+json.dumps('\n'.join(files))+''');backend.iconCount=16000;backend.iconRevision++
  backend.activity=[{time:Date.now(),kind:'crashed',id:'000000000002',name:'lidarr',text:'lidarr exited with code 1'},{time:Date.now()-60000,kind:'restarting',id:'000000000001',name:'deemix',text:'deemix is restarting'},{time:Date.now()-180000,kind:'recovered',id:'000000000000',name:'caddy',text:'caddy is healthy again'},{time:Date.now()-900000,kind:'started',id:'000000000003',name:'navidrome',text:'navidrome started'},{time:Date.now()-1200000,kind:'stopped',id:'',name:'beets',text:'beets stopped'}]
  backend.recomputeTotals();backend.syncModel();backend.revision++;backend.updateCount=3;backend.lastUpdatedMs=Date.now()
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
def step(index=0):
 if index==len(cases):
  if os.environ.get('DOCKMOID_UI_PAGES'):pages(0)
  else:app.quit()
  return
 w,m,l=cases[index];view.resize(w,760);view.rootObject().presentation(m,l)
 home=view.rootObject().findChild(QObject,"homeSectionPage");home.updateSetting("previewMode","selection")
 QTimer.singleShot(100,safe(lambda:check(index,w,m,l)))
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
PAGES=[(n,w) for n in (os.environ.get('DOCKMOID_UI_ONLY') or 'doctor,resources,deploy,detail,detail1,activity,dock-new,dock-resources,dock-doctor,dock-preview').split(',') for w in [1050,360]]
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
QTimer.singleShot(500,safe(step));app.exec()
errors=[m for m in messages if any(e in m for e in ['TypeError','ReferenceError','Cannot assign','Unable to assign','Required property','Binding loop'])]
(out/'runtime.log').write_text('\n'.join(messages));print('Production QML demo cases:',len(checks),'failures:',failures,'errors:',errors)
assert len(checks)==32 and not failures and not errors
