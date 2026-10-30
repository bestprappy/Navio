import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {sampleCatalogue,completeSample} from './complete-sample.mjs';
import {plans} from './plans.mjs';
test('sample vehicle remains the exact real Navio catalogue specification',()=>{const records=JSON.parse(readFileSync(new URL('../../../server/user-management-service/src/main/resources/vehicles/thailand.json',import.meta.url),'utf8'));assert.deepEqual(sampleCatalogue,records.find(record=>record.id===sampleCatalogue.id));});
for(const slug of ['th-chiang-mai','th-khao-yai-ev'])test(`new maintained ${slug} is published with complete source sections`,()=>{
 const setup=`import assert from 'node:assert/strict';
 let saved;
 globalThis.fetch=async(url,options={})=>{
  const path=new URL(url).pathname,method=options.method??'GET',body=options.body?JSON.parse(options.body):null;
  if(path==='/v1/geo/places/search')return Response.json({items:[{providerPlaceId:'real-place',name:'Real place fixture',location:{lat:18.79,lng:98.98}}]});
  if(path==='/v1/ev/chargers/near')return Response.json({items:[{id:'real-charger',name:'Real charger fixture',status:'AVAILABLE',connectorTypes:['CCS2'],maxKw:50,totalConnectors:2,location:{lat:18.79,lng:98.98}}]});
  if(path==='/v1/trips'&&method==='GET')return Response.json({content:[],totalPages:1});
  if(path==='/v1/trips'&&method==='POST')return Response.json({id:'trip',version:0});
  if(path==='/v1/trips/trip/planner'&&method==='GET')return Response.json({version:0,budget:{currency:'THB',amount:0,expenses:[]},capabilities:['publication-sections-v1','trip-vehicles-v1']});
  if(path==='/v1/trips/trip/planner'&&method==='PUT'){saved=body;assert.ok(body.blocks.some(b=>b.id.startsWith('starting-part-')));assert.ok(body.blocks.some(b=>b.kind==='list'&&b.items.some(i=>i.type==='checklist')));assert.equal(Boolean(body.energyState?.vehicles?.length),${slug.includes('-ev')});return Response.json({version:1});}
  if(path==='/v1/trips/trip/publication'&&method==='PUT'){assert.ok(saved);assert.ok(body.options.includeStartingPart&&body.options.includeBudget&&body.options.includeNotes);assert.equal(body.options.listIds.length,1);assert.equal(body.options.includeGarage,${slug.includes('-ev')});return Response.json({token:'existing-api-generated-token'});}
  throw new Error('Unexpected request '+method+' '+path);
 };`;
 const output=execFileSync(process.execPath,['--import',`data:text/javascript;base64,${Buffer.from(setup).toString('base64')}`,new URL('./seed.mjs',import.meta.url).pathname.replace(/^\/(?=[A-Za-z]:)/,'')],{env:{...process.env,SEED_USER_ID:'0ae736e4-a315-456e-bb2e-7257d419b2d9',ONLY:slug,PAUSE_MS:'0'},encoding:'utf8'});assert.match(output,/"published":1/);
});
test('generated budget uses real backend expense categories',()=>{const source=readFileSync(new URL('../../../server/trip-planning-service/src/main/java/com/navio/tripplanningservice/model/ExpenseCategory.java',import.meta.url),'utf8');const allowed=[...source.matchAll(/\("([a-z-]+)"\)/g)].map(match=>match[1]);for(const expense of completeSample(plans[0],{blocks:[{id:'day',kind:'itinerary',date:'2027-01-01',title:'Day',colorId:'teal',items:[{id:'p',type:'place',placeId:'real',name:'Stop',address:'Address',lat:1,lng:2}]}]}).budget.expenses)assert.ok(allowed.includes(expense.categoryId),expense.categoryId);});
