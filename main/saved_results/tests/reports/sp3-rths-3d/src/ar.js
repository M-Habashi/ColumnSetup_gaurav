import * as T from 'three';
import {drawPlot} from './charts.js';

// The same physical rig and the same telemetry drive the desktop and immersive scenes.
export function createAR(world,run,state,buttons,onMode,onExit){
  const {renderer,scene,display,lab,rig}=world;
  const ui=document.getElementById('xr-ui'),hint=document.getElementById('xr-hint');
  const reticle=new T.Mesh(new T.RingGeometry(.075,.081,56).rotateX(-Math.PI/2),
    new T.MeshBasicMaterial({color:0xc9f794,side:T.DoubleSide,toneMapped:false}));
  reticle.matrixAutoUpdate=false;reticle.visible=false;scene.add(reticle);
  const panels=new T.Group();display.add(panels);panels.visible=false;
  const textures=[],screens=[],lines=[];
  for(let i=0;i<2;i++){
    const c=document.createElement('canvas'),texture=new T.CanvasTexture(c);texture.colorSpace=T.SRGBColorSpace;texture.minFilter=T.LinearFilter;
    const panel=new T.Mesh(new T.PlaneGeometry(.49,.32),new T.MeshBasicMaterial({map:texture,side:T.DoubleSide,toneMapped:false}));
    panel.position.set(i===0?-.46:.94,i===0?.86:1.33,.14);panels.add(panel);
    const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(new Float32Array(6),3));
    const line=new T.Line(g,new T.LineBasicMaterial({color:0xc8e9bd}));line.frustumCulled=false;panels.add(line);lines.push(line);textures.push(texture);screens.push(panel);
  }
  let session=null,source=null,placed=false,scale=1,last=-Infinity;
  const pose=new T.Matrix4(),point=new T.Vector3(),eye=new T.Vector3();
  function place(){
    if(!reticle.visible)return;
    point.setFromMatrixPosition(pose);eye.setFromMatrixPosition(renderer.xr.getCamera().matrixWorld);
    display.rotation.set(0,Math.atan2(eye.x-point.x,eye.z-point.z),0);
    display.position.copy(point);display.position.y-=rig.floorY*scale;display.scale.setScalar(scale);
    display.visible=true;placed=true;reticle.visible=false;last=-Infinity;
    hint.textContent='Walk around the specimen to inspect its response.';
  }
  const onSelect=()=>{if(!placed)place();else if(!session.domOverlayState)buttons.toggle();};
  const controller=renderer.xr.getController(0);scene.add(controller);controller.addEventListener('select',onSelect);
  const controller2=renderer.xr.getController(1);scene.add(controller2);controller2.addEventListener('select',onSelect);
  ui.addEventListener('beforexrselect',e=>e.preventDefault());
  document.getElementById('xr-exit').onclick=()=>session?.end();
  document.getElementById('xr-play').onclick=buttons.toggle;
  document.getElementById('xr-scale').onclick=()=>{
    scale=scale===1?.35:1;document.getElementById('xr-scale').textContent=scale===1?'Scale 1:1':'Tabletop 35%';
    if(placed){display.scale.setScalar(scale);display.position.y=point.y-rig.floorY*scale;}
  };
  document.getElementById('xr-place').onclick=()=>{placed=false;display.visible=false;hint.textContent='Aim at a horizontal surface. Tap to place the specimen.';};
  function restore(){
    source?.cancel();source=null;session=null;reticle.visible=false;panels.visible=false;placed=false;
    display.visible=true;display.position.set(0,0,0);display.rotation.set(0,0,0);display.scale.setScalar(1);
    lab.visible=true;ui.hidden=true;renderer.xr.enabled=false;world.setMode('specimen');onExit();world.resize();world.resetView();world.invalidate();
  }
  async function enter(){
    const s=await navigator.xr.requestSession('immersive-ar',{requiredFeatures:['hit-test'],optionalFeatures:['dom-overlay','local-floor'],domOverlay:{root:ui}});
    session=s;s.addEventListener('end',restore,{once:true});
    try{
      onMode();renderer.xr.enabled=true;renderer.xr.setReferenceSpaceType('local');
      await renderer.xr.setSession(s);const space=await s.requestReferenceSpace('viewer');
      source=await s.requestHitTestSource({space,entityTypes:['plane']});
      lab.visible=false;scene.background=null;scene.fog=null;ui.hidden=false;display.visible=false;panels.visible=true;scale=1;placed=false;
      document.getElementById('xr-scale').textContent='Scale 1:1';hint.textContent='Aim at a horizontal surface. Tap the ring to place the specimen.';
    }catch(err){await s.end();throw err;}
  }
  function tick(frame,now){
    if(!session||!frame||!source)return;
    if(!placed){
      const hit=frame.getHitTestResults(source)[0],result=hit?.getPose(renderer.xr.getReferenceSpace());
      reticle.visible=!!result&&result.transform.matrix[5]>.86;if(reticle.visible){pose.fromArray(result.transform.matrix);reticle.matrix.copy(pose);}return;
    }
    panels.visible=state.plots;
    const xrCamera=renderer.xr.getCamera();xrCamera.getWorldPosition(eye);
    for(let i=0;i<2;i++){
      screens[i].lookAt(eye);const a=rig.anchor(i),p=screens[i].position;
      const data=lines[i].geometry.attributes.position;data.setXYZ(0,a.x,a.y,a.z);data.setXYZ(1,p.x,p.y,p.z);data.needsUpdate=true;
      if(now-last>55){drawPlot(textures[i].image,run,state.t,i?'hysteresis':'displacement',256,167);textures[i].needsUpdate=true;}
    }
    if(now-last>55)last=now;
  }
  return {enter,tick,get active(){return !!session;}};
}
