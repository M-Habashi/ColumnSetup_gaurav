// A rolled section in the bending plane (x) and across its flanges (z), in metres.
function wideFlange(depth,width,flange,web,fillet){
  const a=depth/2,b=width/2,s=web/2,f=flange;
  const corners=[[-a,-b],[-a+f,-b],[-a+f,-s],[a-f,-s],[a-f,-b],[a,-b],[a,b],[a-f,b],[a-f,s],[-a+f,s],[-a+f,b],[-a,b]];
  const outline=[];
  for(let i=0;i<corners.length;i++){
    const [x,z]=corners[i],[ax,az]=corners[(i+11)%12],[bx,bz]=corners[(i+1)%12];
    const ix=Math.sign(x-ax),iz=Math.sign(z-az),ox=Math.sign(bx-x),oz=Math.sign(bz-z);
    const turn=ix*oz-iz*ox,r=turn<0?fillet:.0016;
    const cx=x+r*(ox-ix),cz=z+r*(oz-iz);
    // Tangent normals meet the flat web and flange faces without a shading seam.
    for(const t of [0,.5,1]){
      const nx=(1-t)*iz+t*oz,nz=-(1-t)*ix-t*ox,len=Math.hypot(nx,nz);
      outline.push([cx+turn*r*nx/len,cz+turn*r*nz/len,nx/len,nz/len]);
    }
  }
  return {a,b,outline};
}
export const exteriorColumn=wideFlange(.206,.166,.0104,.0074,.008);
export const interiorColumn=wideFlange(.303,.203,.0131,.0075,.012);
export const beamSection=wideFlange(.201,.165,.0102,.0062,.008);
