// Compose approved game identity in HTML and capture exact Steam canvases.
// Does not generate/retouch the underlying game artwork.
const fs=require('fs'),path=require('path');
const {chromium}=require('playwright');
const root=path.resolve(__dirname,'../..'), out=path.join(root,'docs/steam/package/artwork');
const data=p=>'data:image/png;base64,'+fs.readFileSync(path.join(root,p)).toString('base64');
const logo=data('assets/ui/logo/under_two_skies_logo.png');
const word=data('assets/ui/logo/under_two_skies_wordmark.png');
const island=data('assets/ui/logo/under_two_skies_icon.png');
const crew='data:image/png;base64,'+fs.readFileSync('/Users/lighthouse-control/Desktop/satellite-shadow-site/public/media/crew.png').toString('base64');
const sizes={header:[920,430],small:[462,174],main:[1232,706],vertical:[748,896],library_capsule:[600,900],library_header:[920,430],library_hero:[3840,1240],library_logo:[1280,200]};
(async()=>{
 fs.mkdirSync(out,{recursive:true});
 const browser=await chromium.launch({headless:true});
 for(const [name,[w,h]] of Object.entries(sizes)) {
  const page=await browser.newPage({viewport:{width:w,height:h},deviceScaleFactor:1});
  const transparent=name==='library_logo',small=name==='small',portrait=h>w,hero=name==='library_hero';
  let art=hero?`<img class="hero-scene" src="${crew}">`:transparent?`<img class="word" src="${word}">`:small?`<img class="small-island" src="${island}"><img class="word" src="${word}">`:`<img class="logo" src="${logo}">`;
  const html=`<!doctype html><meta charset="utf-8"><style>*{box-sizing:border-box}body{margin:0;width:${w}px;height:${h}px;overflow:hidden;background:${transparent?'transparent':'#111c26'};position:relative}.facet{position:absolute;inset:0;background:linear-gradient(150deg,#243c44 0%,#111c26 58%,#332a29 100%)}.ridge{position:absolute;inset:0;background:#30403b;clip-path:polygon(0 72%,18% 43%,32% 62%,48% 35%,72% 74%,100% 47%,100% 100%,0 100%);opacity:.37}.ridge.two{background:#0a1420;clip-path:polygon(0 90%,24% 65%,46% 95%,75% 67%,100% 86%,100% 100%,0 100%);opacity:.85}.logo{position:absolute;width:${portrait?'97':'89'}%;height:${portrait?'80':'96'}%;object-fit:contain;left:50%;top:50%;transform:translate(-50%,-50%)}.word{position:absolute;width:${transparent?'100':'96'}%;height:${transparent?'100':'40'}%;object-fit:contain;left:50%;top:${transparent?'50':'66'}%;transform:translate(-50%,-50%)}.small-island{position:absolute;width:49%;height:71%;object-fit:contain;right:24%;top:-16%;opacity:.7}.hero-scene{width:100%;height:100%;object-fit:cover;object-position:50% 62%}.island{position:absolute;object-fit:contain;width:29%;height:76%;left:50%;top:50%;transform:translate(-50%,-50%)}</style>${transparent?'':'<div class="facet"></div><div class="ridge"></div><div class="ridge two"></div>'}${art}`;
  await page.setContent(html);await page.evaluate(()=>Promise.all([...document.images].map(i=>i.decode())));
  await page.screenshot({path:path.join(out,name+'.png'),omitBackground:transparent});
  fs.writeFileSync(path.join(out,name+'.html'),html);await page.close();
 }
 // Review sheet includes actual-size smallest Steam previews.
 const cards=Object.entries(sizes).map(([name,[w,h]])=>`<section><p>${name} · ${w} × ${h}</p><img src="${data('docs/steam/package/artwork/'+name+'.png')}" style="max-width:540px;max-height:340px"></section>`).join('');
 const review=`<!doctype html><meta charset="utf-8"><title>Steam artwork review</title><style>body{background:#0b131c;color:#f4e6cb;font:16px system-ui;margin:32px}h1{font-size:25px}.grid{display:grid;grid-template-columns:1fr 1fr;gap:28px}section{background:#17232d;padding:20px}img{object-fit:contain;max-width:100%}</style><h1>Under Two Skies — Steam artwork candidates</h1><p>Real approved game identity. Review candidates; rights and owner review pending.</p><p>Smallest displays: <img width="120" height="45" src="${data('docs/steam/package/artwork/small.png')}"> <img width="184" height="69" src="${data('docs/steam/package/artwork/small.png')}"></p><div class="grid">${cards}</div>`;
 fs.writeFileSync(path.join(out,'review.html'),review);
 const page=await browser.newPage({viewport:{width:1240,height:900}});await page.setContent(review);await page.screenshot({path:path.join(out,'review.png'),fullPage:true});await browser.close();console.log('Rendered 8 Steam artwork candidates and review sheet.');
})().catch(e=>{console.error(e);process.exit(1)});
