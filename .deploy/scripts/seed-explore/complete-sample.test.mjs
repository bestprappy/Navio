import test from 'node:test';
import assert from 'node:assert/strict';
import { completeSample } from './complete-sample.mjs';
import { plans } from './plans.mjs';
const original={blocks:[{id:'day-old',kind:'itinerary',title:'Original day',date:'2027-01-01',colorId:'rose',items:[{id:'place-old',type:'place',placeId:'GOOGLE:real',name:'Existing stop',lat:1,lng:2,notes:'Original owner note',time:'09:00',timeEnd:'10:00'}]}],budget:{currency:'USD',amount:0,expenses:[]},energyState:null};
test('complete source retains itinerary identities and authored content, adds real sections and is repeatable',()=>{
 const source=completeSample(plans[0],original);assert.deepEqual(source.blocks.filter(b=>b.kind==='itinerary'),original.blocks);assert.equal(original.blocks.length,1);
 assert.ok(source.blocks[0].id.startsWith('starting-part-'));assert.match(source.blocks[0].items[0].content,/Chiang Mai/);
 const list=source.blocks.find(b=>b.kind==='list'&&!b.id.startsWith('starting-part-'));assert.deepEqual(list.items.map(i=>i.type),['note','checklist','place']);assert.equal(list.items[2].placeId,'GOOGLE:real');
 assert.deepEqual(completeSample(plans[0],source),source);assert.ok(source.budget.expenses.every(e=>e.label.includes('illustrative')));
});
test('all maintained definitions get starting part and list, Garage only for designated EV examples',()=>{
 for(const plan of plans){const source=completeSample(plan,original);assert.ok(source.blocks.length>=3);assert.ok(source.options.includeStartingPart);assert.equal(source.options.listIds.length,1);assert.equal(Boolean(source.energyState?.vehicles?.length),plan.days.some(day=>day.some(stop=>stop.chargerNear)));}
});
test('existing authored sections, budget, trip energy and publication choices are preserved',()=>{
 const state={...structuredClone(original),blocks:[{id:'starting-part-user',kind:'list',title:'Mine',items:[{id:'note',type:'note',content:'My introduction'}]},...structuredClone(original.blocks)],budget:{currency:'JPY',amount:200,expenses:[{id:'expense',label:'Reserved',amount:200}]},energyState:{initialSocPct:45,vehicleSnapshot:null,garageVehicleIds:[]}};
 const source=completeSample(plans[0],state,{includeDates:false,listIds:['user-list'],excludedVehicleIds:['excluded']});assert.deepEqual(source.blocks[0],state.blocks[0]);assert.deepEqual(source.budget,state.budget);assert.deepEqual(source.energyState,state.energyState);assert.equal(source.options.includeDates,false);assert.ok(source.options.listIds.includes('user-list'));assert.deepEqual(source.options.excludedVehicleIds,['excluded']);
});
