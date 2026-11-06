import {chromium} from 'playwright'
import {spawn} from 'node:child_process'
import assert from 'node:assert/strict'
import {mkdir} from 'node:fs/promises'
const server=spawn(process.execPath,['node_modules/vite/bin/vite.js','preview','--host','127.0.0.1','--port','4173'],{stdio:'inherit'})
let browser
try {
 for(let i=0;i<60;i++){try{const r=await fetch('http://127.0.0.1:4173');if(r.ok)break}catch{}await new Promise(r=>setTimeout(r,250))}
 browser=await chromium.launch();const page=await browser.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message))
 await mkdir('test-results',{recursive:true})
 for(const [width,height] of [[1440,1000],[360,800],[768,1024]]){
  await page.setViewportSize({width,height});await page.goto('http://127.0.0.1:4173/kalendar');await page.getByRole('heading',{name:'Dobro došli natrag'}).waitFor()
  assert.equal(await page.getByRole('button',{name:'Prijavi se'}).isDisabled(),true)
  assert.ok(await page.getByText('Za povezivanje postavite').isVisible())
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true,`No overflow at ${width}`)
  await page.getByRole('button',{name:'Kreiraj novi račun'}).click();await page.getByLabel('Prezime',{exact:true}).waitFor();assert.equal(await page.getByLabel('Potvrda lozinke').getAttribute('minlength'),'8')
  await page.screenshot({path:`test-results/register-${width}.png`,fullPage:true})
  await page.getByRole('button',{name:'Zaboravljena lozinka?'}).click();await page.getByRole('heading',{name:'Zaboravljena lozinka'}).waitFor()
 }
 await page.goto('http://127.0.0.1:4173/auth/reset');await page.getByRole('heading',{name:'Nova lozinka'}).waitFor()
 assert.deepEqual(errors,[]);console.log('Browser smoke: protected routes, registration/reset forms, disabled unconfigured auth, 3 responsive widths, no JS errors: PASS')
}finally{await browser?.close();server.kill('SIGTERM')}
