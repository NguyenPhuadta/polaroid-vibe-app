const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const elements = new Map();
const context = {
  document: {getElementById(id) {
    if (!elements.has(id)) elements.set(id, {getContext:()=>({}),addEventListener:()=>{}});
    return elements.get(id);
  }},
  Image: class {}, window: {}, Uint8ClampedArray, Map, Math
};
vm.createContext(context);
vm.runInContext(fs.readFileSync(__dirname+'/app.js','utf8'),context);
const {parseCube, sampleLut, haldCubeSize, applyDisposable, alpineColor, rgbToHsv, hsvToRgb} = context.window.filmLab;
assert.equal(haldCubeSize(1728,1728),144);
assert.throws(()=>haldCubeSize(512,511));
const n = 4, data = new Uint8ClampedArray(n**3*4);
for(let b=0;b<n;b++) for(let g=0;g<n;g++) for(let r=0;r<n;r++) {
  const i=4*(r+g*n+b*n*n);
  data.set([r*85,g*85,b*85,255],i);
}
const result = [0,0,0];
for(let i=0;i<1000;i++) {
  const rgb = [(i*37)%256,(i*71)%256,(i*109)%256];
  sampleLut({size:n,data},...rgb,result);
  rgb.forEach((v,c)=>assert.ok(Math.abs(v-result[c])<1e-10));
}
for(const rgb of [[0,0,0],[255,255,255],[255,0,0],[0,255,0],[0,0,255]]) {
  sampleLut({size:n,data},...rgb,result);
  rgb.forEach((v,c)=>assert.equal(v,result[c]));
}
// An independent channel permutation detects swapped LUT axes.
for(let i=0;i<data.length;i+=4) [data[i],data[i+1],data[i+2]]=[data[i+2],data[i],data[i+1]];
sampleLut({size:n,data},17,83,201,result);
[201,17,83].forEach((v,c)=>assert.ok(Math.abs(v-result[c])<1e-10));
console.log('PASS: Hald dimensions, 1000 identity colors, RGB endpoints, axis permutation.');
const photo = {width:4,height:4,data:new Uint8ClampedArray(64).fill(127)};
for(let i=3;i<64;i+=4) photo.data[i]=255;
const untouched = new Uint8ClampedArray(photo.data);
applyDisposable(photo,0);
assert.deepEqual(photo.data,untouched);
const copy = {width:4,height:4,data:new Uint8ClampedArray(photo.data)};
applyDisposable(photo,0.75); applyDisposable(copy,0.75);
assert.deepEqual(photo.data,copy.data);
assert.notDeepEqual(photo.data,untouched);
for(let i=3;i<64;i+=4) assert.equal(photo.data[i],255);
console.log('PASS: texture bypass, deterministic grain, preserved alpha.');
for(let i=0;i<1000;i++) {
  const rgb=[(i*37)%256,(i*71)%256,(i*109)%256];
  const back=hsvToRgb(...rgbToHsv(...rgb.map(v=>v/255)));
  rgb.forEach((v,c)=>assert.ok(Math.abs(v-back[c]*255)<1e-8));
  alpineColor(...rgb,0,result);
  rgb.forEach((v,c)=>assert.equal(v,result[c]));
  alpineColor(...rgb,1,result);
  result.forEach(v=>assert.ok(Number.isFinite(v)&&v>=0&&v<=255));
}
alpineColor(70,140,210,1,result);
const skyHue=rgbToHsv(...result.map(v=>v/255))[0];
assert.ok(skyHue>=150&&skyHue<=195,'Blue should grade to green-teal.');
alpineColor(245,245,245,1,result);
assert.ok(result[0]>result[1]&&result[1]>result[2],'Neutral highlights should become warm.');
console.log('PASS: HSV round trip, recipe bypass/range, teal blues, warm highlights.');

const cubeLines=['TITLE "identity"','LUT_3D_SIZE 2','DOMAIN_MIN 0 0 0','DOMAIN_MAX 1 1 1'];
for(let b=0;b<2;b++) for(let g=0;g<2;g++) for(let r=0;r<2;r++) cubeLines.push(`${r} ${g} ${b}`);
const cube=parseCube(cubeLines.join('\n'));
sampleLut(cube,17,83,201,result);
[17,83,201].forEach((v,c)=>assert.ok(Math.abs(v-result[c])<1e-8));
assert.throws(()=>parseCube('LUT_3D_SIZE 2\n0 0 0'));
assert.throws(()=>parseCube(cubeLines.join('\n').replace('DOMAIN_MAX 1 1 1','DOMAIN_MAX 2 2 2')));
const sx70=parseCube(fs.readFileSync(__dirname+'/assets/picturefx-sx70.cube','utf8'));
assert.equal(sx70.size,64);
sampleLut(sx70,0,0,0,result);
[0.172549,0.180392,0.172549].forEach((v,c)=>assert.ok(Math.abs(v*255-result[c])<0.0001));
for(let i=0;i<1000;i++) {sampleLut(sx70,(i*37)%256,(i*71)%256,(i*109)%256,result); result.forEach(v=>assert.ok(Number.isFinite(v)&&v>=0&&v<=255));}
console.log('PASS: CUBE identity/axes, malformed size/domain rejection, real SX-70 64³ data and finite output.');
