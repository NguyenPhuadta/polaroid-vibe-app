'use strict';
const $ = id => document.getElementById(id);
const descriptions = {
  'indoor-print': 'Indoor Flash Print: PX-680 phối màu kem ấm, bóng tối nâu, nét mềm và viền giấy. Không tái tạo ánh sáng flash thật.',
  'gmic-px680': 'Indoor Instant · PX-680: chỉnh ám xanh trước LUT, texture nhẹ không thêm cyan vào bóng tối. Chỉnh Tint theo ảnh thực tế; chưa hiệu chuẩn cho đèn cụ thể.',
  picturefx: 'PictureFX SX-70 Core LUT gốc: tương phản phai, xanh olive dịu, vùng sáng kem. Template chính đã chọn; grain, nét dịu và tối góc có thể chỉnh riêng.',
  'gmic-669': 'G’MIC / Pat David 669: instant dịu, vùng sáng hơi xanh kem, giữ màu cảnh rõ hơn.',
  'gmic-px70': 'G’MIC / Pat David PX-70: vùng tối xanh, vùng sáng vàng kem, lệch màu vintage rõ.',
  'gmic-timezero': 'G’MIC / Pat David Time Zero Expired: vàng cam và màu phai mạnh, hướng ảnh instant cũ.',
  alpine: 'Alpine Vintage: xanh trời → teal, xanh cây → olive, vùng sáng → kem ấm, bóng tối → nâu sâu. Công thức mới theo hai ảnh reference.',
  velvia50: 'Velvia 50: hướng màu rực và tương phản mạnh. Kiểm tra kỹ vùng cây và núi tối.',
  provia100f: 'Provia 100F: ứng viên cho màu phong cảnh cân bằng. So với Velvia trên cùng ảnh.',
  ektar100: 'Ektar 100: thử trên núi đá, trời xanh và cảnh nắng. Chú ý sắc đỏ và xanh.',
  portra400: 'Portra 400: thử cho cảnh sương hoặc màu dịu. Tên preset không đảm bảo mọi ảnh đều pastel.'
};
const original = $('original'), graded = $('graded');
const originalCtx = original.getContext('2d', {willReadFrequently: true});
const gradedCtx = graded.getContext('2d');
const lutCache = new Map();
let base = null, filename = 'landscape', version = 0, imageVersion = 0, frame;
function imageFrom(url) {
  return new Promise((resolve, reject) => {
    const img = new Image(); img.onload = () => resolve(img);
    img.onerror = () => reject(new Error('Không đọc được ảnh. Thử JPG hoặc PNG nhé.'));
    img.src = url;
  });
}
// A level-L Hald image has L^3 pixels per side and an L^2 RGB cube.
// Its flat order is red-fastest, then green, then blue.
function haldCubeSize(width, height) {
  const level = Math.round(Math.cbrt(width));
  if (width !== height || level ** 3 !== width) throw new Error('HaldCLUT không hợp lệ.');
  return level ** 2;
}
async function getLut(name) {
  if (name==='indoor-print') name='gmic-px680';
  if (!lutCache.has(name)) {
    const pending = name==='picturefx' ? fetch('assets/picturefx-sx70.cube').then(response => {
      if (!response.ok) throw new Error('Không tải được PictureFX SX-70.');
      return response.text();
    }).then(parseCube) : imageFrom(`assets/${name}.png`).then(img => {
      const size = haldCubeSize(img.naturalWidth, img.naturalHeight);
      const canvas = document.createElement('canvas');
      canvas.width = img.naturalWidth; canvas.height = img.naturalHeight;
      const ctx = canvas.getContext('2d', {willReadFrequently: true, colorSpace: 'srgb'});
      ctx.drawImage(img, 0, 0);
      return {size, data: ctx.getImageData(0, 0, canvas.width, canvas.height).data};
    });
    lutCache.set(name, pending);
    pending.catch(() => lutCache.delete(name));
  }
  return lutCache.get(name);
}
function parseCube(text) {
  let size = 0;
  const values = [];
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.split('#')[0].trim();
    if (!line || line.startsWith('TITLE')) continue;
    const fields = line.split(/\s+/);
    if (fields[0]==='LUT_3D_SIZE') {size=Number(fields[1]); continue;}
    if (fields[0]==='DOMAIN_MIN' || fields[0]==='DOMAIN_MAX') {
      const expected=fields[0]==='DOMAIN_MIN'?0:1;
      if (fields.length!==4 || fields.slice(1).some(v=>Number(v)!==expected)) throw new Error('CUBE domain chưa hỗ trợ.');
      continue;
    }
    const rgb=fields.map(Number);
    if (rgb.length!==3 || rgb.some(v=>!Number.isFinite(v))) throw new Error('Dữ liệu CUBE không hợp lệ.');
    values.push(rgb[0]*255,rgb[1]*255,rgb[2]*255,255);
  }
  if (!Number.isInteger(size) || size<2 || size>256 || values.length!==size**3*4) throw new Error('Kích thước CUBE không hợp lệ.');
  return {size,data:new Float32Array(values)};
}
function sampleLut(lut, r, g, b, result) {
  const n = lut.size, d = lut.data, scale = (n - 1) / 255;
  const rr = r * scale, gg = g * scale, bb = b * scale;
  const r0 = Math.floor(rr), g0 = Math.floor(gg), b0 = Math.floor(bb);
  const r1 = Math.min(r0 + 1, n - 1), g1 = Math.min(g0 + 1, n - 1), b1 = Math.min(b0 + 1, n - 1);
  const fr = rr - r0, fg = gg - g0, fb = bb - b0;
  const offsets = [r0+g0*n+b0*n*n, r1+g0*n+b0*n*n, r0+g1*n+b0*n*n, r1+g1*n+b0*n*n,
    r0+g0*n+b1*n*n, r1+g0*n+b1*n*n, r0+g1*n+b1*n*n, r1+g1*n+b1*n*n];
  for (let c = 0; c < 3; c++) {
    const a = d[offsets[0]*4+c]*(1-fr)+d[offsets[1]*4+c]*fr;
    const z = d[offsets[2]*4+c]*(1-fr)+d[offsets[3]*4+c]*fr;
    const e = d[offsets[4]*4+c]*(1-fr)+d[offsets[5]*4+c]*fr;
    const f = d[offsets[6]*4+c]*(1-fr)+d[offsets[7]*4+c]*fr;
    result[c] = (a*(1-fg)+z*fg)*(1-fb)+(e*(1-fg)+f*fg)*fb;
  }
}
function grainNoise(x, y, seed) {
  let h = Math.imul(x + 1, 374761393) ^ Math.imul(y + 1, 668265263) ^ seed;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967295 - 0.5;
}
function rgbToHsv(r,g,b) {
  const max = Math.max(r,g,b), min = Math.min(r,g,b), delta = max-min;
  let h = 0;
  if (delta) h = max===r ? ((g-b)/delta+6)%6 : max===g ? (b-r)/delta+2 : (r-g)/delta+4;
  return [h*60,max===0?0:delta/max,max];
}
function hsvToRgb(h,s,v) {
  const c=v*s, x=c*(1-Math.abs((h/60)%2-1)), m=v-c;
  const rgb=h<60?[c,x,0]:h<120?[x,c,0]:h<180?[0,c,x]:h<240?[0,x,c]:h<300?[x,0,c]:[c,0,x];
  return rgb.map(value=>value+m);
}
function hueWeight(h,center,width) {
  const distance = Math.min(Math.abs(h-center),360-Math.abs(h-center));
  return Math.max(0,1-distance/width);
}
function alpineColor(r,g,b,amount,result) {
  const [h,s,v]=rgbToHsv(r/255,g/255,b/255);
  const sky = hueWeight(h,215,65), foliage = hueWeight(h,115,65);
  // Hue-selective grading, no sky segmentation: blue fabric also becomes teal.
  const targetHue = h+(182-h)*sky*0.83+(65-h)*foliage*0.68;
  const targetSaturation = s*(0.78-0.12*sky-0.12*foliage);
  const rgb=hsvToRgb(targetHue,targetSaturation,v);
  const warm = Math.max(0,(1-s-0.1)/0.9), light=v*v;
  const offsets = [0.054*light*warm,0.003*light*warm,-0.096*light*warm];
  const floor = [0.055,0.035,0.028], ceiling = [0.9,0.825,0.715];
  for(let c=0;c<3;c++) {
    const exposed=Math.max(0,Math.min(1,rgb[c]*0.9+offsets[c]));
    const toned=floor[c]+(ceiling[c]-floor[c])*Math.pow(exposed,1.17);
    const original = c===0?r:c===1?g:b;
    result[c]=original*(1-amount)+toned*255*amount;
  }
}
// `alpine=true` is also the approved Indoor recipe's `no-color-cast` mode:
// keep softness/grain/vignette (0.23 coefficient), skip faded blacks and cast.
function applyDisposable(image, amount, alpine = false) {
  if (amount === 0) return;
  const {width:w,height:h,data:d} = image;
  const clean = new Uint8ClampedArray(d);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const i = (y*w+x)*4;
    const luma = (clean[i]*0.2126+clean[i+1]*0.7152+clean[i+2]*0.0722)/255;
    const shadow = (1-luma)**2, highlight = luma**2;
    const dx = (x-(w-1)/2)/(w/2), dy = (y-(h-1)/2)/(h/2);
    const vignette = 1-(alpine?0.23:0.13)*amount*Math.min(1,(dx*dx+dy*dy)/1.5);
    const grain = (grainNoise(x,y,31337)*0.55+grainNoise(x>>1,y>>1,9191)*0.45)*31*(0.65+0.6*shadow)*amount;
    for (let c = 0; c < 3; c++) {
      const left = (y*w+Math.max(0,x-1))*4+c, right = (y*w+Math.min(w-1,x+1))*4+c;
      const up = (Math.max(0,y-1)*w+x)*4+c, down = (Math.min(h-1,y+1)*w+x)*4+c;
      const softened = clean[i+c]*(1-0.22*amount)+(clean[left]+clean[right]+clean[up]+clean[down])*0.055*amount;
      // A modest faded black point and warm highlights / cyan-green shadows.
      const cast = alpine ? 0 : c===0 ? 5+8*highlight-5*shadow : c===1 ? 3+6*shadow : -7*highlight+4*shadow-3;
      const chromaGrain = grainNoise(x,y,501+c*137)*5*amount;
      const toned = alpine ? softened : softened*(1-0.075*amount)+9*amount+cast*amount;
      d[i+c] = toned*vignette+grain+chromaGrain;
    }
  }
}
// Green–magenta adjustment on processed sRGB, not a calibrated RAW white balance.
function indoorTint(r,g,b,amount,result) {
  const gains = [1+0.12*amount,1-0.12*amount,1+0.12*amount];
  [r,g,b].forEach((v,c)=>result[c]=Math.max(0,Math.min(255,v*gains[c])));
}
function printColor(r,g,b,result) {
  const luma = r*0.2126+g*0.7152+b*0.0722;
  const floor=[11,7,6], ceiling=[250,245,235];
  [r,g,b].forEach((v,c)=> {
    const muted=v*0.82+luma*0.18;
    result[c]=floor[c]+(ceiling[c]-floor[c])*Math.pow(muted/255,1.12);
  });
}
function printCanvas() {
  const canvas=document.createElement('canvas');
  const border=Math.round(graded.width*0.055), bottom=Math.round(graded.width*0.19);
  canvas.width=graded.width+border*2; canvas.height=graded.height+border+bottom;
  const ctx=canvas.getContext('2d');
  ctx.fillStyle='#eeeae0'; ctx.fillRect(0,0,canvas.width,canvas.height);
  ctx.drawImage(graded,border,border);
  return canvas;
}
async function render() {
  const current = ++version;
  if (!base) return;
  const name = $('preset').value, strength = Number($('strength').value)/100;
  const disposable = $('disposable').checked, texture = Number($('texture').value)/100;
  const source = base;
  const print = name==='indoor-print';
  $('printShell').classList.toggle('paper',print);
  const indoor = name==='gmic-px680' || print, tint = indoor ? Number($('tint').value)/100 : 0;
  $('indoorControls').hidden = !indoor;
  $('tintAmount').value = `${Math.round(tint*100)}`;
  $('amount').value = `${Math.round(strength*100)}%`;
  $('label').textContent = `${$('preset').selectedOptions[0].textContent} · ${Math.round(strength*100)}%`;
  if (disposable) $('label').textContent += ` · Film ${Math.round(texture*100)}%`;
  $('textureAmount').value = `${Math.round(texture*100)}%`;
  $('texture').disabled = !disposable;
  $('description').textContent = descriptions[name];
  $('save').disabled = true; $('status').classList.remove('error');
  $('status').textContent = 'Đang áp preset…';
  try {
    const lut = name==='alpine' ? null : await getLut(name);
    if (current !== version) return;
    const started = performance.now();
    const out = new ImageData(new Uint8ClampedArray(source.data), source.width, source.height);
    const rgb = [0,0,0];
    for (let i = 0; i < out.data.length; i += 4) {
      if (name==='alpine') {
        alpineColor(source.data[i],source.data[i+1],source.data[i+2],strength,rgb);
        for(let c=0;c<3;c++) out.data[i+c]=rgb[c];
      } else {
        const input = [source.data[i],source.data[i+1],source.data[i+2]];
        if (indoor) indoorTint(...input,tint,input);
        sampleLut(lut, ...input, rgb);
        for (let c = 0; c < 3; c++) out.data[i+c] = input[c]*(1-strength)+rgb[c]*strength;
      }
    }
    if (print) for(let i=0;i<out.data.length;i+=4) {
      printColor(out.data[i],out.data[i+1],out.data[i+2],rgb);
      for(let c=0;c<3;c++) out.data[i+c]=rgb[c];
    }
    if (disposable) applyDisposable(out, texture, name==='alpine' || indoor);
    gradedCtx.putImageData(out, 0, 0);
    $('status').textContent = 'Sẵn sàng. Kéo thanh Trước / Sau để so sánh.';
    $('metrics').textContent = `${source.width} × ${source.height} px · ${lut?'LUT '+lut.size+'³':'Alpine Vintage'} · ${Math.round(performance.now()-started)} ms (trình duyệt)`;
    $('save').disabled = false;
  } catch (error) { if (current === version) showError(error); }
}
function showError(error) { $('status').textContent = error.message; $('status').classList.add('error'); }
async function setImage(url, name) {
  const currentImage = ++imageVersion;
  ++version; $('save').disabled = true;
  try {
    const img = await imageFrom(url);
    if (currentImage !== imageVersion) return;
    const scale = Math.min(1,1600/Math.max(img.naturalWidth,img.naturalHeight));
    original.width = graded.width = Math.max(1,Math.round(img.naturalWidth*scale));
    original.height = graded.height = Math.max(1,Math.round(img.naturalHeight*scale));
    originalCtx.drawImage(img,0,0,original.width,original.height);
    base = originalCtx.getImageData(0,0,original.width,original.height);
    filename = name;
    await render();
  } catch(error) {if (currentImage === imageVersion) showError(error);}
}
$('file').addEventListener('change', async event => {
  const file = event.target.files[0]; if (!file) return;
  const url = URL.createObjectURL(file);
  await setImage(url, file.name.replace(/\.[^.]+$/, ''));
  URL.revokeObjectURL(url);
});
$('sample').onclick = () => setImage('assets/landscape.webp','landscape');
$('preset').onchange = () => {
  if ($('preset').value==='indoor-print') {
    $('strength').value=88; $('texture').value=100; $('tint').value=19; $('disposable').checked=true;
  } else if ($('preset').value==='gmic-px680') {
    $('strength').value=85; $('texture').value=35; $('disposable').checked=true;
  }
  render();
};
$('disposable').onchange = render;
$('tint').oninput = () => {cancelAnimationFrame(frame); frame = requestAnimationFrame(render);};
$('texture').oninput = () => {cancelAnimationFrame(frame); frame = requestAnimationFrame(render);};
$('strength').oninput = () => {cancelAnimationFrame(frame); frame = requestAnimationFrame(render);};
$('split').oninput = () => {
  const split = Number($('split').value);
  $('overlay').style.clipPath = `inset(0 ${100-split}% 0 0)`;
  $('divider').style.left = `${split}%`;
};
$('save').onclick = () => ($('preset').value==='indoor-print' ? printCanvas() : graded).toBlob(blob => {
  if (!blob) return showError(new Error('Không xuất được ảnh.'));
  const url = URL.createObjectURL(blob), a = document.createElement('a');
  const tintTag = ['gmic-px680','indoor-print'].includes($('preset').value) ? '-tint-'+$('tint').value : '';
  a.href = url; a.download = `${filename}-${$('preset').value}-${$('strength').value}${tintTag}${$('disposable').checked?'-disposable-'+$('texture').value:''}.png`;
  a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
},'image/png');
// Exposed pure functions permit a deterministic identity-LUT verification.
window.filmLab = {sampleLut, haldCubeSize, parseCube, applyDisposable, alpineColor, rgbToHsv, hsvToRgb, indoorTint, printColor};
setImage('assets/landscape.webp','landscape');

if (new URLSearchParams(location.search).get('preset')==='indoor') {
  $('preset').value='gmic-px680'; $('preset').onchange();
}

if (new URLSearchParams(location.search).get('preset')==='print') {
  $('preset').value='indoor-print'; $('preset').onchange();
}
