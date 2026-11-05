const { chromium } = require('playwright');
const path=require('path'); const {spawn}=require('child_process');
const ROOT=path.resolve(__dirname,'..');
const SRC='file:///'+path.resolve(ROOT,'src/index.html').replace(/\\/g,'/');
const TL=require(path.join(ROOT,'timeline.json'));
const FFMPEG='C:/Users/paradox/PYthon/lib/site-packages/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe';
(async()=>{
  console.log('step1 launch');
  const b=await chromium.launch({channel:'msedge',headless:true});
  const p=await b.newPage({viewport:{width:1920,height:1080}});
  await p.addInitScript(`window.TIMELINE=${JSON.stringify(TL)};`);
  await p.goto(SRC,{waitUntil:'load'});
  console.log('step2 fonts');
  await p.evaluate(()=>document.fonts.ready.then(()=>1));
  console.log('step3 ffmpeg');
  const ff=spawn(FFMPEG,['-y','-hide_banner','-loglevel','error','-f','image2pipe','-vcodec','mjpeg','-framerate','25','-i','-','-an','-c:v','libx264','-preset','veryfast','-crf','20','-pix_fmt','yuv420p','-r','25',path.join(ROOT,'out','dbg.mp4')]);
  ff.on('error',e=>console.log('ff err',e.message));
  for(let i=0;i<10;i++){
    const buf=await p.screenshot({type:'jpeg',quality:80});
    console.log('frame',i,buf.length,'write',ff.stdin.write(buf));
  }
  console.log('step4 end');
  ff.stdin.end();
  ff.on('close',c=>{console.log('ff close',c); b.close();});
})().catch(e=>console.log('ERR',e.message));
