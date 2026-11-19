import {loadRun,clamp,hingePhase} from './data.js';
import {icon,installIcons} from './icons.js';
import {drawPlot,drawWave,plotTypes} from './charts.js';
import {makeScene} from './scene.js';
import {createAR} from './ar.js';

installIcons();
const $=id=>document.getElementById(id);
const viewText={
  specimen:['EXPERIMENTAL LABORATORY','Nonlinear SP3','W8×28 steel column <em>/</em> El Centro ×3.5'],
  frame:['CONSTRUCTION SITE · HYBRID ASSEMBLY','Coupled frame','Physical SP3 <em>/</em> Three-story numerical frame'],
  path:['MEASURED RESPONSE','Response space','Displacement, force and earthquake time'],
  camera:['SYNCHRONIZED MEDIA','Test footage','Nonlinear SP3 <em>/</em> 11 November 2026']
};
const state={mode:'specimen',media:'raw',t:7.03,play:false,rate:1,scale:1,plots:true,guides:false,lens:false};
let run,world,ar,arSupported=false,drawNeeded=true,lastNow=null,lastHUD=-Infinity,plotDialog=null;
let priorLayout='',lastChartT=NaN,cards=[],closeFocus=null;
const instruments=[$('instrument-a'),$('instrument-b')],videoRaw=$('footage'),videoFilm=$('analysis');
const clock=t=>t.toFixed(2).padStart(5,'0');
const plotNames=()=>state.mode==='frame'?['roof','ground']:['displacement','hysteresis'];
const touch=()=>{drawNeeded=true;world?.invalidate();};
function togglePlay(force){
  state.play=typeof force==='boolean'?force:!state.play;
  if(state.play&&state.t>=run.duration-.0001)state.t=0;
  $('play').innerHTML=icon(state.play?'pause':'play');$('play').setAttribute('aria-label',state.play?'Pause experiment':'Play experiment');
  $('xr-play').textContent=state.play?'Pause':'Play';
  if($('detail-play'))$('detail-play').textContent=state.play?'Pause replay':'Play replay';
  lastNow=null;syncVideo();touch();
}
function seek(v){state.t=clamp(Number(v),0,run.duration);lastNow=null;touch();syncVideo(true);renderHUD();}
function quietVideo(){for(const v of [videoRaw,videoFilm])if(!v.paused)v.pause();}
function syncVideo(force=false){
  const lens=state.lens&&state.mode==='specimen';
  if(!run||(state.mode!=='camera'&&!lens)){quietVideo();return;}
  const raw=lens||state.media==='raw';
  const v=raw?videoRaw:videoFilm,other=raw?videoFilm:videoRaw;
  other.pause();other.hidden=true;
  const rawClock=run.sample(state.t,8)-run.cameraLabStart;
  const gap=raw&&(rawClock<0||rawClock>=run.cameraSeconds);
  $('camera-gap').hidden=!gap;v.hidden=gap;
  $('media-caption').textContent=raw?'Lab recording · 20× lab speed at 1× replay':'Analysis film · earthquake time';
  if(gap){v.pause();return;}

  if(!v.hasAttribute('src'))v.src=v.dataset.file;
  if(v.error){
    $('media-caption').textContent='Could not open the recording.';
    return;
  }
  // Both clips are encoded on the earthquake clock. The lab clip starts partway through the test.
  const stream=state.play&&state.rate>=.25;
  if(v.readyState>=HTMLMediaElement.HAVE_METADATA){
    const frameTime=raw?rawClock/run.timeScale:state.t;
    const target=clamp(frameTime,0,Math.max(0,v.duration-1/30));
    if((force||!v.seeking)&&Math.abs(v.currentTime-target)>(stream&&!force?.15:.016))v.currentTime=target;
  }
  if(stream){
    v.playbackRate=state.rate;
    if(v.paused)v.play().catch(()=>{});
  }else if(!v.paused)v.pause();
}
function setWalk(on){
  if(!world)return;world.setWalk(on);for(const [id,val] of [['orbit',!on],['walk',on]]){$(id).classList.toggle('selected',val);$(id).setAttribute('aria-pressed',String(val));}
  $('walk-pad').hidden=!on;$('axis').hidden=on||state.mode==='camera';$('nav-hint').innerHTML=on?'Drag to look <em>·</em> WASD to move':state.mode==='frame'?'Click a hinge to inspect it':state.mode==='path'?'Click the trajectory to seek':'Drag to orbit <em>·</em> Scroll to zoom';
  touch();
}
function setMode(name){
  if(!viewText[name])return;state.mode=name;$('stage').dataset.mode=name;
  const [k,title,sub]=viewText[name];$('section-kicker').textContent=k;$('scene-title').textContent=title;$('scene-subtitle').innerHTML=sub;
  $('views').querySelectorAll('[data-mode]').forEach(b=>{const active=b.dataset.mode===name;b.classList.toggle('active',active);b.setAttribute('aria-pressed',String(active));});
  closePopover();world?.setMode(name);setWalk(false);const isCam=name==='camera';
  $('camera-bay').hidden=!isCam;$('leaders').hidden=isCam;$('viewport').style.visibility=isCam?'hidden':'visible';$('scene-error').hidden=!!world||isCam;
  $('nav-pad').parentElement.hidden=isCam||!world;$('axis').hidden=isCam||!world;$('layer-button').hidden=isCam||!world;$('motion-setting').hidden=name==='path';
  $('instruments').hidden=isCam||!world||!state.plots;$('view-key').hidden=!['frame','path'].includes(name);$('lens-setting').hidden=name!=='specimen';
  $('probe-label').hidden=$('spec-label').hidden=name!=='specimen';$('interface-focus').hidden=name!=='frame';$('rig-cameras').hidden=name!=='specimen';$('rig-camera').value='';quietVideo();
  if(isCam)syncVideo(true);
  for(let i=0;i<2;i++)instruments[i].setAttribute('aria-label','Inspect '+plotTypes[plotNames()[i]].title.toLowerCase()+' plot');
  lastChartT=NaN;priorLayout='';touch();
}
function closePopover(){
  for(const [p,b] of [['layer-menu','layer-button'],['event-menu','events']]){$(p).hidden=true;$(b).setAttribute('aria-expanded','false');}
}
function pop(p,b){const open=$(p).hidden;closePopover();$(p).hidden=!open;$(b).setAttribute('aria-expanded',String(open));}
function modal(k,title,html,source){
  closePopover();closeFocus=source??document.activeElement;$('dialog-kicker').textContent=k;$('dialog-title').textContent=title;$('dialog-body').innerHTML=html;$('modal').showModal();$('close-modal').focus();world?.keys.clear();
}
function inspect(i){
  plotDialog=plotNames()[i];const cfg=plotTypes[plotDialog];
  const detail={
    displacement:'Solid blue is measured actuator displacement (dₘ). Dashed black is the numerical interface displacement (dₙ) replayed from measured force.',
    hysteresis:'Each point pairs measured displacement with measured force at the same instant. The dark purple trail follows the latest 1.25 seconds. The pale trace gives the full test envelope.',
    roof:'Roof displacement is the third-floor translation of the numerical substructure, replayed from measured feedback force.',
    ground:'Ground acceleration is the scaled El Centro input on the earthquake clock.'
  }[plotDialog];
  modal('SIGNAL INSPECTION',cfg.title,'<canvas id="dialog-plot" aria-label="'+cfg.title+' over the test"></canvas><p>'+detail+'</p><input id="detail-time" aria-label="Inspect time in seconds" type="range" min="0" max="'+run.duration+'" step=".005" style="width:100%;accent-color:var(--lime)"><div class="dialog-foot"><output id="detail-stamp"></output><button id="detail-play" class="primary">'+(state.play?'Pause replay':'Play replay')+'</button></div>',instruments[i]);
  $('detail-time').oninput=e=>seek(e.target.value);$('detail-play').onclick=()=>togglePlay();renderHUD();
}
function testInfo(){
  plotDialog=null;
  modal('EXPERIMENT RECORD','Nonlinear SP3',
    '<dl><dt>Test</dt><dd>sp3_r_2 · 11 Nov 2026</dd><dt>Ground motion</dt><dd>El Centro ×3.5</dd><dt>Interface height</dt><dd>1.016 m above the base</dd><dt>Earthquake record</dt><dd>37.52 s · lab time stretched 20×</dd><dt>Replay sampling</dt><dd>200 Hz traces · 30 Hz FEM states</dd><dt>Original file</dt><dd>20261111_1810_testing_OSI.mat</dd></dl>'+
    '<figure class="setup-photo"><img src="./media/sp3-setup.webp" alt="Actual SP3 column anchored to its concrete footing, with steel hold-down channels, yellow rod caps and the actuator reaction bracket at right"><figcaption>SP3 test setup · supplied laboratory photograph</figcaption></figure>'+
    '<p>The W8×28 specimen follows measured displacement. The 1.016 m pin height is calibrated. The clamp channels, concrete blocks, gusset plates, clevis and hoses are reconstructed from the photo and recording. Concealed fixings and support dimensions are approximate.</p>'+
    '<p>On site, the blue W8×28 is the physical specimen. It follows measured displacement up to the pin. A short visual transition joins it to the independently replayed numerical position. In the lab, the specimen has its steel finish and includes the unloaded length above the pin.</p>'+
    '<p>The frame uses 20 replayed DOFs. Amber paint marks a member end that has reached yield. Red marks its first recorded plastic rotation and persists for the rest of the replay. The painted length is a visual marker. These states come from the numerical model.</p>'+
    '<p class="source-note">The laboratory building, the site, the sky and the clouds are modeled in 3D with photo-scanned Poly Haven materials (CC0). The building, site and bolted connection details are illustrative.</p>'+
    '<p class="source-note">Source: sp3_r_2_anim_data.mat. Measured traces use the source replay’s 4 Hz lab-time low-pass filter. Original camera time equals lab time minus 178.64 s. The analysis film uses displacement-matched frames after camera coverage ends.</p>',$('notes'));
}
function arHelp(message=''){
  plotDialog=null;modal('IMMERSIVE VIEW','Place SP3 in your room',
    '<p>'+(message||'Open this page in a WebXR browser with immersive AR and surface tracking, such as Chrome on an ARCore-capable Android device.')+'</p><p>Aim at a clear horizontal surface and tap the placement ring. Walk around the rig to inspect the measured response. You can switch between full size and 35% tabletop scale.</p><button id="return-3d" class="primary">Explore in 3D</button>',$('ar'));
  $('return-3d').onclick=()=>{$('modal').close();setMode('specimen');world?.resetView();};
}
function buildEvents(){
  const list=[[0,'Start of earthquake'],[Math.ceil(run.cameraStart*100)/100,'Camera begins'],[Math.min(...run.firstYield.filter(t=>t!==null)),'First yield'],[run.firstHinge,'First plastic hinge'],[run.peakTime,'Peak |dₘ|'],[run.lastHinge,'Last hinge onset'],[run.cameraEnd,'Camera ends'],[run.duration,'End of record']];
  for(const [t,title] of list){
    const b=document.createElement('button'),s=document.createElement('span'),tm=document.createElement('time');s.textContent=title;tm.textContent=t.toFixed(2)+' s';b.append(s,tm);b.onclick=()=>{togglePlay(false);seek(t);closePopover();};$('event-list').append(b);
  }
}
function wire(){
  let down=null;
  $('viewport').addEventListener('pointerdown',e=>{down=[e.clientX,e.clientY];});
  $('viewport').addEventListener('pointerup',e=>{
    if(!down||Math.hypot(e.clientX-down[0],e.clientY-down[1])>5)return;
    down=null;const hit=world?.pick(e.clientX,e.clientY);if(!hit)return;togglePlay(false);
    if(hit.time!==undefined){seek(hit.time);return;}
    const j=hit.hinge,k=Math.min(run.frameCount-1,state.t*run.frameHz),lo=Math.floor(k),hi=Math.min(lo+1,run.frameCount-1);
    const at=i=>run.frames[i*(run.dofs+run.labels.length)+run.dofs+j];
    const rotation=1000*(at(lo)+(at(hi)-at(lo))*(k-lo));
    const ft=v=>v===null?'No onset in this record':v.toFixed(4)+' s';
    const pl=run.firstPlastic[j],yi=run.firstYield[j],phase=pl!==null&&state.t>=pl?'Plastic rotation recorded':yi!==null&&state.t>=yi?'Yield recorded':'Elastic';
    modal('NUMERICAL HINGE',run.labels[j],'<dl><dt>Replay time</dt><dd>'+clock(state.t)+' s</dd><dt>State at cursor</dt><dd>'+phase+'</dd><dt>Plastic rotation</dt><dd>'+rotation.toFixed(4)+' mrad</dd><dt>First yield</dt><dd>'+ft(yi)+'</dd><dt>First plastic rotation</dt><dd>'+ft(pl)+'</dd></dl>'+ (pl===null?'':'<button id="hinge-jump" class="primary">Jump to plastic onset</button>'));
    if($('hinge-jump'))$('hinge-jump').onclick=()=>{$('modal').close();seek(pl);};
  });
  $('play').onclick=()=>togglePlay();$('time').oninput=e=>seek(e.target.value);$('rate').onchange=e=>{state.rate=+e.target.value;syncVideo(true);};
  $('views').onclick=e=>{const b=e.target.closest('button');if(b)setMode(b.dataset.mode);};
  $('scene-error').querySelector('button').onclick=()=>setMode('camera');
  $('notes').onclick=testInfo;$('events').onclick=()=>pop('event-menu','events');$('layer-button').onclick=()=>pop('layer-menu','layer-button');
  $('show-plots').onchange=e=>{state.plots=e.target.checked;touch();};$('show-guides').checked=state.guides;$('show-guides').onchange=e=>{state.guides=e.target.checked;touch();};
  $('camera-lens').onchange=e=>{state.lens=e.target.checked;syncVideo(true);touch();};
  $('motion').onchange=e=>{state.scale=+e.target.value;touch();};
  $('reset-view').onclick=()=>{setWalk(false);world?.resetView();$('rig-camera').value='';};$('walk').onclick=()=>setWalk(true);$('orbit').onclick=()=>setWalk(false);
  $('rig-camera').onchange=e=>{setWalk(false);world.resetView(e.target.value);closePopover();touch();};
  $('interface-focus').onclick=()=>{setWalk(false);world.resetView(!world.inspecting);touch();};
  for(const [i,b] of instruments.entries())b.onclick=()=>inspect(i);
  $('close-modal').onclick=()=>$('modal').close();$('modal').addEventListener('close',()=>{plotDialog=null;closeFocus?.focus?.({preventScroll:true});touch();});
  $('modal').addEventListener('click',e=>{if(e.target===$('modal')){const r=$('modal').getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)$('modal').close();}});
  $('camera-jump').onclick=()=>seek(Math.ceil(run.cameraStart*100)/100);
  for(const b of document.querySelectorAll('[data-media]'))b.onclick=()=>{state.media=b.dataset.media;for(const a of document.querySelectorAll('[data-media]'))a.setAttribute('aria-pressed',String(a===b));syncVideo(true);};
  for(const v of [videoRaw,videoFilm])v.addEventListener('loadedmetadata',()=>syncVideo(true));
  $('fullscreen').onclick=async()=>{if(document.fullscreenElement)await document.exitFullscreen();else if(document.documentElement.requestFullscreen)await document.documentElement.requestFullscreen();};
  if(!document.fullscreenEnabled)$('fullscreen').hidden=true;
  $('ar').onclick=async()=>{
    if(!arSupported||!ar){arHelp();return;}
    try{await ar.enter();}catch(e){arHelp(e.name==='NotAllowedError'?'The browser needs permission to start the AR session. You can try Enter AR again.':'The device could not start a surface-tracked AR session in this browser.');}
  };
  for(const b of document.querySelectorAll('[data-step]')){b.onpointerdown=e=>{b.setPointerCapture(e.pointerId);world?.keys.add(b.dataset.step);};b.onpointerup=b.onpointercancel=()=>world?.keys.delete(b.dataset.step);}
  document.addEventListener('pointerdown',e=>{if(!e.target.closest('.popover,#layer-button,#events'))closePopover();});
  window.addEventListener('blur',()=>world?.keys.clear());
  window.addEventListener('keydown',e=>{
    if(e.key==='Escape')closePopover();
    if($('modal').open||['INPUT','SELECT','TEXTAREA'].includes(e.target.tagName)||e.metaKey||e.ctrlKey||e.altKey)return;
    const k=e.key.toLowerCase();
    if(k===' '&&e.target.tagName!=='BUTTON'){e.preventDefault();if(!e.repeat)togglePlay();return;}
    if(k==='r'){setWalk(false);world?.resetView();return;}
    if(world?.walking&&['w','a','s','d','arrowup','arrowleft','arrowright','arrowdown'].includes(k)){e.preventDefault();world.keys.add(k);}
    else if(k==='arrowleft'||k==='arrowright'){e.preventDefault();seek(state.t+(k==='arrowleft'?-1:1)*(e.shiftKey?1:1/run.frameHz));}
  });
  window.addEventListener('keyup',e=>world?.keys.delete(e.key.toLowerCase()));
  document.addEventListener('visibilitychange',()=>{lastNow=null;if(document.hidden&&!ar?.active){quietVideo();world?.keys.clear();}});
}
function leader(c,p,end,color,r=4){
  if(!p.visible)return;
  c.strokeStyle=color;c.lineWidth=1;c.beginPath();c.moveTo(p.x,p.y);c.lineTo(end.x+(p.x<end.x?-10:10),end.y);c.lineTo(end.x,end.y);c.stroke();
  c.beginPath();c.arc(p.x,p.y,r,0,Math.PI*2);c.fillStyle='#24312b';c.fill();c.stroke();c.fillStyle=color;c.fillRect(p.x-1,p.y-1,2,2);
}
function placeCards(){
  if(!world||state.mode==='camera'){$('instruments').hidden=true;$('probe-label').hidden=$('spec-label').hidden=true;$('leaders').getContext('2d').clearRect(0,0,$('leaders').width,$('leaders').height);return;}
  const {width:w,height:h}=world.size,narrow=w<680,compact=narrow||h<350;
  const layers=$('leaders'),ratio=Math.min(2,devicePixelRatio);if(layers.width!==Math.round(w*ratio)||layers.height!==Math.round(h*ratio)){layers.width=Math.round(w*ratio);layers.height=Math.round(h*ratio);}
  const c=layers.getContext('2d');c.setTransform(ratio,0,0,ratio,0,0);c.clearRect(0,0,w,h);$('instruments').hidden=!state.plots;
  cards=[];let previous;
  for(let i=0;i<2;i++){
    const a=world.project(world.anchor(i)),p=world.project(world.instrumentWorld(i)),isFrame=state.mode==='frame';
    const focal=h/(2*Math.tan(world.camera.fov*Math.PI/360));
    const pw=narrow?Math.min(203,Math.floor((w-35)/2)):clamp((isFrame?2.8:.69)*focal/Math.max(.1,p.depth),compact?148:188,compact?184:265);
    const ph=Math.round(pw*(compact?.625:.665));
    let x=p.x-pw/2,y=p.y-ph/2;
    if(narrow&&!world.walking){x=i===0?12:w-12-pw;y=h-51-ph;}
    else if(!world.walking&&p.visible){x=clamp(x,14,w-pw-14);y=clamp(y,Math.min(107,h*.26),h-ph-52);}
    const show=state.plots&&(narrow&&!world.walking||p.visible&&p.x>-pw*.65&&p.x<w+pw*.65&&p.y>-ph&&p.y<h+ph)&&(!world.walking||a.visible);
    if(show&&previous&&!narrow&&Math.abs(y+ph/2-previous.cy)<(ph+previous.h)/2+8&&Math.abs(x+pw/2-previous.cx)<(pw+previous.w)/2+12){
      const roomOnRight=previous.cx<w/2;
      x=clamp(previous.cx+(roomOnRight?previous.w/2+12:-previous.w/2-12-pw),12,w-pw-12);
    }
    if(i===0&&show)previous={cx:x+pw/2,cy:y+ph/2,w:pw,h:ph};
    const b=instruments[i];b.hidden=!show;b.style.width=pw+'px';b.style.height=ph+'px';b.style.transform='translate('+Math.round(x)+'px,'+Math.round(y)+'px)';
    if(show&&state.guides){
      const end=narrow?{x:clamp(a.x,x+8,x+pw-8),y}:{x:a.x>x+pw/2?x+pw:x,y:clamp(a.y,y+17,y+ph-17)};
      leader(c,a,end,i?'#d7b4d0':'#c1dcba');
    }
    cards.push([Math.round(pw),ph]);
  }
  const labels=state.mode==='specimen'&&state.guides;
  for(const [id,pos,dx,dy] of [['probe-label',world.rig.pin(),17,-24],['spec-label',world.rig.base,-57,14]]){
    const el=$(id),p=world.project(pos);const show=labels&&p.visible&&p.x>20&&p.x<w-35&&p.y>80&&p.y<h-40;
    el.hidden=!show;if(!show)continue;
    if(id==='probe-label')el.textContent='Actuator pin';
    const x=p.x+dx,y=p.y+dy;el.style.transform='translate('+Math.round(x)+'px,'+Math.round(y)+'px)';
    if(id==='probe-label'){c.strokeStyle='#c5e1b8';c.lineWidth=1.2;c.beginPath();c.arc(p.x,p.y,7,0,Math.PI*2);c.stroke();c.beginPath();c.moveTo(p.x+5,p.y-5);c.lineTo(x-3,y+8);c.stroke();}
  }
  if(state.mode==='frame'){
    const btn=$('interface-focus'),pin=world.project(world.rig.root.localToWorld(world.rig.pin()));
    btn.hidden=!pin.visible||pin.x<0||pin.x>w||pin.y<0||pin.y>h;
    if(!btn.hidden){
      btn.textContent=world.inspecting?'Full frame ↗':'Inspect SP3 ↗';
      const foot=world.rig.base.clone();foot.y=world.rig.floorY;
      const floorPoint=world.project(world.rig.root.localToWorld(foot));
      const x=clamp(pin.x-50,10,w-100),y=clamp(floorPoint.y+9,88,h-65-(narrow&&state.plots?126:0));
      btn.style.transform='translate('+Math.round(x)+'px,'+Math.round(y)+'px)';
      if(state.guides)leader(c,pin,{x:x+43,y:y+4},'#def6ad',3);
    }
    // Mark the most recent onset at its actual moving member end.
    let latest=-1,id=-1,phase=0;
    run.labels.forEach((_,i)=>{const s=hingePhase(run,i,state.t),at=s===2?run.firstPlastic[i]:run.firstYield[i];if(s&&at>latest){latest=at;id=i;phase=s;}});
    if(id>=0&&state.guides&&!world.inspecting){
      const p=world.project(world.views.frame.spots[id]),el=$('probe-label');
      if(p.visible&&p.x>10&&p.x<w-30&&p.y>75&&p.y<h-55){
        el.hidden=false;el.textContent=(phase===2?'Plastic':'Yielded')+' · '+run.labels[id];
        const x=clamp(p.x+14,8,w-130),y=p.y-26;el.style.transform='translate('+Math.round(x)+'px,'+Math.round(y)+'px)';
        leader(c,p,{x:x+3,y:y+9},phase===2?'#ff7057':'#ffca47',3);
      }
    }
  }
  const layout=cards.join('|')+state.mode;if(layout!==priorLayout)lastChartT=NaN;priorLayout=layout;
}
function renderHUD(){
  if(!run)return;
  $('time').value=state.t;$('time').setAttribute('aria-valuetext',state.t.toFixed(2)+' earthquake seconds');
  $('time-value').textContent=clock(state.t);drawWave($('wave'),run,state.t);
  if(state.mode==='frame'){
    const counts=[0,0,0];run.labels.forEach((_,i)=>counts[hingePhase(run,i,state.t)]++);
    $('view-key').innerHTML='<span class="legend-dot" style="background:#68737a"></span>'+counts[0]+' elastic <span class="legend-dot" style="background:#ffb000"></span>'+counts[1]+' yielded <span class="legend-dot" style="background:#fa493b"></span><b>'+counts[2]+' plastic</b>';
  }else if(state.mode==='path')$('view-key').textContent='Purple · measured trajectory     ●  '+clock(state.t)+' s';
  if(world&&state.mode!=='camera'&&state.plots&&cards.length&&lastChartT!==state.t){
    const plots=plotNames();instruments.forEach((b,i)=>{if(!b.hidden)drawPlot(b.querySelector('canvas'),run,state.t,plots[i],...cards[i]);});lastChartT=state.t;
  }
  if(plotDialog&&$('dialog-plot')){const c=$('dialog-plot');drawPlot(c,run,state.t,plotDialog,Math.max(250,c.clientWidth),Math.max(210,c.clientWidth*.59),true);$('detail-time').value=state.t;$('detail-stamp').textContent=clock(state.t)+' s · earthquake time';}
}
function loop(now,frame){
  const dt=lastNow===null?0:Math.max(0,(now-lastNow)/1000);lastNow=now;
  if(state.play){state.t=Math.min(run.duration,state.t+dt*state.rate);if(state.t>=run.duration)togglePlay(false);}
  if(ar?.active)ar.tick(frame,now);
  world?.updateLens(state.lens&&state.mode==='specimen',videoRaw,state.t);
  const changed=world?.update(state.t,state.scale,state.guides,Math.min(dt,.1));
  if((changed||drawNeeded||ar?.active)&&world&&state.mode!=='camera'){world.render();if(!ar?.active){placeCards();world.drawAxis($('axis'));}}
  if(drawNeeded||((state.play||changed)&&now-lastHUD>33)){renderHUD();syncVideo();lastHUD=now;}
  drawNeeded=false;if(!world)requestAnimationFrame(loop);
}
async function start(){
  run=await loadRun();const query=new URLSearchParams(location.search);
  state.t=query.get('event')==='first-plastic'?run.firstHinge:run.peakTime;
  await document.fonts.ready;
  try{world=makeScene($('viewport'),run);ar=createAR(world,run,state,{toggle:()=>togglePlay()},()=>setMode('specimen'),touch);}
  catch(e){console.error('3D scene initialization failed',e);}
  if(navigator.xr)navigator.xr.isSessionSupported('immersive-ar').then(v=>arSupported=v).catch(()=>{});
  wire();buildEvents();$('time').max=run.duration;$('loading').hidden=true;setMode(Object.hasOwn(viewText,query.get('view'))?query.get('view'):'specimen');
  new ResizeObserver(()=>{if(!ar?.active){world?.resize();world?.resetView();priorLayout='';lastChartT=NaN;touch();}}).observe($('stage'));
  if(world)world.renderer.setAnimationLoop(loop);else requestAnimationFrame(loop);
}
start().catch(e=>{$('loading').textContent='The experiment data could not be opened. Reload to try again.';console.error(e);});
