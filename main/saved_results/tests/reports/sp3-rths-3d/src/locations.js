import * as T from 'three';
import {V,metal,box,post,batch,STRONG_FLOOR_Y} from './rig.js';
import {surface,boxUV,groundDisc,heap} from './env.js';

const floorY=STRONG_FLOOR_Y;
const slab=surface('concrete',{color:0xd5dde6});

function strut(g,a,b,w,d,mat){
  const start=V(...a),end=V(...b),dir=end.clone().sub(start);
  const o=box(g,0,0,0,w,dir.length(),d,mat);
  o.position.copy(start).lerp(end,.5);o.quaternion.setFromUnitVectors(V(0,1,0),dir.normalize());
  return o;
}
function horizontalI(g,x,y,z,length,depth,width,mat){
  box(g,x,y,z,length,depth-.05,.014,mat);
  for(const s of [-1,1])box(g,x,y+s*(depth-.025)/2,z,length,.025,width,mat);
}
// Rafter in a plane x = const: flanges either side of a web.
function rafter(g,x,a,b,depth,mat){
  const n=V(0,b[0]-a[0],b[1]-a[1]).normalize().applyAxisAngle(V(1,0,0),Math.PI/2);
  for(const s of [-1,1])strut(g,V(x,...a).addScaledVector(n,s*depth/2).toArray(),V(x,...b).addScaledVector(n,s*depth/2).toArray(),.2,.024,mat);
  strut(g,[x,...a],[x,...b],.014,depth-.05,mat);
}
function column(g,x,z,y0,y1,mat){
  box(g,x,(y0+y1)/2,z,.016,y1-y0,.4,mat);
  for(const s of [-1,1])box(g,x,(y0+y1)/2,z+s*.212,.3,y1-y0,.025,mat);
}

// An empty high-bay structures laboratory: precast panels, clerestory glazing, a portal
// frame with crane runway, a parked bridge crane, roof skylights and high-bay lighting.
function laboratory(){
  const room=new T.Group(),g=new T.Group(),y=floorY,x0=-13,x1=17,D=10,eave=y+8.4,ridge=y+9.6,L=x1-x0,cx=(x0+x1)/2;
  const panel=surface('concrete',{color:0xe2e8ee}),clad=surface('clad',{color:0xf4f6f7,metalness:.25});
  const steel=surface('paint',{color:0x58636b,metalness:.25,normal:.6}),yellow=surface('paint',{color:0xe0a516,normal:.6});
  const dark=metal(0x2b2f31,.3,.6),glass=new T.MeshStandardMaterial({color:0xe9f0f6,emissive:0xeef4ff,emissiveIntensity:2.2,roughness:.1});
  const lamp=new T.MeshStandardMaterial({color:0xffffff,emissive:0xfff3df,emissiveIntensity:9});
  const floor=new T.Mesh(boxUV(new T.PlaneGeometry(L,2*D).rotateX(-Math.PI/2)),surface('floor',{color:0xf0eee9,normal:.8}));
  floor.position.set(cx,y,0);floor.receiveShadow=true;room.add(floor);
  for(const s of [-1,1]){
    const z=s*(D+.12);
    box(g,cx,y+1.6,z,L,3.2,.24,panel);box(g,cx,y+3.9,z,L,1.4,.2,clad);
    box(g,cx,y+5.4,z+s*.06,L,1.6,.06,glass);box(g,cx,(y+6.2+eave)/2,z,L,eave-y-6.2,.2,clad);
    for(let x=x0+1.5;x<x1;x+=1.5)box(g,x,y+5.4,z-s*.03,.07,1.6,.1,steel);
    for(let x=x0+3;x<x1;x+=3)box(g,x,y+1.6,z-s*.122,.025,3.2,.01,dark);
  }
  const gable=new T.Shape([new T.Vector2(-D-.25,0),new T.Vector2(D+.25,0),new T.Vector2(0,ridge-eave)]);
  for(const x of [x0-.12,x1+.12]){
    const s=Math.sign(x-cx),door=s>0;
    for(const [z0,z1] of door?[[-D,-3],[3,D]]:[[-D,D]])box(g,x,y+1.6,(z0+z1)/2,.24,3.2,z1-z0,panel);
    if(door){
      box(g,x,(y+5.6+eave)/2,0,.2,eave-y-5.6,6,clad);
      for(const z of [-D/2-1.5,D/2+1.5])box(g,x,(y+3.2+eave)/2,z,.2,eave-y-3.2,D-3,clad);
      for(let k=0;k<9;k++)box(g,x-s*.04,y+.31+k*.62,0,.08,.6,5.9,clad);
      for(const z of [-3.05,3.05])box(g,x-s*.1,y+2.8,z,.18,5.6,.12,steel);box(g,x-s*.1,y+5.65,0,.18,.12,6.2,steel);
    }else box(g,x,(y+3.2+eave)/2,0,.2,eave-y-3.2,2*D+.5,clad);
    const face=new T.Mesh(new T.ExtrudeGeometry(gable,{depth:.2,bevelEnabled:false}),clad);
    face.position.set(x-.1,eave,0);face.rotation.y=Math.PI/2;g.add(face);
  }
  const pitch=Math.atan2(ridge-eave,D),run=D/Math.cos(pitch);
  for(const s of [-1,1]){
    box(g,cx,(eave+ridge)/2+.14,s*D/2,L+.5,.1,run+.3,clad).rotation.x=s*pitch;
    for(let x=x0+3;x<x1;x+=6)box(g,x,(eave+ridge)/2+.07,s*D*.45,3.6,.04,1.6,glass).rotation.x=s*pitch;
    for(const k of [.12,.36,.6,.84])horizontalI(g,cx,ridge-(ridge-eave)*k-.15,s*D*k,L,.2,.09,steel);
  }
  // Portal frames at 6 m centres carry the crane runway and the roof.
  for(let x=x0;x<=x1;x+=6){
    for(const s of [-1,1]){
      column(g,x,s*(D-.3),y,eave,steel);box(g,x,y+6.05,s*(D-.72),.3,.5,.44,steel);
      rafter(g,x,[eave,s*(D-.3)],[ridge,0],.55,steel);
    }
  }
  for(const s of [-1,1]){horizontalI(g,cx,y+6.62,s*(D-.75),L,.6,.3,steel);box(g,cx,y+6.95,s*(D-.75),L,.06,.06,dark);}
  const bx=x0+3.2;
  box(g,bx,y+7.45,0,.55,.85,2*D-1.5,yellow,.02);
  for(const s of [-1,1])box(g,bx,y+7.15,s*(D-.75),1.9,.4,.5,yellow,.02);
  box(g,bx,y+6.85,1.6,.8,.5,.9,dark,.02);
  for(const dz of [-.1,.1])post(g,bx,y+4.3,y+6.6,1.6+dz,.008,dark,6);
  box(g,bx,y+4.15,1.6,.22,.34,.12,yellow,.02);
  for(let x=x0+3;x<x1;x+=6)for(const z of [-5,0,5]){
    const top=ridge-(ridge-eave)*Math.abs(z)/D-.1;
    post(g,x,y+7.4,top,z,.012,dark,6);post(g,x,y+7.1,y+7.4,z,.24,dark,28);post(g,x,y+7.08,y+7.1,z,.21,lamp,28);
  }
  batch(g);g.traverse(o=>{if(o.isMesh)o.castShadow=false;});room.add(g);
  // Tie-down anchors of the strong floor on a 3 ft grid.
  const pitchA=.9144,cap=metal(0x7d827c,.8,.42),hole=metal(0x0c0e0d,0,1),count=17*13;
  const rings=new T.InstancedMesh(new T.RingGeometry(.03,.052,24).rotateX(-Math.PI/2),cap,count);
  const holes=new T.InstancedMesh(new T.CircleGeometry(.03,20).rotateX(-Math.PI/2),hole,count);
  const at=new T.Object3D();let n=0;
  for(let i=-6;i<=10;i++)for(let j=-6;j<=6;j++){
    at.position.set(.3+i*pitchA,y+.0015,.25+j*pitchA);at.updateMatrix();rings.setMatrixAt(n,at.matrix);holes.setMatrixAt(n++,at.matrix);
  }
  for(const o of [rings,holes]){o.receiveShadow=true;room.add(o);}
  return room;
}

export function siteFloorAt(x,z){
  return Math.abs(x-3.6)<13.35/2&&Math.abs(z)<3.55/2?floorY:floorY-.18;
}
// Open meadow with a compacted construction pad, the foundation slab and a distant forest edge.
function landscape(){
  const g=new T.Group(),grade=floorY-.18;
  const field=new T.Mesh(boxUV(new T.CircleGeometry(1500,64).rotateX(-Math.PI/2)),surface('soil',{color:0xdde3ee}));
  field.position.y=grade-.006;field.receiveShadow=true;g.add(field);
  // Compacted crushed-stone working platform around the test slab, crossed by a haul road.
  const pad=groundDisc(surface('gravel',{color:0xbab6b0}),24,.4);pad.position.set(3.6,grade,0);g.add(pad);
  const road=groundDisc(surface('gravel',{color:0x9e9a94}),3.6,.25,16);road.position.set(3.6,grade-.002,0);road.rotation.y=2.18;g.add(road);
  boxUV(box(g,3.6,floorY-.09,0,13.35,.18,3.55,slab,.019).geometry);
  // Sand and aggregate stockpiles nearby, spoil heaps of excavated soil along the site boundary.
  const sand=surface('sand',{color:0xe6d2b0}),gravel=surface('gravel',{color:0xbab6b0}),spoil=surface('dirt',{color:0xd6cec4});
  for(const [m,x,z,r,h,s,a] of [[sand,-15,-19,5,1.9,1.3,.5],[sand,-7,-27,3.4,1.3,1,0],[sand,30,20,3.8,1.5,1.2,.3],[gravel,21,-17,4.6,1.7,1.4,-.4],[gravel,28,-9,3.2,1.2,1,0],[gravel,-24,14,3.5,1.4,1.2,-.6],
    [spoil,6,-50,10,4.6,2.6,.1],[spoil,44,-36,9,4,2.4,-.7],[spoil,-44,-6,9,4.2,2.5,1.3],[spoil,-48,30,10,4,2.5,.6],[spoil,52,16,9,3.8,2.6,1.4],[spoil,12,54,10,4.2,2.8,-.1]]){
    const pile=heap(m,r,h,s,x-z);pile.position.set(x,grade,z);pile.rotation.y=a;g.add(pile);
  }
  return g;
}

export function createLocations(){
  return {specimen:laboratory(),frame:landscape()};
}
