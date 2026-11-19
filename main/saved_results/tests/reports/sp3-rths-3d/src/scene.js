import * as T from 'three';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {RoomEnvironment} from 'three/addons/environments/RoomEnvironment.js';
import {EffectComposer} from 'three/addons/postprocessing/EffectComposer.js';
import {RenderPass} from 'three/addons/postprocessing/RenderPass.js';
import {GTAOPass} from 'three/addons/postprocessing/GTAOPass.js';
import {OutputPass} from 'three/addons/postprocessing/OutputPass.js';
import {ShaderPass} from 'three/addons/postprocessing/ShaderPass.js';
import {VignetteShader} from 'three/addons/shaders/VignetteShader.js';
import {createPlaces,manager} from './env.js';
import {createRig} from './rig.js';
import {createFrame, createPath} from './spaces.js';
import {createLocations,siteFloorAt} from './locations.js';
import {clamp,hingePhase} from './data.js';

const vec=(x,y,z)=>new T.Vector3(x,y,z);
export function makeScene(container,run){
  const renderer=new T.WebGLRenderer({antialias:true,alpha:true,powerPreference:'high-performance'});
  renderer.setPixelRatio(Math.min(window.devicePixelRatio||1,1.8));
  renderer.setClearColor(0x182021,0);renderer.outputColorSpace=T.SRGBColorSpace;renderer.toneMapping=T.NeutralToneMapping;
  renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFShadowMap;container.append(renderer.domElement);
  const coarse=matchMedia('(pointer: coarse)').matches;
  const scene=new T.Scene(),camera=new T.PerspectiveCamera(33,1,.035,48);
  scene.background=new T.Color(0x202829);scene.fog=new T.FogExp2(0x202829,.135);
  const env=new RoomEnvironment(),generator=new T.PMREMGenerator(renderer);
  const roomLight=generator.fromScene(env,.035).texture;scene.environment=roomLight;scene.environmentIntensity=.7;env.dispose();generator.dispose();
  const hemisphere=new T.HemisphereLight(0xd8e6ea,0x777463,.80);scene.add(hemisphere);
  const key=new T.DirectionalLight(0xfff1dc,2.85);key.castShadow=true;key.shadow.mapSize.setScalar(coarse?2048:4096);key.shadow.radius=coarse?2:3;key.shadow.normalBias=.003;key.shadow.bias=-.00035;key.shadow.intensity=.60;scene.add(key,key.target);
  const rim=new T.DirectionalLight(0xccedfa,2.15);rim.position.set(-2.1,3.1,-2.3);scene.add(rim);
  const fill=new T.DirectionalLight(0xe0edd6,.8);fill.position.set(1.4,.9,2.9);scene.add(fill);
  const display=new T.Group(),lab=new T.Group();scene.add(display,lab);
  const locations=createLocations();
  lab.add(...Object.values(locations));
  let place=null,skyClock=0,skyDrawn=0;
  const places=createPlaces(renderer),sky=places.frame.sky;lab.add(sky);
  manager.onProgress=()=>dirty=true;
  const composer=new EffectComposer(renderer,new T.WebGLRenderTarget(1,1,{type:T.HalfFloatType,samples:coarse?0:4}));
  const ao=new GTAOPass(scene,camera),aoSize=ao.setSize.bind(ao),gbuffer=ao._overrideVisibility.bind(ao);
  ao.setSize=(w,h)=>aoSize(Math.ceil(w/2),Math.ceil(h/2));
  // Labels, guides and fading overlays do not occlude.
  ao._overrideVisibility=()=>{gbuffer();scene.traverse(o=>{if(o.visible&&(o.isSprite||o.userData.noAO||o.material?.transparent&&!o.userData.ao)){o.visible=false;ao._visibilityCache.push(o);}});};
  const vignette=new ShaderPass(VignetteShader);vignette.uniforms.offset.value=.92;vignette.uniforms.darkness.value=.8;
  composer.addPass(new RenderPass(scene,camera));composer.addPass(ao);composer.addPass(new OutputPass());composer.addPass(vignette);
  const floor=new T.Mesh(new T.PlaneGeometry(170,170),new T.MeshStandardMaterial({color:0x202b2d,roughness:.92,metalness:.23}));
  floor.rotation.x=-Math.PI/2;floor.receiveShadow=true;lab.add(floor);
  const grid=new T.Mesh(new T.PlaneGeometry(155,155),new T.ShaderMaterial({
    transparent:true,depthWrite:false,uniforms:{stepSize:{value:.16},falloff:{value:4.3}},
    vertexShader:'varying vec3 world;void main(){vec4 p=modelMatrix*vec4(position,1.);world=p.xyz;gl_Position=projectionMatrix*viewMatrix*p;}',
    fragmentShader:'varying vec3 world;uniform float stepSize;uniform float falloff;float lines(vec2 p){vec2 d=abs(fract(p-.5)-.5)/max(fwidth(p),vec2(.0001));return 1.-clamp(min(d.x,d.y),0.,1.);}void main(){vec2 g=world.xz/stepSize;float a=lines(g)*.13+lines(g/5.)*.18;float fade=exp(-length(world.xz)/falloff);gl_FragColor=vec4(.53,.65,.61,a*fade);}'
  }));grid.rotation.x=-Math.PI/2;lab.add(grid);
  const rig=createRig(),frame=createFrame(run),path=createPath(run),views={specimen:rig,frame,path};
  for(const v of Object.values(views))display.add(v.root);
  const lensCanvas=document.createElement('canvas');lensCanvas.width=320;lensCanvas.height=552;
  const lensContext=lensCanvas.getContext('2d'),lensMap=new T.CanvasTexture(lensCanvas);
  lensMap.colorSpace=T.SRGBColorSpace;lensMap.minFilter=T.LinearFilter;
  const lens=new T.Mesh(new T.PlaneGeometry(.36,.621),new T.MeshBasicMaterial({map:lensMap,side:T.DoubleSide,toneMapped:false}));
  rig.root.add(lens);lens.position.set(.55,.48,.06);lens.visible=false;
  let lensKey='';
  function updateLens(on,video,t){
    if(lens.visible!==on){lens.visible=on;dirty=true;}if(!on)return;
    const viewer=renderer.xr.isPresenting?renderer.xr.getCamera():camera;
    lens.lookAt(viewer.getWorldPosition(new T.Vector3()));
    const covered=t>=run.cameraStart&&t<run.cameraEnd;
    const key=covered?[video.readyState,video.seeking,Math.floor(video.currentTime*30)].join('-'):'gap';
    if(key===lensKey)return;lensKey=key;
    const c=lensContext;c.fillStyle='#1a2422';c.fillRect(0,0,320,552);c.strokeStyle='#93a89c';c.lineWidth=3;c.strokeRect(1.5,1.5,317,549);
    c.fillStyle='#c9f794';c.fillRect(16,17,7,7);c.textAlign='left';c.font='20px "Plex Mono", monospace';c.fillText('LAB CAMERA',34,29);
    if(covered&&video.readyState>=2)c.drawImage(video,17,43,286,503);
    else{c.textAlign='center';c.font='22px "DM Sans", sans-serif';c.fillStyle='#e2e9df';c.fillText(covered?'Opening recording…':'Outside camera coverage',160,263);c.font='18px "Plex Mono", monospace';c.fillText('4.96 – 25.59 s',160,302);}
    lensMap.needsUpdate=true;dirty=true;
  }
  const controls=new OrbitControls(camera,renderer.domElement);controls.enableDamping=true;controls.dampingFactor=.14;controls.rotateSpeed=.72;controls.zoomSpeed=.90;controls.target.set(.43,.52,0);controls.maxPolarAngle=Math.PI*.495;controls.minPolarAngle=.055;controls.zoomToCursor=true;
  let mode='specimen',walking=false,dirty=true,width=1,height=1,previousT=-1,previousScale=0,previousGuides=true,detail=false;
  let yaw=0,pitch=0,pointer=null,lastX=0,lastY=0;
  const keys=new Set(),direction=vec(0,0,0),side=vec(0,0,0),up=vec(0,1,0);
  controls.addEventListener('change',()=>dirty=true);
  const camConfig={
    specimen:{focus:[.67,.45,0],dir:[-1.28,.62,3.48],span:3.02,w:3.42},
    base:{focus:[0,-.03,0],dir:[-.67,.82,1.58],span:.93,w:1.27},
    reaction:{focus:[1.39,.72,0],dir:[-1.8,1.22,2.06],span:1.70,w:1.58},
    frame:{focus:[3.53,2.64,0],dir:[-4.20,1.55,13.1],span:8.63,w:12.64},
    interface:{focus:[-.66,.66,0],dir:[-1.8,1.12,3.3],span:2.94,w:3.37},
    path:{focus:[-.012,.53,0],dir:[1.82,.98,2.63],span:2.23,w:2.5}
  };
  function resetView(inspect=false){
    if(!views[mode])return;
    detail=inspect===true&&mode==='frame';
    const preset=mode==='specimen'&&['base','reaction'].includes(inspect)?inspect:mode;
    const opt=camConfig[detail?'interface':preset],narrow=width<680,aspect=width/height;
    const span=Math.max(opt.span,opt.w/(aspect*(narrow?.92:.82)));
    const distance=span/(2*Math.tan(T.MathUtils.degToRad(camera.fov)/2));
    const focus=vec(...opt.focus);
    if(narrow)focus.y-=(mode==='frame'&&!detail?1.08:.22);
    controls.target.copy(focus);camera.position.copy(vec(...opt.dir).normalize().multiplyScalar(distance).add(focus));
    controls.minDistance=mode==='frame'?.5:.18;controls.maxDistance=mode==='frame'?60:12;
    camera.up.set(0,1,0);camera.lookAt(focus);camera.updateMatrixWorld();controls.update();syncLook();dirty=true;
  }
  function syncLook(){camera.getWorldDirection(direction);pitch=Math.asin(clamp(direction.y,-1,1));yaw=Math.atan2(-direction.x,-direction.z);}
  const eyeLevel=1.62;
  function walkHeight(x,z){return eyeLevel+(mode==='frame'?siteFloorAt(x,z):rig.floorY);}
  function setWalk(on){
    if(on===walking)return;walking=on;controls.enabled=!on;keys.clear();pointer=null;
    if(on&&(mode==='frame'||mode==='specimen')){
      direction.subVectors(camera.position,controls.target);direction.y=0;
      const distance=clamp(direction.length(),mode==='frame'?2.1:1.3,mode==='frame'?10.2:4.2);
      if(direction.lengthSq()<1e-6)direction.set(0,0,1);
      camera.position.copy(controls.target).addScaledVector(direction.normalize(),distance);
      camera.position.y=walkHeight(camera.position.x,camera.position.z);camera.lookAt(controls.target);
    }
    syncLook();
    if(!on){camera.getWorldDirection(direction);const d=clamp(camera.position.distanceTo(controls.target),mode==='frame'?1:.35,mode==='frame'?12:3);controls.target.copy(camera.position).addScaledVector(direction,d);controls.update();}
    dirty=true;
  }
  const dom=renderer.domElement;
  dom.addEventListener('pointerdown',e=>{if(!walking||pointer!==null)return;pointer=e.pointerId;lastX=e.clientX;lastY=e.clientY;dom.setPointerCapture(pointer);});
  dom.addEventListener('pointermove',e=>{if(!walking||pointer!==e.pointerId)return;yaw-=(e.clientX-lastX)*.004;pitch=clamp(pitch-(e.clientY-lastY)*.004,-1.48,1.48);camera.rotation.set(pitch,yaw,0,'YXZ');lastX=e.clientX;lastY=e.clientY;dirty=true;});
  for(const event of ['pointerup','pointercancel','lostpointercapture'])dom.addEventListener(event,e=>{if(pointer===e.pointerId)pointer=null;});
  function move(dt){
    if(!walking||!keys.size)return;
    const z=Number(keys.has('w')||keys.has('arrowup'))-Number(keys.has('s')||keys.has('arrowdown'));
    const x=Number(keys.has('d')||keys.has('arrowright'))-Number(keys.has('a')||keys.has('arrowleft'));
    camera.getWorldDirection(direction);direction.y=0;direction.normalize();side.crossVectors(direction,up).normalize();
    const step=(mode==='frame'?3:.85)*dt/(Math.hypot(x,z)||1);
    const nx=camera.position.x+(direction.x*z+side.x*x)*step,nz=camera.position.z+(direction.z*z+side.z*x)*step;
    function clear(a,b){
      if(mode==='path')return true;
      const local=mode==='frame'?-a:a;
      if(local>-.74&&local<2.34&&Math.abs(b)<.83)return false;
      if(mode==='frame'&&Math.abs(b)<.43)for(let c=1;c<=run.bays;c++)if(Math.abs(a-c*run.bayWidth)<.47)return false;
      return true;
    }
    if(clear(nx,camera.position.z))camera.position.x=nx;
    if(clear(camera.position.x,nz))camera.position.z=nz;
    if(mode!=='path')camera.position.y=walkHeight(camera.position.x,camera.position.z);
    dirty=true;
  }
  function setMode(name){
    mode=name;setWalk(false);keys.clear();
    for(const [k,v] of Object.entries(views))v.root.visible=k===mode;
    const inFrame=mode==='frame';rig.root.visible=mode==='specimen'||inFrame;rig.setCoupled(inFrame);
    for(const [key,group] of Object.entries(locations))group.visible=key===mode;
    if(!views[mode])return;
    const large=inFrame,diagram=mode==='path',ground=diagram?-.11:rig.floorY;
    place=places[mode]??null;sky.visible=large;
    floor.visible=grid.visible=diagram;
    floor.position.y=ground;grid.position.y=ground+.001;grid.material.uniforms.stepSize.value=large?.6:.16;grid.material.uniforms.falloff.value=large?21:4.4;
    const center=large?vec(4.0,2.6,0):vec(.70,.43,-.30),extent=large?9:3.9;
    key.target.position.copy(center);key.position.copy(center).addScaledVector(place?place.sun:vec(-2.1,3.7,2.35).normalize(),large?24:9);
    Object.assign(key.shadow.camera,{left:-extent,right:extent,top:extent,bottom:-extent,near:.05,far:large?48:20});key.shadow.camera.updateProjectionMatrix();
    key.shadow.normalBias=large?.02:.006;key.shadow.bias=large?-.0002:-.0001;key.shadow.intensity=diagram?.60:1;
    key.intensity=large?4.6:diagram?2.85:3.3;rim.intensity=diagram?2.15:0;fill.intensity=diagram?.8:0;hemisphere.intensity=diagram?1.08:0;
    ao.enabled=!diagram;ao.updateGtaoMaterial({radius:large?.8:.28,distanceExponent:2,thickness:large?1.5:.5,scale:1.25,samples:16});ao.blendIntensity=large?.85:.95;
    setLight();
    camera.far=large?1600:60;camera.updateProjectionMatrix();
    previousT=-1;resetView();
  }
  function setLight(){
    const diagram=!place,site=mode==='frame';
    renderer.toneMapping=T.ACESFilmicToneMapping;renderer.toneMappingExposure=diagram?1.15:site?.92:1.12;
    scene.environment=place?.environment??roomLight;scene.environmentIntensity=diagram?.7:site?.6:.62;
    // Distant haze matches the sky at the horizon.
    scene.fog=diagram?new T.FogExp2(0x202829,.135):site?new T.Fog(new T.Color(.74,.9,1.08),90,1500):null;
    scene.background=new T.Color(diagram?0x202829:0x9a9b98);dirty=true;
  }
  function render(){if(renderer.xr.isPresenting||!place)renderer.render(scene,camera);else composer.render();}
  function resize(){
    width=Math.max(1,container.clientWidth);height=Math.max(1,container.clientHeight);camera.aspect=width/height;camera.updateProjectionMatrix();
    if(!renderer.xr.isPresenting){renderer.setSize(width,height,false);composer.setPixelRatio(renderer.getPixelRatio());composer.setSize(width,height);}dirty=true;
  }
  const roomMin=vec(-12.4,rig.floorY+.09,-9.3),roomMax=vec(16.4,7.6,9.3);
  const focusMin=roomMin.clone().addScalar(.24),focusMax=roomMax.clone().addScalar(-.24);
  function constrainCamera(){
    if(mode==='specimen'){
      if(walking)camera.position.clamp(roomMin,roomMax);
      else{
        direction.subVectors(camera.position,controls.target);controls.target.clamp(focusMin,focusMax);
        camera.position.copy(controls.target).add(direction);
        let fraction=1;
        for(const k of ['x','y','z']){
          if(direction[k]>0)fraction=Math.min(fraction,(roomMax[k]-controls.target[k])/direction[k]);
          if(direction[k]<0)fraction=Math.min(fraction,(roomMin[k]-controls.target[k])/direction[k]);
        }
        if(fraction<1){camera.position.copy(controls.target).addScaledVector(direction,fraction);camera.lookAt(controls.target);}
      }
    }else if(mode==='frame'){camera.position.x=clamp(camera.position.x,-58,67);camera.position.z=clamp(camera.position.z,-62,62);camera.position.y=Math.max(camera.position.y,rig.floorY+.08);}
    const near=walking?.032:clamp(camera.position.distanceTo(controls.target)*.009,.018,.24);
    if(Math.abs(camera.near-near)>.001){camera.near=near;camera.updateProjectionMatrix();}
  }
  function update(t,scale,guides,dt){
    if(!views[mode])return false;
    if(!renderer.xr.isPresenting){move(dt);if(!walking)controls.update();constrainCamera();}
    // Clouds drift continuously; redraw them at up to 30 fps while the site is open.
    if(mode==='frame'){skyClock+=dt;if(skyClock-skyDrawn>1/30){sky.material.uniforms.time.value=skyClock;skyDrawn=skyClock;dirty=true;}}
    if(t!==previousT||scale!==previousScale){
      if(mode==='specimen'||mode==='frame')rig.update(run.sample(t,0),run.sample(t,2),scale);
      if(mode==='frame')frame.update(t,scale);else if(mode==='path')path.update(t);dirty=true;
      previousT=t;previousScale=scale;
    }
    if(previousGuides!==guides)dirty=true;views[mode].guides.visible=guides;rig.guides.visible=mode==='specimen'&&guides;previousGuides=guides;
    camera.updateMatrixWorld();
    const changed=dirty;dirty=false;return changed;
  }
  function project(p){
    const view=p.clone().applyMatrix4(camera.matrixWorldInverse),q=p.clone().project(camera);
    return {x:(q.x+1)*width/2,y:(1-q.y)*height/2,depth:-view.z,visible:q.z>-1&&q.z<1};
  }
  function instrumentWorld(i){
    if(mode==='specimen')return i===0?vec(-1.07,.79,.13):vec(2.72,.80,.10);
    if(mode==='frame')return i===0?vec(-2.15,3.65,.35):vec(11.4,3.4,.35);
    return i===0?vec(-1.55,.80,.15):vec(1.56,.70,-.12);
  }
  const ray=new T.Raycaster();ray.params.Line.threshold=.022;
  function pick(clientX,clientY){
    const obj=views[mode]?.pickable;
    if(!obj||walking)return;
    const b=container.getBoundingClientRect();
    ray.setFromCamera(new T.Vector2(2*(clientX-b.left)/b.width-1,1-2*(clientY-b.top)/b.height),camera);
    const hits=ray.intersectObject(obj,false),hit=hits[0];
    if(mode==='frame'){
      // Beam and column end surfaces meet at the same joint. Prefer visible paint at the contact.
      for(const h of hits){
        if(h.distance>hit.distance+.20)break;
        const hinge=frame.hingeForFace(h.faceIndex);
        if(hinge!==undefined&&hingePhase(run,hinge,previousT))return {hinge};
      }
      let nearest=matchMedia('(pointer: coarse)').matches?13:5,painted;
      for(let id=0;id<frame.spots.length;id++){
        if(!hingePhase(run,id,previousT))continue;
        const p=project(frame.spots[id]),d=Math.hypot(p.x-(clientX-b.left),p.y-(clientY-b.top));
        if(p.visible&&d<nearest){nearest=d;painted=id;}
      }
      const hinge=painted??(hit&&frame.hingeForFace(hit.faceIndex));
      if(hinge!==undefined)return {hinge};
    }else if(hit)return {time:hit.index/run.hz};
  }
  function drawAxis(canvas){
    const c=canvas.getContext('2d'),w=canvas.width,h=canvas.height,cx=w*.48,cy=h*.55,quat=camera.quaternion.clone().invert();
    c.clearRect(0,0,w,h);c.lineWidth=2.5;c.font='17px "Plex Mono",monospace';c.textAlign='center';c.textBaseline='middle';
    const axes=[['X',vec(1,0,0),'#cc9d86'],['Y',vec(0,1,0),'#c3dcaa'],['Z',vec(0,0,1),'#97bfd5']].map(([name,p,color])=>[name,p.applyQuaternion(quat),color]).sort((a,b)=>a[1].z-b[1].z);
    for(const [n,v,color] of axes){c.strokeStyle=color;c.fillStyle=color;c.beginPath();c.moveTo(cx,cy);c.lineTo(cx+v.x*39,cy-v.y*39);c.stroke();c.fillText(n,cx+v.x*53,cy-v.y*53);}
    c.beginPath();c.arc(cx,cy,3,0,Math.PI*2);c.fillStyle='#e1e8df';c.fill();
  }
  resize();setMode('specimen');
  return {renderer,scene,camera,controls,display,lab,rig,views,keys,render,resize,resetView,setMode,setWalk,update,updateLens,drawAxis,project,instrumentWorld,pick,
    anchor:i=>views[mode].anchor(i),invalidate:()=>dirty=true,get size(){return {width,height};},get walking(){return walking;},get inspecting(){return detail;}};
}
