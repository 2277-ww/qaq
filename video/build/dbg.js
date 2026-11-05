const { chromium } = require('playwright');
const path=require('path');
const ROOT=path.resolve(__dirname,'..');
const SRC='file:///'+path.resolve(ROOT,'src/index.html').replace(/\\/g,'/');
const TL=require(path.join(ROOT,'timeline.json'));
(async()=>{
  const b=await chromium.launch({channel:'msedge',headless:true});
  const p=await b.newPage({viewport:{width:1920,height:1080}});
  p.on('pageerror',e=>console.log('PAGEERROR',e.message));
  p.on('console',m=>{ if(m.type()==='error') console.log('CONSOLE',m.text()); });
  await p.addInitScript(`window.TIMELINE=${JSON.stringify(TL)};`);
  await p.goto(SRC,{waitUntil:'load'});
  console.log('loaded', await p.evaluate(()=>typeof window.__render));
  for(const t of [0,1000,6000,20000,60000,150000]){
    try{ await p.evaluate(ms=>window.__render(ms), t); console.log('render ok', t); }
    catch(e){ console.log('render fail', t, e.message.split('\n')[0]); }
  }
  const s=await p.screenshot({type:'jpeg',quality:80});
  console.log('shot bytes', s.length);
  await b.close();
})().catch(e=>console.log('ERR',e.message));
