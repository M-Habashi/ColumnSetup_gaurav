import * as T from 'three';

// Photo-scanned CC0 surfaces come from Poly Haven (polyhaven.com).
export const manager=new T.LoadingManager();
const loader=new T.TextureLoader(manager),cache={};
// Real size of one texture tile in metres. Geometry UVs are in metres (see boxUV).
const tiles={floor:2.4,concrete:1.6,paint:1.2,worn:1.1,soil:2.48,gravel:2,sand:2.1,dirt:2.2,clad:1.1};
// Ground surfaces never repeat: mean linear green of each, for the large-scale variation below.
const grounds={floor:.0955,soil:.1587,gravel:.3881,sand:.3661,dirt:.1775};
function tex(file,srgb){
  if(!cache[file]){
    const t=cache[file]=loader.load('./tex/'+file+'.webp');
    t.wrapS=t.wrapT=T.RepeatWrapping;t.anisotropy=8;t.repeat.setScalar(1/tiles[file.split('_')[0]]);
    if(srgb)t.colorSpace=T.SRGBColorSpace;
  }
  return cache[file];
}
// Each tile is sampled at a random offset chosen by a smooth noise field (after Quilez), so no pattern repeats.
const noTile=`
float ntHash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float ntNoise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
  return mix(mix(ntHash(i),ntHash(i+vec2(1,0)),f.x),mix(ntHash(i+vec2(0,1)),ntHash(i+vec2(1,1)),f.x),f.y);}
vec4 noTile(sampler2D t,vec2 uv){
  float k=ntNoise(uv*.43)*7.,i=floor(k),f=smoothstep(.25,.75,fract(k));vec2 dx=dFdx(uv),dy=dFdy(uv);
  return mix(textureGrad(t,uv+sin(vec2(3,7)*i),dx,dy),textureGrad(t,uv+sin(vec2(3,7)*(i+1.)),dx,dy),f);
}`;
export function surface(name,{normal=1,...params}={}){
  const m=new T.MeshStandardMaterial({map:tex(name+'_d',true),normalMap:tex(name+'_n'),normalScale:new T.Vector2(normal,normal),
    roughnessMap:tex(name+'_r'),aoMap:tex(name+'_r'),aoMapIntensity:.7,roughness:1,metalness:0,...params});
  const mean=grounds[name];
  if(mean){
    m.onBeforeCompile=s=>{
      let f=s.fragmentShader.replace('#include <common>','#include <common>\n'+noTile);
      for(const [chunk,map,uv] of [['map_fragment','map','vMapUv'],['roughnessmap_fragment','roughnessMap','vRoughnessMapUv'],['normal_fragment_maps','normalMap','vNormalMapUv'],['aomap_fragment','aoMap','vAoMapUv']])
        f=f.replace('#include <'+chunk+'>',T.ShaderChunk[chunk].replaceAll('texture2D( '+map+', '+uv+' )','noTile( '+map+', '+uv+' )'));
      s.fragmentShader=f.replace('#include <emissivemap_fragment>','diffuseColor.rgb*=mix(1.,texture2D(map,vMapUv*.083+.37).g/'+mean+',.55);\n#include <emissivemap_fragment>');
    };
    m.customProgramCacheKey=()=>'ground-'+name;
  }
  return m;
}
// Planar UVs in metres from the dominant normal axis. Non-indexed geometry is projected per triangle.
export function boxUV(g){
  const p=g.attributes.position,n=g.attributes.normal,uv=new Float32Array(p.count*2),tri=!g.index,v=new T.Vector3();
  for(let i=0;i<p.count;i++){
    if(!tri||i%3===0){v.set(0,0,0);for(let k=0;k<(tri?3:1);k++)v.x+=Math.abs(n.getX(i+k)),v.y+=Math.abs(n.getY(i+k)),v.z+=Math.abs(n.getZ(i+k));}
    const [a,b]=v.y>=v.x&&v.y>=v.z?[p.getX(i),p.getZ(i)]:v.x>=v.z?[p.getZ(i),p.getY(i)]:[p.getX(i),p.getY(i)];
    uv[2*i]=a;uv[2*i+1]=b;
  }
  g.setAttribute('uv',new T.BufferAttribute(uv,2));return g;
}
// A disc (or ellipse, stretched along x) that fades out along a ragged edge into the surface beneath it.
export function groundDisc(material,radius,fade,stretch=1){
  const n=256,c=document.createElement('canvas');c.width=c.height=n;
  const x=c.getContext('2d'),img=x.createImageData(n,n),grid=Array.from({length:17*17},Math.random);
  const noise=(u,v)=>{const i=Math.floor(u),j=Math.floor(v),a=u-i,b=v-j,g=(p,q)=>grid[(j+q)*17+i+p];return (g(0,0)*(1-a)+g(1,0)*a)*(1-b)+(g(0,1)*(1-a)+g(1,1)*a)*b;};
  for(let j=0;j<n;j++)for(let i=0;i<n;i++){
    const u=i/n,v=j/n,r=2*Math.hypot(u-.5,v-.5)+.4*(noise(u*16,v*16)-.5);
    img.data[4*(j*n+i)+1]=255*(1-T.MathUtils.smoothstep(r,fade,1));img.data[4*(j*n+i)+3]=255;
  }
  x.putImageData(img,0,0);
  const alpha=new T.CanvasTexture(c);alpha.channel=1;
  const geo=new T.CircleGeometry(radius,128).rotateX(-Math.PI/2).scale(stretch,1,1);geo.setAttribute('uv1',geo.attributes.uv.clone());boxUV(geo);
  Object.assign(material,{alphaMap:alpha,transparent:true});
  const mesh=new T.Mesh(geo,material);mesh.receiveShadow=true;mesh.userData.ao=true;return mesh;
}

// Clear daytime sky with a few slowly drifting fair-weather clouds on a layer above the site.
export function createSky(sun){
  const material=new T.ShaderMaterial({side:T.BackSide,depthWrite:false,depthTest:false,uniforms:{sun:{value:sun},time:{value:0}},
    vertexShader:'varying vec3 dir;void main(){dir=position;gl_Position=(projectionMatrix*vec4(mat3(viewMatrix)*position,1.)).xyww;}',
    fragmentShader:`uniform vec3 sun;uniform float time;varying vec3 dir;
      float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
      float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
      float fbm(vec2 p){float v=0.,a=.5;for(int i=0;i<6;i++){v+=a*noise(p);p=mat2(1.6,1.2,-1.2,1.6)*p;a*=.5;}return v;}
      float cloud(vec2 p){return fbm(p+1.2*fbm(.6*p+3.1));}
      void main(){
        vec3 d=normalize(dir);float h=d.y,s=max(dot(d,sun),0.);
        vec3 col=mix(vec3(.44,.63,.92),vec3(.025,.15,.62),pow(max(h,0.),.42))*1.35;
        col+=vec3(1.,.88,.72)*(pow(s,8.)*.22+pow(s,120.)*.7)+vec3(80.)*smoothstep(.99988,.99993,s);
        if(h>0.){
          vec2 p=d.xz/(h+.07)*.8+vec2(.013,.005)*time;
          float n=cloud(.75*p),c=smoothstep(.63,.75,n)*smoothstep(.015,.14,h);
          float lit=clamp(.8+5.*(n-cloud(.75*(p+.06*sun.xz))),.45,1.15);
          col=mix(col,mix(vec3(.6,.66,.78),vec3(1.2,1.16,1.1),lit)*1.55,c);
        }
        gl_FragColor=vec4(mix(col,vec3(.2,.19,.15),smoothstep(0.,-.05,h)),1.);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
      }`});
  const mesh=new T.Mesh(new T.SphereGeometry(1,48,24),material);mesh.frustumCulled=false;mesh.renderOrder=-100;mesh.userData.noAO=true;
  return mesh;
}
// A tipped stockpile or spoil heap: a rounded cone with a ragged toe, stretched along x. Sizes in metres.
export function heap(material,r,h,stretch=1,seed=1){
  const geo=new T.PlaneGeometry(2,2,72,72).rotateX(-Math.PI/2),p=geo.attributes.position,uv=new Float32Array(p.count*2);
  const toe=a=>1+.09*Math.sin(3*a+seed)+.05*Math.sin(7*a+2*seed)+.03*Math.sin(13*a+5*seed);
  for(let i=0;i<p.count;i++){
    const x=p.getX(i),z=p.getZ(i),d=Math.hypot(x,z)/toe(Math.atan2(z,x)),X=x*r*stretch,Z=z*r;
    const y=d<1?h*(.5*(1-d)+.5*T.MathUtils.smoothstep(1-d,0,1))*(1+.05*Math.sin(X*1.7+seed)*Math.sin(Z*2.1-seed)):-.08;
    p.setXYZ(i,X,y,Z);uv[2*i]=X;uv[2*i+1]=Z;
  }
  geo.setAttribute('uv',new T.BufferAttribute(uv,2));geo.computeVertexNormals();
  const mesh=new T.Mesh(geo,material);mesh.castShadow=mesh.receiveShadow=true;return mesh;
}

// The lab uses the neutral studio light set up in scene.js; the site is lit by its own sky.
export function createPlaces(renderer){
  const sun=new T.Vector3(-.52,.62,.58).normalize(),sky=createSky(sun);
  const environment=new T.PMREMGenerator(renderer).fromScene(new T.Scene().add(new T.Mesh(sky.geometry,sky.material)),0,.1,10).texture;
  return {specimen:{sun:new T.Vector3(-.38,.86,.34).normalize()},frame:{sun,sky,environment}};
}
