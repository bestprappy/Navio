import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {seasonalEventPlans} from './seasonal-events.mjs';
test('fifteen complete varied definitions have explicit valid dates and provenance',()=>{
 assert.equal(seasonalEventPlans.length,15);assert.equal(new Set(seasonalEventPlans.map(p=>p.title)).size,15);
 for(const p of seasonalEventPlans){assert.equal(new Date(p.startDate+'T00:00:00Z').toISOString().slice(0,10),p.startDate);assert.equal(p.publishDates,true);assert.ok(p.days.length>=2);assert.ok(p.days.every(d=>d.filter(s=>s.q).length>=2));assert.ok(p.introduction.length>100);assert.ok(p.sources.every(s=>s.url.startsWith('https://')));}
 for(const theme of ['spring','summer','autumn','winter','halloween','christmas','new year','chinese new year','loy krathong'])assert.ok(seasonalEventPlans.some(p=>p.title.toLowerCase().includes(theme)),theme);
});
test('explicit batch uses per-plan date and publishes complete month/day sections',()=>{
 const setup=`import assert from 'node:assert/strict';let saved;let created;
 globalThis.fetch=async(url,options={})=>{const path=new URL(url).pathname,method=options.method??'GET',body=options.body?JSON.parse(options.body):null;
 if(path==='/v1/geo/places/search')return Response.json({items:[{providerPlaceId:'real-place',name:'Place fixture',location:{lat:35,lng:135}}]});
 if(path==='/v1/trips'&&method==='GET')return Response.json({content:[],totalPages:1});
 if(path==='/v1/trips'&&method==='POST'){created=body;return Response.json({id:'new-trip'});}
 if(path.endsWith('/planner')&&method==='GET')return Response.json({version:1,blocks:[],capabilities:['publication-sections-v1','trip-vehicles-v1']});
 if(path.endsWith('/planner')&&method==='PUT'){saved=body;return Response.json({version:2});}
 if(path.endsWith('/publication')&&method==='PUT'){assert.equal(created.startDate,'2027-04-04');assert.equal(body.options.includeDates,true);assert.equal(body.options.includeStartingPart,true);assert.equal(body.options.includeBudget,true);assert.ok(saved.blocks.some(b=>b.id.startsWith('starting-part-')));assert.ok(saved.blocks.some(b=>b.kind==='list'&&!b.id.startsWith('starting-part-')));return Response.json({token:'published'});}
 throw new Error(method+' '+path);};await import('./.deploy/scripts/seed-explore/seed.mjs');`;
 const result=execFileSync(process.execPath,['--input-type=module','-e',setup],{cwd:new URL('../../../',import.meta.url),env:{...process.env,SEED_USER_ID:'0ae736e4-a315-456e-bb2e-7257d419b2d9',SEED_BATCH:'seasonal-events',ONLY:'se-kyoto-spring',PAUSE_MS:'0'},encoding:'utf8'});
 assert.match(result,/"published":1/);
});

for (const scenario of ['unpublished', 'missing-charger', 'charger-error']) {
 test(`maintained batch refuses ${scenario} instead of silently succeeding`,()=>{
  const setup=`globalThis.fetch=async(url,options={})=>{const path=new URL(url).pathname,method=options.method??'GET';
   if(path==='/v1/trips'&&method==='GET')return Response.json({content:${scenario==='unpublished'?"[{id:'existing',displayName:'Kyoto Spring: Blossoms, Canals and Temple Gardens'}]":"[]"},totalPages:1});
   if(path.endsWith('/publication'))return Response.json({published:false});
   if(path==='/v1/geo/places/search')return Response.json({items:[{providerPlaceId:'real-place',name:'Place fixture',location:{lat:13.75,lng:100.5}}]});
   if(path==='/v1/ev/chargers/near')return ${scenario==='charger-error'?"new Response('provider unavailable',{status:503})":"Response.json({items:[]})"};
   throw new Error('Unexpected write or call '+method+' '+path);};await import('./.deploy/scripts/seed-explore/seed.mjs');`;
  assert.throws(()=>execFileSync(process.execPath,['--input-type=module','-e',setup],{cwd:new URL('../../../',import.meta.url),env:{...process.env,SEED_USER_ID:'0ae736e4-a315-456e-bb2e-7257d419b2d9',SEED_BATCH:'seasonal-events',ONLY:scenario==='unpublished'?'se-kyoto-spring':'ev-bangkok-new-year',PAUSE_MS:'0'},encoding:'utf8',stdio:'pipe'}),error=>{assert.match(error.stdout,/"failed":1/);assert.doesNotMatch(error.stderr,/Unexpected write/);return true;});
 });
}
