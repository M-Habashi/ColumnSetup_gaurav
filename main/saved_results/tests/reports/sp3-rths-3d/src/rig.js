import * as T from 'three';
import {exteriorColumn} from './sections.js';
import {RoundedBoxGeometry} from 'three/addons/geometries/RoundedBoxGeometry.js';
import {mergeGeometries} from 'three/addons/utils/BufferGeometryUtils.js';
import {surface,boxUV} from './env.js';

const V=(x,y,z)=>new T.Vector3(x,y,z);
export const STRONG_FLOOR_Y=-.52;
const metal=(color,metalness=.68,roughness=.4,extra={})=>new T.MeshStandardMaterial({color,metalness,roughness,...extra});
const m={
  column:surface('worn',{color:0xa9b0b2,metalness:.62,normal:.7}),
  edge:surface('worn',{color:0xb8bfc2,metalness:.62,normal:.6}),
  black:surface('paint',{color:0x34393b,metalness:.25,normal:.6}),cast:surface('worn',{color:0x6b7378,metalness:.55}),
  dark:surface('worn',{color:0x3a4244,metalness:.5}), zinc:metal(0xb4b8b2,.88,.36),
  chrome:metal(0xf0f2ee,1,.07),bronze:metal(0xb3955b,.9,.32),gold:metal(0xad8747,.8,.38),
  actuator:metal(0x616c72,.80,.3),plinth:surface('concrete',{color:0xd5dde6}),
  oxide:surface('worn',{color:0x8a5a3c,metalness:.25,normal:1.2}),yellow:surface('paint',{color:0xf2bd1a,metalness:0}),
  reaction:surface('worn',{color:0x45474a,metalness:.55,normal:1.1}),grout:surface('concrete',{color:0xc9ccce}),
  rubber:metal(0x1b1e1d,0,.62),hole:metal(0x111413,.2,.9), weld:metal(0x72766f,.8,.56),
  label:new T.MeshBasicMaterial({color:0xd8dbce}),line:new T.MeshBasicMaterial({color:0xc5f794,toneMapped:false})
};
function mesh(g,mat,parent,x=0,y=0,z=0){
  const o=new T.Mesh(g,mat);o.position.set(x,y,z);o.castShadow=o.receiveShadow=true;parent.add(o);return o;
}
function box(parent,x,y,z,w,h,d,mat,round=0){
  return mesh(round?new RoundedBoxGeometry(w,h,d,2,round):new T.BoxGeometry(w,h,d),mat,parent,x,y,z);
}
function cylinder(parent,a,b,r,mat,n=24,rEnd=r){
  const dir=b.clone().sub(a),g=new T.CylinderGeometry(rEnd,r,dir.length(),n);
  const o=mesh(g,mat,parent);o.position.copy(a).lerp(b,.5);o.quaternion.setFromUnitVectors(V(0,1,0),dir.normalize());return o;
}
function axle(p,x0,x1,y,z,r,mat,n=36,r1=r){return cylinder(p,V(x0,y,z),V(x1,y,z),r,mat,n,r1);}
function post(p,x,y0,y1,z,r,mat,n=24){return cylinder(p,V(x,y0,z),V(x,y1,z),r,mat,n);}
function bolt(p,x,y,z,r=.019,h=.025,brass=false){
  post(p,x,y,y+.004,z,r*1.5,m.zinc);
  post(p,x,y+.004,y+h,z,r*1.13,brass?m.bronze:m.zinc,6);
  post(p,x,y+h,y+h+.009,z,r*.61,m.actuator,14);
}
function tube(p,points,r,mat){
  return mesh(new T.TubeGeometry(new T.CatmullRomCurve3(points.map(q=>V(...q))),24,r,8,false),mat,p);
}
function plateXY(p,points,z,d,mat,holes=[]){
  const s=new T.Shape();s.moveTo(...points[0]);for(const q of points.slice(1))s.lineTo(...q);s.closePath();
  for(const [x,y,r] of holes){const h=new T.Path();h.absarc(x,y,r,0,2*Math.PI,true);s.holes.push(h);}
  return mesh(new T.ExtrudeGeometry(s,{depth:d,bevelEnabled:true,bevelThickness:.0015,bevelSize:.0015,bevelSegments:2,curveSegments:20}),mat,p,0,0,z);
}
function tag(p,words,x,y,z,w,h,color='#d7d9cb',bg='',rotate=0){
  const c=document.createElement('canvas');c.width=512;c.height=128;
  const ctx=c.getContext('2d');if(bg){ctx.fillStyle=bg;ctx.fillRect(0,0,512,128);}
  ctx.fillStyle=color;ctx.font='bold 79px Arial';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(words,256,68);
  const texture=new T.CanvasTexture(c);texture.colorSpace=T.SRGBColorSpace;
  const o=mesh(new T.PlaneGeometry(w,h),new T.MeshBasicMaterial({map:texture,transparent:true,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-2}),p,x,y,z);
  o.rotation.z=rotate;o.castShadow=false;return o;
}
// Batch rigid hardware by material. Moving pieces are separate groups.
function batch(group){
  const bins=new Map();
  for(const mesh of [...group.children]){
    if(!mesh.isMesh||mesh.material.transparent)continue;mesh.updateMatrix();
    let geom=mesh.geometry.index?mesh.geometry.toNonIndexed():mesh.geometry.clone();
    geom.applyMatrix4(mesh.matrix);boxUV(geom);
    if(!bins.has(mesh.material))bins.set(mesh.material,[]);
    bins.get(mesh.material).push(geom);group.remove(mesh);mesh.geometry.dispose();
  }
  for(const [mat,geos] of bins){mesh(mergeGeometries(geos),mat,group);for(const g of geos)g.dispose();}
}
// The normalized centerline comes from the camera edge-tracking calibration in sp3_r_2_camera.m.
const profile=[[1590,0],[1500,.091],[1300,.277],[1100,.379],[900,.671],[700,.871],[500,1.075],[300,1.277],[297,1.277],[120,1.283],[62,1.283]]
  .map(([row,a])=>[(1590-row)/(1590-297)*1.016,a/1.277]);
function shape(y){
  for(let i=1;i<profile.length;i++)if(y<profile[i][0]){
    const [x0,a]=profile[i-1],[x1,b]=profile[i];return a+(b-a)*Math.max(0,(y-x0)/(x1-x0));
  }
  return profile.at(-1)[1];
}
function specimenSteel(y0,y1){
  const ring=exteriorColumn.outline,n=ring.length,rows=36;
  const pos=[],normal=[],index=[],weights=[],slopes=[];
  for(let j=0;j<=rows;j++){
    const y=y0+(y1-y0)*j/rows;
    weights.push(shape(y));slopes.push((shape(y+.001)-shape(y-.001))/.002);
    for(let i=0;i<n;i++){
      const [x,z,nx,nz]=ring[i];pos.push(x,y,z);normal.push(nx,0,nz);
      if(j<rows){
        const a=j*n+i,b=j*n+(i+1)%n;index.push(a,a+n,b,b,a+n,b+n);
      }
    }
  }
  const g=new T.BufferGeometry();g.setIndex(index);
  const points=new T.Float32BufferAttribute(pos,3),normals=new T.Float32BufferAttribute(normal,3);
  g.setAttribute('position',points.setUsage(T.DynamicDrawUsage));g.setAttribute('normal',normals.setUsage(T.DynamicDrawUsage));boxUV(g);
  function deform(offset){
    for(let j=0;j<=rows;j++)for(let i=0;i<n;i++){
      const [x,,nx,nz]=ring[i],ny=-offset*slopes[j]*nx,inv=1/Math.hypot(1,ny),k=j*n+i;
      points.setX(k,x+offset*weights[j]);normals.setXYZ(k,nx*inv,ny*inv,nz*inv);
    }
    points.needsUpdate=normals.needsUpdate=true;
  }
  return {g,deform};
}
export function createRig(){
  const root=new T.Group(),fixed=new T.Group(),head=new T.Group(),cap=new T.Group(),guides=new T.Group();
  root.add(fixed,head,cap,guides);
  // Separate specimen and reaction foundations, as visible in the wide setup photograph.
  const footingTop=-.028;
  box(fixed,0,(STRONG_FLOOR_Y+footingTop)/2,0,.85,footingTop-STRONG_FLOOR_Y,1.36,m.plinth,.009);
  box(fixed,0,-.020,0,.252,.018,.247,m.grout,.003);
  box(fixed,0,-.006,0,.225,.012,.222,m.column,.0015);
  for(const z of [-.48,.48]){
    box(fixed,0,.018,z,1.30,.092,.009,m.black);
    for(const y of [-.022,.059])box(fixed,0,y,z-.025,1.30,.011,.062,m.cast);
    for(const x of [-.532,.532]){
      const capY=x<0?.34:.30;
      post(fixed,x,STRONG_FLOOR_Y,capY,z-.021,.014,m.dark,16);
      for(let h=.095;h<capY-.02;h+=.011)post(fixed,x,h,h+.0035,z-.021,.016,m.cast,12);
      box(fixed,x,.072,z-.021,.095,.012,.101,m.cast,.002);bolt(fixed,x,.078,z-.021,.022,.031);
      post(fixed,x,capY-.042,capY+.017,z-.021,.023,m.yellow,16);
      box(fixed,x,capY+.025,z-.021,.071,.023,.071,m.yellow,.004);
      box(fixed,x,STRONG_FLOOR_Y+.012,z-.021,.093,.024,.106,m.black,.003);
    }
  }
  for(const x of [-.048,.048])for(const z of [-.061,.061]){
    post(fixed,x,0,.007,z,.025,m.black);
    post(fixed,x,.007,.034,z,.023,m.bronze,16);
    post(fixed,x,.034,.038,z,.0255,m.zinc);
    bolt(fixed,x,.038,z,.013,.015);
  }
  for(const x of [-.098,.098])for(const z of [-.065,.065]){
    tube(fixed,[[x-.007,0,z],[x,.004,z],[x+.008,0,z]],.0028,m.weld);
  }
  // W8×28 has two flange plates and a continuous web across the actuator axis.
  const height=1.205,pinY=1.016;
  const enamel=surface('paint',{color:0x2f86e0,metalness:.15,normal:.6});
  const extension=new T.Group();root.add(extension);
  const bent=[[0,pinY,root],[pinY,height,extension]].map(([a,b,parent])=>{
    const {g,deform}=specimenSteel(a,b);return {member:mesh(g,m.column,parent),deform};
  });
  box(cap,0,height+.004,0,.211,.011,.179,m.edge,.002);
  // Clevis bolted to the right flange. The piston and specimen share the moving pin.
  box(head,.123,pinY,0,.036,.188,.185,m.cast,.007);
  for(const y of [pinY-.066,pinY+.066])for(const z of [-.062,.062]){
    axle(head,.083,.151,y,z,.008,m.zinc,14);axle(head,.143,.158,y,z,.013,m.zinc,6);
  }
  const pinX=.206;
  for(const z of [-.065,.037]){
    const pts=[[.14,pinY-.073],[.204,pinY-.073],[.229,pinY-.062],[.25,pinY-.038],[.258,pinY-.013],[.257,pinY+.021],[.243,pinY+.048],[.216,pinY+.068],[.14,pinY+.073]];
    plateXY(head,pts,z,.028,m.black,[[pinX,pinY,.026]]);
  }
  cylinder(head,V(pinX,pinY,-.078),V(pinX,pinY,.079),.025,m.zinc,36);
  cylinder(head,V(pinX,pinY,.065),V(pinX,pinY,.075),.038,m.bronze,36);
  cylinder(head,V(pinX,pinY,.075),V(pinX,pinY,.083),.0295,m.cast,24);
  cylinder(head,V(pinX,pinY,.083),V(pinX,pinY,.085),.012,m.black,6);
  axle(head,.21,.34,pinY,0,.044,m.cast,36,.033);
  axle(head,.314,.344,pinY,0,.047,m.zinc,28);
  axle(head,.35,.431,pinY,0,.075,m.cast,48,.076);
  axle(head,.34,.353,pinY,0,.069,m.bronze,48);
  axle(head,.426,.443,pinY,0,.073,m.edge,48);
  for(let j=0;j<8;j++){
    const a=j*Math.PI/4;axle(head,.331,.349,pinY+.059*Math.cos(a),.059*Math.sin(a),.0064,m.bronze,6);
  }
  tag(head,'LOAD CELL',.39,pinY,.073,.06,.016,'#27302b','#ccc8ad');
  const piston=axle(root,.438,.668,pinY,0,.035,m.chrome,48);
  // Barrel and tie rods terminate in a pinned seat on the buttressed reaction plate.
  axle(fixed,.652,.686,pinY,0,.058,m.chrome,48);
  axle(fixed,.671,.7,pinY,0,.077,m.black,48);
  axle(fixed,.693,.724,pinY,0,.084,m.zinc,48);
  axle(fixed,.721,1.14,pinY,0,.085,m.black,48,.089);
  for(const x of [.732,.753,1.10,1.125])axle(fixed,x,x+.009,pinY,0,.0855,m.dark,48);
  for(const x of [.745,1.132])box(fixed,x,pinY,0,.035,.187,.172,m.cast,.014);
  for(const y of [-.077,.077])for(const z of [-.067,.067]){
    axle(fixed,.728,1.16,pinY+y,z,.0068,m.black,16);
    axle(fixed,.722,.737,pinY+y,z,.012,m.bronze,6);axle(fixed,1.145,1.16,pinY+y,z,.012,m.zinc,6);
  }
  axle(fixed,1.146,1.211,pinY,0,.051,m.cast,36);
  cylinder(fixed,V(1.195,pinY,-.094),V(1.195,pinY,.096),.031,m.chrome,32);
  const side=[[1.16,.977],[1.295,.924],[1.295,1.104],[1.17,1.064],[1.146,1.037]];
  for(const z of [-.081,.053])plateXY(fixed,side,z,.028,m.black,[[1.195,pinY,.032]]);
  box(fixed,1.32,pinY,0,.054,.33,.32,m.black,.003);
  for(const y of [.899,1.135])for(const z of [-.115,.115])axle(fixed,1.277,1.309,y,z,.020,m.zinc,6);
  const blockTop=.207;
  box(fixed,1.66,(STRONG_FLOOR_Y+blockTop)/2,0,1.14,blockTop-STRONG_FLOOR_Y,1.30,m.plinth,.010);
  box(fixed,1.66,.223,0,.94,.032,1.04,m.oxide,.003);
  box(fixed,1.361,.764,0,.041,1.05,.81,m.reaction,.006);
  for(const z of [-.32,.295]){
    plateXY(fixed,[[1.382,.241],[2.07,.241],[1.53,1.20],[1.382,1.26]],z,.025,m.reaction);
    tube(fixed,[[1.391,.25,z],[1.391,.71,z],[1.391,1.19,z]],.004,m.weld);
  }
  for(const x of [1.27,2.02])for(const z of [-.452,.452]){
    box(fixed,x,.245,z,.115,.013,.104,m.cast,.0015);bolt(fixed,x,.252,z,.025,.035);
    const length=x>1.9?.70:.17;
    post(fixed,x,.28,.28+length,z,.012,m.black,14);
    for(let y=.30;y<.28+length;y+=.019)post(fixed,x,y,y+.004,z,.0145,m.cast,12);
  }
  // Independent square-tube support frame beside the actuator.
  for(const z of [-.57,.66]){
    box(fixed,.85,.155,z,.059,1.35,.059,m.oxide,.002);
    box(fixed,.85,STRONG_FLOOR_Y+.011,z,.115,.021,.107,m.cast,.002);
  }
  box(fixed,.85,.844,.045,.063,.068,1.29,m.oxide,.0015);
  box(fixed,.922,1.123,.006,.20,.085,.128,m.black,.005);
  box(fixed,.90,1.177,.013,.153,.026,.107,m.zinc,.003);
  axle(fixed,.775,1.026,1.171,-.057,.026,m.cast,28);
  for(const [i,x] of [.84,.971].entries()){
    post(fixed,x,1.18,1.217,.029,.016,m.zinc,6);
    tube(fixed,[[x,1.214,.029],[x+.055,1.242,.034],[1.23,1.23,.075+i*.048],[1.40+i*.095,1.09,.18+i*.063],[1.53+i*.089,.74,.28+i*.064],[1.55+i*.10,.29,.38+i*.064],[1.60+i*.10,.29,.65+i*.05],[1.86+i*.12,-.38,.78+i*.09],[2.16,-.49,.68+i*.12]],.018-i*.002,m.rubber);
    axle(fixed,x+.025,x+.069,1.233,.031,.019,m.zinc,16);
  }
  tube(fixed,[[.397,1.02,.071],[.42,.972,.096],[.58,.842,.10],[.70,.825,.13],[.86,1.12,.087]],.004,m.rubber);
  const profileGeo=new T.BufferGeometry(),pp=new Float32Array(39*3);profileGeo.setAttribute('position',new T.BufferAttribute(pp,3));
  const center=new T.Line(profileGeo,new T.LineBasicMaterial({color:0xc7f995,transparent:true,opacity:.65}));guides.add(center);
  const measurement=new T.LineSegments(new T.BufferGeometry().setFromPoints([V(-.235,0,.01),V(-.235,pinY,.01),V(-.255,0,.01),V(-.21,0,.01),V(-.255,pinY,.01),V(-.21,pinY,.01)]),new T.LineDashedMaterial({color:0xd3e6ce,dashSize:.023,gapSize:.012,transparent:true,opacity:.58}));measurement.computeLineDistances();guides.add(measurement);
  const datumTag=tag(guides,'1.016 m',-.25,.52,.012,.163,.033,'#d5e8d2','',Math.PI/2);
  datumTag.material.toneMapped=false;
  const forceArrow=new T.ArrowHelper(V(-1,0,0),V(.206,pinY+.14,0),.2,0xe6abd9,.037,.019);guides.add(forceArrow);
  const forceLead=new T.Line(new T.BufferGeometry().setFromPoints([V(0,0,0),V(0,.116,0)]),new T.LineDashedMaterial({color:0xd6a3cd,dashSize:.012,gapSize:.009,transparent:true,opacity:.75}));forceLead.computeLineDistances();guides.add(forceLead);
  batch(fixed);batch(head);batch(cap);
  let last=Infinity;
  function update(dm,fm,factor){
    const offset=-dm*factor/1000;
    if(offset!==last){
      for(const part of bent)part.deform(offset);
      head.position.x=offset;cap.position.x=offset*shape(height);
      const start=.438+offset,end=.668;piston.position.x=(start+end)/2;piston.scale.y=(end-start)/(.668-.438);
      for(let i=0;i<39;i++){const y=pinY*i/38;pp[3*i]=offset*shape(y);pp[3*i+1]=y;pp[3*i+2]=.0051;}
      profileGeo.attributes.position.needsUpdate=true;profileGeo.computeBoundingSphere();last=offset;
    }
    const a=Math.abs(fm)*.064;forceArrow.visible=a>.012;forceLead.visible=forceArrow.visible;forceLead.position.set(pinX+offset,pinY+.016,.086);
    forceArrow.position.set(pinX+offset,pinY+.132,.086);forceArrow.setDirection(V(fm>=0?-1:1,0,0));forceArrow.setLength(Math.max(a,.012),Math.min(.038,a*.35),Math.min(.025,a*.22));
  }
  function setCoupled(on){
    root.rotation.y=on?Math.PI:0;extension.visible=cap.visible=!on;
    for(const {member} of bent)member.material=on?enamel:m.column;
  }
  return {root,guides,update,setCoupled,floorY:STRONG_FLOOR_Y,anchor:(side)=>side===0?V(head.position.x-.097,1.016,.077):V(head.position.x+.393,1.045,.067),pin:()=>V(head.position.x+.206,1.016,.088),base:V(-.048,.054,.07)};
}
export {V,metal,box,cylinder,post,bolt,tube,batch,tag};
