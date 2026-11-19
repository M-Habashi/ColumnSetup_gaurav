import {clamp, signed} from './data.js';

const mono = '"Plex Mono", monospace', sans = '"DM Sans", sans-serif';
const blue = '#007CA8', purple = '#74058A', ink = '#182326';
export const plotTypes = {
  displacement: {title:'Displacement', channel:'INTERFACE  /  dₘ', unit:'mm', col:0},
  hysteresis: {title:'Force–displacement', channel:'LOAD CELL  /  fₘ', unit:'kip', col:2},
  roof: {title:'Roof displacement', channel:'NUMERICAL FEM  /  x₃,ₙ', unit:'mm', col:6},
  ground: {title:'Ground acceleration', channel:'EL CENTRO  /  aɡ', unit:'g', col:3}
};

function fit(canvas, w, h, ratio) {
  const pw = Math.round(w * ratio), ph = Math.round(h * ratio);
  if (canvas.width !== pw || canvas.height !== ph) { canvas.width = pw; canvas.height = ph; }
  const c = canvas.getContext('2d');
  c.setTransform(pw / w, 0, 0, ph / h, 0, 0);
  c.clearRect(0, 0, w, h);
  return c;
}
function write(c, val, x, y, size, color, family=mono, weight=400, align='left') {
  c.font = weight+' '+size+'px '+family; c.fillStyle=color; c.textAlign=align; c.fillText(val,x,y);
}
function stroke(c,x1,y1,x2,y2,color,width=1) {
  c.beginPath();c.moveTo(x1,y1);c.lineTo(x2,y2);c.strokeStyle=color;c.lineWidth=width;c.stroke();
}
function trace(c, start, end, delta, x, y, color, width, dashed=false) {
  c.beginPath();for(let i=start;i<=end;i+=delta){ if(i===start)c.moveTo(x(i),y(i));else c.lineTo(x(i),y(i)); }
  if ((end-start)%delta) c.lineTo(x(end),y(end));
  c.strokeStyle=color;c.lineWidth=width;c.setLineDash(dashed?[5,3]:[]);c.stroke();c.setLineDash([]);
}
// Shared canvas renderer for the visor instruments, their enlarged plots and the WebXR textures.
export function drawPlot(canvas, run, t, type, w=252, h=163, full=false) {
  const cfg=plotTypes[type], small=w<185, r=full?Math.min(2,devicePixelRatio||1):2;
  const c=fit(canvas,w,h,r), pad=small?7:12, v=run.sample(t,cfg.col);
  c.fillStyle='#1b2424';c.fillRect(0,0,w,h);
  c.fillStyle= type==='hysteresis' ? '#e0b5e3' : '#b5e4ef';c.fillRect(pad,pad+1,4,4);
  write(c,cfg.channel,pad+9,pad+5,small?7:9,'#b4c5c0');
  write(c,cfg.title,pad,pad+(small?22:27),small?12:16,'#f2f5ef',sans,560);
  const valY=pad+(small?40:52);
  write(c,signed(v),pad,valY,small?16:23,'#edf4ed',mono);
  const valueWidth=c.measureText(signed(v)).width;
  write(c,cfg.unit,pad+valueWidth+4,valY-1,small?8:10,'#adbbb2');
  const areaTop=valY+8, left=pad+(small?20:25),right=w-pad-5,top=areaTop+8,bottom=h-(small?16:21);
  c.fillStyle='#dce5dc';c.fillRect(pad,areaTop,w-2*pad,h-areaTop-5);
  let from=0,to=run.duration,ym=35,xm=32;
  const loop=type==='hysteresis', dm=type==='displacement';
  if(!full&&!loop){from=Math.max(0,Math.min(t-2,run.duration-4));to=from+4;}
  if(loop)ym=5;else if(type==='ground')ym=1.2;else if(type==='roof')ym=115;else ym=40;
  const X=a=>left+(right-left)*(loop?(a+xm)/(2*xm):(a-from)/(to-from)),Y=a=>bottom-(bottom-top)*(a+ym)/(2*ym);
  const tx=i=>X(i/run.hz), dx=i=>X(run.at(i,0)), yy=i=>Y(run.at(i,cfg.col));
  const cur=Math.min(run.samples-1,Math.round(t*run.hz)), lo=Math.max(0,Math.floor(from*run.hz)),hi=Math.min(run.samples-1,Math.ceil(to*run.hz));
  const grid='#bdc9c0', axis='#73877b', text='#485d52', label=small?6.5:8;
  for(let k=-1;k<=1;k++){const y=Y(k*ym);stroke(c,left,y,right,y,k===0?axis:grid,.75);write(c,(k*ym).toString().replace('-','−'),left-3,y+2,label,text,mono,400,'right');}
  for(let k=0;k<=4;k++){const x=left+(right-left)*k/4;stroke(c,x,top,x,bottom,loop&&k===2?axis:grid,.65);}
  c.save();c.beginPath();c.rect(left-2,top-2,right-left+4,bottom-top+4);c.clip();
  const stride=Math.max(1,Math.floor((hi-lo)/(full?1700:650)));
  if(loop){
    // A faint outline gives the full recorded envelope. Saturation marks elapsed history.
    trace(c,0,run.samples-1,3,dx,yy,'#bba9bd',.8);
    trace(c,0,cur,2,dx,yy,'#a475ac',1);
    trace(c,Math.max(0,cur-250),cur,1,dx,yy,purple,full?2.5:1.8);
  }else{
    if(dm)trace(c,lo,hi,stride,tx,i=>Y(run.at(i,1)),'#181d1b',full?2.4:1.9,true);
    trace(c,lo,hi,stride,tx,yy,type==='ground'?ink:blue,full?1.9:1.4);
    const x=X(t);stroke(c,x,top,x,bottom,'#536b57',1);
  }
  const hx=loop?X(run.sample(t,0)):X(t),hy=Y(v);
  c.beginPath();c.arc(hx,hy,full?4:3,0,Math.PI*2);c.fillStyle=loop?purple:(type==='ground'?ink:blue);c.fill();c.strokeStyle='#fff';c.lineWidth=1.3;c.stroke();c.restore();
  const axisY=h-8;
  write(c,loop?'−32':from.toFixed(full?0:1),left,axisY,label,text);
  write(c,loop?'dₘ (mm)':'t (s)',(left+right)/2,axisY,label,text,mono,400,'center');
  write(c,loop?'+32':to.toFixed(full?2:1),right,axisY,label,text,mono,400,'right');
  if(dm&&!small){
    const lx=w-pad-61,ly=valY-11;
    stroke(c,lx,ly,lx+10,ly,'#8ad3ef',1.5);write(c,'dₘ',lx+14,ly+3,9,'#d6dfd9');
    c.setLineDash([3,2]);stroke(c,lx+32,ly,lx+42,ly,'#dce3dc',1.7);c.setLineDash([]);write(c,'dₙ',lx+46,ly+3,9,'#d6dfd9');
  }
}
export function drawWave(canvas,run,t){
  const w=Math.max(1,canvas.clientWidth),h=Math.max(5,canvas.clientHeight),c=fit(canvas,w,h,Math.min(2,devicePixelRatio));
  const played=w*t/run.duration,mid=h*.54,spacing=w<550?2:3;
  stroke(c,0,mid,w,mid,'#44504a',.7);
  for(let px=0;px<w;px+=spacing){
    const l=Math.floor(px/w*(run.samples-1)),r=Math.min(run.samples,Math.ceil((px+spacing)/w*run.samples));
    let hi=0,lo=0;for(let j=l;j<r;j++){const v=run.at(j,3);hi=Math.max(hi,v);lo=Math.min(lo,v);}
    const a=mid-hi*(h*.40),b=mid-lo*(h*.40);
    stroke(c,px+.5,Math.min(mid-.75,a),px+.5,Math.max(mid+.75,b),px<played?'#bcdf97':'#77857d',spacing===2?1:1.55);
  }
  stroke(c,played,4,played,h,'#dcfdb3',1.5);
  c.fillStyle='#d3f8a5';c.beginPath();c.moveTo(played-3,0);c.lineTo(played+3,0);c.lineTo(played+3,3);c.lineTo(played,6);c.lineTo(played-3,3);c.fill();
}
