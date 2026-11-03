// unit flame path, scaled into (x,y,w,h)
function flame(x,y,w,h){const p=(a,b)=>`${(x+w*a).toFixed(1)},${(y+h*b).toFixed(1)}`;
return `M${p(.5,0)} C${p(.6,.2)} ${p(1.02,.36)} ${p(.94,.63)} C${p(.88,.87)} ${p(.7,1)} ${p(.5,1)} C${p(.3,1)} ${p(.12,.87)} ${p(.06,.63)} C${p(-.02,.36)} ${p(.4,.2)} ${p(.5,0)} Z`;}
function logo(cx,bottom,w){const h=w*1.25,x=cx-w/2,y=bottom-h;
return `<path d="${flame(x,y,w,h)}" fill="url(#g1)"/>
<path d="${flame(cx-w*.32,bottom-h*.05-h*.66,w*.64,h*.66)}" fill="url(#g2)"/>
<path d="${flame(cx-w*.16,bottom-h*.08-h*.36,w*.32,h*.36)}" fill="url(#g3)"/>`;}
const defs=`<linearGradient id="g1" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#E5484D"/><stop offset="1" stop-color="#F76B15"/></linearGradient>
<linearGradient id="g2" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#F76B15"/><stop offset="1" stop-color="#FFB224"/></linearGradient>
<linearGradient id="g3" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#FFB224"/><stop offset="1" stop-color="#FFE27A"/></linearGradient>`;
module.exports={flame,logo,defs};
