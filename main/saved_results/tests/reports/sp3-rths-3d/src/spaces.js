import * as T from 'three';
import {Line2} from 'three/addons/lines/Line2.js';
import {LineGeometry} from 'three/addons/lines/LineGeometry.js';
import {LineMaterial} from 'three/addons/lines/LineMaterial.js';
import {hingePhase} from './data.js';
import {STRONG_FLOOR_Y,bolt} from './rig.js';
import {exteriorColumn,interiorColumn,beamSection} from './sections.js';
import {surface,boxUV} from './env.js';

const vec=(x,y,z)=>new T.Vector3(x,y,z);
function line(group,points,color,opacity=1,dashed=false){
  const geo=new T.BufferGeometry().setFromPoints(points);
  const params={color,transparent:opacity<1,opacity,toneMapped:false};
  const obj=new T.Line(geo,dashed?new T.LineDashedMaterial({...params,dashSize:.10,gapSize:.075}):new T.LineBasicMaterial(params));
  if(dashed)obj.computeLineDistances();group.add(obj);return obj;
}
export function label(group,text,x,y,z,height,color='#d3ded5'){
  const canvas=document.createElement('canvas'),ctx=canvas.getContext('2d');canvas.height=64;
  ctx.font='38px "Plex Mono", Consolas, monospace';canvas.width=Math.ceil(ctx.measureText(text).width)+18;
  ctx.font='38px "Plex Mono", Consolas, monospace';ctx.textBaseline='middle';ctx.textAlign='center';ctx.fillStyle=color;ctx.fillText(text,canvas.width/2,33);
  const tx=new T.CanvasTexture(canvas);tx.colorSpace=T.SRGBColorSpace;
  const obj=new T.Sprite(new T.SpriteMaterial({map:tx,transparent:true,depthWrite:false,toneMapped:false}));
  obj.position.set(x,y,z);obj.scale.set(height*canvas.width/64,height,1);group.add(obj);return obj;
}
function block(g,x,y,z,w,h,d,material){
  const obj=new T.Mesh(boxUV(new T.BoxGeometry(w,h,d)),material);obj.position.set(x,y,z);obj.castShadow=obj.receiveShadow=true;g.add(obj);return obj;
}
const plateT=.018,jointHalf=.183,blend=.16;

function buildSteel(members,run){
  const indices=[],triangleEnds=[],colors=[],uvs=[],byHinge=run.labels.map(()=>[]);
  const bare=new T.Color(0x56616a),palette=[bare,new T.Color(0xffae00),new T.Color(0xee271b)];
  let count=0;
  // UVs run along the member and around the section perimeter, in metres.
  function vertices(n,id,section,u){
    const first=count;count+=n;
    if(!section.perimeter){let d=0;section.perimeter=section.outline.map(([x,z],i,o)=>(d+=i?Math.hypot(x-o[i-1][0],z-o[i-1][1]):0));}
    for(let i=0;i<n;i++){colors.push(bare.r,bare.g,bare.b);const [x,z]=section.outline[i];uvs.push(u===undefined?x:u,u===undefined?z:section.perimeter[i]);}
    if(id!==undefined)byHinge[id].push([first,n]);
    return first;
  }
  function triangle(a,b,c,id){indices.push(a,b,c);triangleEnds.push(id);}
  for(const m of members){
    const {L,start,end,col,roof,section}=m;
    const samples=Array.from({length:17},(_,i)=>start+(Math.min(L,end)-start)*i/16);
    samples.push(end);
    // Include the exact flange contact planes and the limits of the rigid joint zone.
    for(const [u,sign] of [[start,1],[col?L:end,-1]]){
      const rigid=col&&(sign===-1||m.s>1)?jointHalf:0;
      for(const d of [rigid,rigid+blend/2,rigid+blend])samples.push(u+sign*d);
    }
    const sorted=samples.filter(v=>v>=start&&v<=end).sort((a,b)=>a-b);
    m.stations=sorted.filter((v,i)=>!i||v-sorted[i-1]>1e-6).map(u=>({u,rings:[]}));
    const ring=(station,id)=>{
      const last=station.rings.at(-1);
      if(last&&last.id===id)return last.base;
      const base=vertices(section.outline.length,id,section,station.u);station.rings.push({base,id});return base;
    };
    for(let i=1;i<m.stations.length;i++){
      const a=m.stations[i-1],b=m.stations[i];
      const q=((a.u+b.u)/2-start)/(Math.min(L,end)-start);
      const id=q<3/16?m.j:q>13/16?m.k:undefined;
      const lo=ring(a,id),hi=ring(b,id);
      for(let n=0;n<section.outline.length;n++){
        const next=(n+1)%section.outline.length;
        triangle(lo+n,hi+n,lo+next,id);triangle(lo+next,hi+n,hi+next,id);
      }
    }
    if(roof){
      const last=m.stations.at(-1),p=section.outline;last.cap=vertices(p.length,m.k,section);
      for(const [a,b,c] of T.ShapeUtils.triangulateShape(p.map(([x,z])=>new T.Vector2(x,z)),[])){
        triangle(last.cap+c,last.cap+b,last.cap+a,m.k);
      }
    }
  }
  const geometry=new T.BufferGeometry();
  const position=new T.BufferAttribute(new Float32Array(3*count),3).setUsage(T.DynamicDrawUsage);
  const normal=new T.BufferAttribute(new Float32Array(3*count),3).setUsage(T.DynamicDrawUsage);
  const color=new T.Float32BufferAttribute(colors,3).setUsage(T.DynamicDrawUsage);
  geometry.setIndex(indices);geometry.setAttribute('position',position);geometry.setAttribute('normal',normal);geometry.setAttribute('color',color);geometry.setAttribute('uv',new T.Float32BufferAttribute(uvs,2));
  geometry.boundingSphere=new T.Sphere(vec(run.bays*run.bayWidth/2,run.stories*run.storyHeight/2,0),Math.hypot(run.bays*run.bayWidth,run.stories*run.storyHeight)/2+2);
  const material=surface('worn',{vertexColors:true,metalness:.5,normal:.7});
  material.onBeforeCompile=shader=>{
    shader.fragmentShader=shader.fragmentShader.replace('#include <metalnessmap_fragment>',
      '#include <metalnessmap_fragment>\nfloat pigment=step(.12,vColor.r-vColor.b);\nmetalnessFactor=mix(metalnessFactor,.045,pigment);\nroughnessFactor=mix(roughnessFactor,.64,pigment);');
  };
  const mesh=new T.Mesh(geometry,material);mesh.name='Continuous numerical wide flanges';mesh.castShadow=mesh.receiveShadow=true;
  const oldPhase=run.labels.map(()=>0);
  function setPaint(t){
    for(let h=0;h<oldPhase.length;h++){
      const phase=hingePhase(run,h,t);if(oldPhase[h]===phase)continue;
      for(const [base,n] of byHinge[h])for(let i=base;i<base+n;i++)color.setXYZ(i,palette[phase].r,palette[phase].g,palette[phase].b);
      oldPhase[h]=phase;color.needsUpdate=true;
    }
  }
  function setRing(section,station,x,y,tx,ty){
    const inv=1/Math.hypot(tx,ty),ex=ty*inv,ey=-tx*inv;
    for(const {base} of station.rings){
      for(let i=0;i<section.outline.length;i++){
        const [u,z,nx,nz]=section.outline[i];
        position.setXYZ(base+i,x+u*ex,y+u*ey,z);normal.setXYZ(base+i,nx*ex,nx*ey,nz);
      }
    }
    if(station.cap!==undefined)for(let i=0;i<section.outline.length;i++){
      const [u,z]=section.outline[i];
      position.setXYZ(station.cap+i,x+u*ex,y+u*ey,z);normal.setXYZ(station.cap+i,-ey,ex,0);
    }
  }
  return {mesh,setRing,setPaint,triangleEnds,upload(){position.needsUpdate=normal.needsUpdate=true;}};
}

function createConnections(group,count){
  const plateMat=surface('worn',{color:0x7c868c,metalness:.5,normal:.7});
  const zinc=new T.MeshStandardMaterial({color:0xb2b8b8,metalness:.88,roughness:.34});
  function pieces(geometry,material,n,name){
    const obj=new T.InstancedMesh(geometry,material,n);obj.name=name;obj.castShadow=obj.receiveShadow=true;
    obj.instanceMatrix.setUsage(T.DynamicDrawUsage);obj.frustumCulled=false;group.add(obj);return obj;
  }
  const plates=pieces(new T.BoxGeometry(plateT,.34,.185),plateMat,count,'Beam end plates');
  const washers=pieces(new T.CylinderGeometry(.020,.020,.004,16).rotateZ(Math.PI/2),zinc,count*4,'End plate washers');
  const bolts=pieces(new T.CylinderGeometry(.015,.015,.013,6).rotateZ(Math.PI/2),zinc,count*4,'End plate hex heads');
  const pose=new T.Object3D();
  function set(i,x,y,angle,face,sign){
    const cos=Math.cos(angle),sin=Math.sin(angle);pose.rotation.z=angle;
    function place(mesh,id,offset,v,z){
      const u=sign*(face+offset);pose.position.set(x+u*cos-v*sin,y+u*sin+v*cos,z);pose.updateMatrix();mesh.setMatrixAt(id,pose.matrix);
    }
    place(plates,i,plateT/2,0,0);
    let j=i*4;
    for(const v of [-.133,.133])for(const z of [-.055,.055]){
      place(washers,j,plateT+.002,v,z);place(bolts,j,plateT+.0105,v,z);j++;
    }
  }
  return {set,upload(){for(const o of [plates,washers,bolts])o.instanceMatrix.needsUpdate=true;}};
}

export function createFrame(run){
  const root=new T.Group(),guides=new T.Group();root.add(guides);
  const H=run.storyHeight,W=run.bayWidth,I=run.height,J=run.jointRotation;
  const members=[],labels=new Map(run.labels.map((v,i)=>[v,i]));
  const column=c=>c===0||c===run.bays?exteriorColumn:interiorColumn;
  for(let c=0;c<=run.bays;c++)for(let s=1;s<=run.stories;s++){
    const cut=c===0&&s===1,y0=cut?I:(s-1)*H,L=s*H-y0,roof=s===run.stories;
    members.push({c,s,col:true,cut,y0,L,roof,start:0,end:roof?L+jointHalf:L,section:column(c),
      j:labels.get('C'+(c+1)+'-S'+s+'-bottom'),k:labels.get('C'+(c+1)+'-S'+s+'-top')});
    line(guides,[vec(c*W,y0,-.17),vec(c*W,s*H,-.17)],0x667e83,.44,true);
  }
  for(let s=1;s<=run.stories;s++)for(let c=0;c<run.bays;c++){
    members.push({c,s,col:false,L:W,start:column(c).a+plateT,end:W-column(c+1).a-plateT,section:beamSection,
      j:labels.get('B'+(c+1)+'-F'+s+'-left'),k:labels.get('B'+(c+1)+'-F'+s+'-right')});
    line(guides,[vec(c*W,s*H,-.17),vec((c+1)*W,s*H,-.17)],0x667e83,.44,true);
  }
  const steel=buildSteel(members,run);root.add(steel.mesh);
  const connections=createConnections(root,run.bays*run.stories*2);
  const concrete=surface('concrete',{color:0xd5dde6}),footPlate=surface('worn',{color:0x6e787d,metalness:.5});
  for(let c=1;c<=run.bays;c++){
    block(root,c*W,(STRONG_FLOOR_Y-.033)/2,0,.70,-.033-STRONG_FLOOR_Y,.62,concrete);
    block(root,c*W,-.0165,0,.45,.033,.38,footPlate);
    for(const dx of [-.158,.158])for(const dz of [-.14,.14])bolt(root,c*W+dx,0,dz,.018,.022);
  }
  for(let s=1;s<=run.stories;s++)label(guides,'F'+s,run.bays*W+.40,s*H,0,.22);
  label(guides,'3.048 m',W/2,.15,.02,.2);line(guides,[vec(.18,.15,0),vec(W/2-.55,.15,0)],0x7f9586,.65);line(guides,[vec(W/2+.55,.15,0),vec(W-.18,.15,0)],0x7f9586,.65);
  const stride=run.dofs+run.labels.length,vals=new Float32Array(stride),spots=run.labels.map(()=>vec(0,0,0));
  function update(t,scale){
    const sample=Math.min(run.frameCount-1,t*run.frameHz),lo=Math.floor(sample),hi=Math.min(lo+1,run.frameCount-1);
    for(let i=0;i<stride;i++)vals[i]=scale*T.MathUtils.lerp(run.frames[lo*stride+i],run.frames[hi*stride+i],sample-lo);
    const X=d=>d>0?vals[d-1]:0,P=i=>vals[run.dofs+i],physical=scale*run.sample(t,0)/1000;
    let plate=0;
    for(const m of members){
      const {s,c,col,j,k,L,start,end}=m;
      const u0=col?(m.cut?X(run.interfaceDof):X(s-1)):X(s),u1=X(s);
      const a0=col?(m.cut?X(run.interfaceRotation):X(J[c][s-1])):X(J[c][s]);
      const a1=col?X(J[c][s]):X(J[c+1][s]),r0=a0-P(j),r1=a1-P(k);
      const x0=c*W+u0,y0=col?m.y0:s*H,x1=(col?c:c+1)*W+u1,y1=s*H;
      if(!col){
        connections.set(plate++,x0,y0,a0,column(c).a,1);
        connections.set(plate++,x1,y1,a1,column(c+1).a,-1);
      }
      let nearestJ=Infinity,nearestK=Infinity;
      for(const station of m.stations){
        const u=station.u,q=u/L,q2=q*q,q3=q2*q;
        const b=q-2*q2+q3,d=q3-q2,db=1-4*q+3*q2,dd=3*q2-2*q;
        let x,y,tx,ty;
        if(col){
          x=c*W+u0+(u1-u0)*(3*q2-2*q3)-L*(b*r0+d*r1);y=y0+u;
          tx=(u1-u0)*6*q*(1-q)/L-db*r0-dd*r1;ty=1;
        }else{
          x=x0+u;y=y0+L*(b*r0+d*r1);tx=1;ty=db*r0+dd*r1;
        }
        // Make the section rigid through the actual plate contact area. Outside these short
        // zones the centerline follows the replay's original Hermite interpolation.
        const left=col?u-(s>1?jointHalf:0):u-start,right=col?L-u-jointHalf:end-u;
        const first=left<right,dist=first?left:right;
        if(dist<blend){
          const angle=first?(col&&s===1?0:a0):a1,cs=Math.cos(angle),sn=Math.sin(angle);
          const ux=col?-sn:cs,uy=col?cs:sn,along=first?u:u-L;
          const rigidX=(first?(m.cut?physical:x0):x1)+along*ux,rigidY=(first?y0:y1)+along*uy;
          const v=T.MathUtils.clamp(dist/blend,0,1),w=v*v*(3-2*v),dw=(first?1:-1)*6*v*(1-v)/blend;
          tx=ux+w*(tx-ux)+dw*(x-rigidX);ty=uy+w*(ty-uy)+dw*(y-rigidY);
          x=rigidX+w*(x-rigidX);y=rigidY+w*(y-rigidY);
        }
        steel.setRing(m.section,station,x,y,tx,ty);
        const frac=(u-start)/(Math.min(L,end)-start),da=Math.abs(frac-.10),dband=Math.abs(frac-.90);
        if(da<nearestJ){nearestJ=da;spots[j].set(x,y,m.section.b);}
        if(dband<nearestK){nearestK=dband;spots[k].set(x,y,m.section.b);}
      }
    }
    steel.setPaint(t);steel.upload();connections.upload();
  }
  return {root,guides,update,pickable:steel.mesh,hingeForFace:i=>steel.triangleEnds[i],spots,anchor:i=>i===0?vec(0,3*H,.05):vec(W,0,.05)};
}

export function createPath(run){
  const root=new T.Group(),guides=new T.Group();root.add(guides);
  const pos=new Float32Array(run.samples*3);
  // One coordinate per measured quantity. Time extends away from the front plane.
  const point=(i,v)=>v.set(run.at(i,0)/32*.77,.61+run.at(i,2)/5*.55,.84-1.68*i/(run.samples-1));
  const v=vec(0,0,0);for(let i=0;i<run.samples;i++){point(i,v);v.toArray(pos,i*3);}
  const data=new T.BufferAttribute(pos,3),geo=new T.BufferGeometry();geo.setAttribute('position',data);
  const ghost=new T.Line(geo,new T.LineBasicMaterial({color:0xd8c3dc,transparent:true,opacity:.40,depthWrite:false}));root.add(ghost);
  const pastGeo=new LineGeometry().setPositions(pos);
  const past=new Line2(pastGeo,new LineMaterial({color:0xe1a7dd,linewidth:.0055,worldUnits:true,toneMapped:false}));
  root.add(past);
  const head=new T.Mesh(new T.SphereGeometry(.018,18,12),new T.MeshBasicMaterial({color:0xc9f794,toneMapped:false}));root.add(head);
  const lx=-.77,rx=.77,b=.06,top=1.16,z=.84,end=-.84;
  for(let i=0;i<=4;i++){const x=lx+i*(rx-lx)/4;line(guides,[vec(x,b,z),vec(x,b,end)],0x607a71,.53);}
  for(let i=0;i<=4;i++){const y=b+(top-b)*i/4;line(guides,[vec(lx,y,z),vec(lx,y,end)],0x6b837a,.42);}
  for(const t of [0,10,20,30,run.duration]){const d=z-1.68*t/run.duration;line(guides,[vec(lx,top,d),vec(lx,b,d),vec(rx,b,d)],0x799084,.5);label(guides,t.toFixed(t===run.duration?1:0),rx+.065,b,d,.046);}
  line(guides,[vec(lx,top,z),vec(lx,b,z),vec(rx,b,z),vec(rx,b,end)],0xafc0b4,.95);
  for(const s of [-32,0,32])label(guides,String(s),s*.77/32,b-.046,z+.025,.046);
  for(const s of [-5,0,5])label(guides,String(s),lx-.065,.61+s/5*.55,z,.047);
  label(guides,'DISPLACEMENT (mm)',0,b-.125,z+.04,.06);
  label(guides,'FORCE (kip)',lx,top+.065,z,.06);
  label(guides,'TIME (s)',rx+.16,b+.015,-.62,.06);
  const slice=new T.Mesh(new T.PlaneGeometry(rx-lx,top-b),new T.MeshBasicMaterial({color:0xc7f794,transparent:true,opacity:.035,side:T.DoubleSide,depthWrite:false}));slice.position.y=.61;guides.add(slice);
  const cross=new T.LineSegments(new T.BufferGeometry().setAttribute('position',new T.Float32BufferAttribute(new Float32Array(12),3)),new T.LineBasicMaterial({color:0xc2dfad,transparent:true,opacity:.75}));cross.frustumCulled=false;guides.add(cross);
  function update(t){
    const i=Math.min(run.samples-1,Math.round(t*run.hz));pastGeo.instanceCount=i;point(i,head.position);slice.position.z=head.position.z;
    const {x,y,z}=head.position;cross.geometry.attributes.position.array.set([lx,y,z,x,y,z,x,b,z,x,y,z]);cross.geometry.attributes.position.needsUpdate=true;
  }
  return {root,guides,update,pickable:ghost,anchor:()=>head.position.clone()};
}
