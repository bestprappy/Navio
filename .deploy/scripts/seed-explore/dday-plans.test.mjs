import test from 'node:test';
import assert from 'node:assert/strict';
import {ddayPlans} from './dday-plans.mjs';
import {completeSample} from './complete-sample.mjs';
import {execFileSync} from 'node:child_process';
test('D-Day batch has exactly ten distinct Thai destinations and twenty non-Thai plans',()=>{
 assert.equal(ddayPlans.length,30);const th=ddayPlans.filter(p=>p.destination.endsWith(', Thailand'));assert.equal(th.length,10);assert.equal(new Set(th.map(p=>p.destination)).size,10);assert.equal(new Set(ddayPlans.map(p=>p.title)).size,30);assert.equal(new Set(ddayPlans.map(p=>p.slug)).size,30);
 for(const p of ddayPlans){assert.ok(p.introduction.length>120);assert.equal(new Date(p.startDate+'T00:00:00Z').toISOString().slice(0,10),p.startDate);assert.equal(p.days.length,2);assert.ok(p.sources.length);assert.ok(p.days.every(d=>d.filter(s=>s.q).length===3));assert.ok(p.days.flat().every(s=>s.note.length>25));assert.equal(new Set(p.days.flat().map(s=>s.q?'place:'+s.q:'charger:'+s.chargerNear)).size,p.days.flat().length);const sample=completeSample(p,{blocks:p.days.map((d,n)=>({id:'day-'+n,kind:'itinerary',items:d.filter(s=>s.q).map((s,i)=>({id:'item-'+n+'-'+i,type:'place',name:s.q,notes:s.note,lat:1,lng:1,placeId:'test'+n+i}))}))},{includeDates:true});assert.ok(sample.options.includeStartingPart&&sample.options.includeBudget);}
 assert.equal(ddayPlans.filter(p=>p.days.flat().some(s=>s.chargerNear)).length,2);
});
test('D-Day runner refuses any unresolved stop without creating a trip',()=>{
 const setup=`let calls=0;globalThis.fetch=async(url,options={})=>{const p=new URL(url).pathname;if(p==='/v1/trips'&&options.method==='GET')return Response.json({content:[],totalPages:1});if(p==='/v1/geo/places/search')return Response.json({items:++calls===1?[{providerPlaceId:'destination',name:'Bangkok',location:{lat:13.7,lng:100.5}}]:[]});throw Error('Unexpected write '+p);};await import('./.deploy/scripts/seed-explore/seed.mjs');`;
 assert.throws(()=>execFileSync(process.execPath,['--input-type=module','-e',setup],{cwd:new URL('../../../',import.meta.url),env:{...process.env,SEED_USER_ID:'0ae736e4-a315-456e-bb2e-7257d419b2d9',SEED_BATCH:'dday',ONLY:'dd-bangkok-food',PAUSE_MS:'0'},encoding:'utf8',stdio:'pipe'}),e=>{assert.match(e.stdout,/"failed":1/);assert.match(e.stderr,/required exhibition stop/);assert.doesNotMatch(e.stderr,/Unexpected write/);return true;});
});
test('required-cache mode without a directory refuses to make any request',()=>{
 const setup=`globalThis.fetch=async()=>{throw Error('Unexpected request');};await import('./.deploy/scripts/seed-explore/seed.mjs');`;
 assert.throws(()=>execFileSync(process.execPath,['--input-type=module','-e',setup],{cwd:new URL('../../../',import.meta.url),env:{...process.env,SEED_USER_ID:'0ae736e4-a315-456e-bb2e-7257d419b2d9',SEED_BATCH:'dday',ONLY:'dd-bangkok-food',REQUIRE_CACHED:'1',RESOLUTION_CACHE_DIR:''},encoding:'utf8',stdio:'pipe'}),e=>{assert.match(e.stderr,/REQUIRE_CACHED needs RESOLUTION_CACHE_DIR/);assert.doesNotMatch(e.stderr,/Unexpected request/);return true;});
});
