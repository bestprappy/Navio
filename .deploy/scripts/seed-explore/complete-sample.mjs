import { randomUUID } from 'node:crypto';
// Pinned Navio catalogue record, checked against the service catalogue in tests.
const catalog={id:'th-byd-atto-3-extended-2026',make:'BYD',model:'ATTO 3',trim:'Extended',year:2026,market:'TH',batteryCapacityKwh:60.48,batteryCapacityBasis:'MANUFACTURER_DECLARED',rangeKm:480,rangeStandard:'NEDC',connectorTypes:['TYPE2','CCS2'],maxAcKw:7,maxDcKw:88,imageUrl:'/images/vehicles/byd-atto-3.png',sourceUrl:'https://www.reverautomotive.com/media/models/new-atto3/brochure/bydatto3_MY2026.pdf',verifiedAt:'2026-09-12'};
export const sampleCatalogue=Object.freeze(catalog);
const marker='navio-sample-';
const display = value => String(value??'').replace(/[\r\n]/g,' ').replace(/[\[\]<>]/g,'').trim();
function exampleEnergy(){
 const id=randomUUID(),now=new Date().toISOString();
 const profile={version:1,modelKind:'RATED_RANGE',selectionMode:'CATALOG_DEFAULT',consumptionKwhPer100km:null,consumptionSource:'UNKNOWN',consumptionMeasurementBasis:'UNKNOWN',consumptionStandard:'NONE',sourceUrl:null,usableBatteryCapacityKwh:null,capacityBasis:'MANUFACTURER_DECLARED_UNSPECIFIED',ratedRangeKm:catalog.rangeKm,ratedRangeStandard:catalog.rangeStandard};
 const vehicle={id,nickname:'Example trip EV',make:catalog.make,model:catalog.model,year:catalog.year,batteryCapacityKwh:catalog.batteryCapacityKwh,rangeKm:catalog.rangeKm,consumptionKwhPer100km:null,connectorTypes:[...catalog.connectorTypes],isDefault:false,createdAt:now,updatedAt:now,settings:{maxAcKw:catalog.maxAcKw,maxDcKw:catalog.maxDcKw,startingBatteryPct:80,imageUrl:catalog.imageUrl},catalog:structuredClone(catalog),energyProfile:profile};
 return {initialSocPct:80,garageVehicleIds:[id],vehicles:[{scope:'trip',vehicle}],vehicleSnapshot:{version:1,vehicleId:id,label:'Example trip EV',profile,maxAcKw:catalog.maxAcKw,maxDcKw:catalog.maxDcKw,connectorTypes:[...catalog.connectorTypes],legacyConsumptionConfirmed:false}};
}
function exampleBudget(plan){
 const destination=plan.destination.toLowerCase();
 const [currency,daily]=destination.includes('thailand')?['THB',1800]:destination.includes('japan')?['JPY',15000]:destination.includes('taiwan')?['TWD',4000]:['USD',150];
 const amount=daily*plan.days.length;
 return {currency,amount,expenses:[{id:`${marker}${plan.slug}-food`,label:'Food allowance (illustrative)',categoryId:'food',amount:amount*.4},{id:`${marker}${plan.slug}-transport`,label:'Transport allowance (illustrative)',categoryId:'transport',amount:amount*.3},{id:`${marker}${plan.slug}-activities`,label:'Activities allowance (illustrative)',categoryId:'activities',amount:amount*.3}]};
}
/** Merge complete sample content without replacing existing authored itinerary, IDs or settings. */
export function completeSample(plan,planner,options={}){
 const source=structuredClone(planner),blocks=source.blocks??[];
 const days=blocks.filter(block=>block.kind==='itinerary');
 const places=days.flatMap(day=>day.items??[]).filter(item=>item.type==='place'&&!item.evCharger);
 const first=places[0];
 if(!first)throw new Error(`No located itinerary place in ${plan.slug}; refusing to enrich an empty sample.`);
 const prefix=`${marker}${plan.slug}`,date=days[0]?.date??null;
 if(!blocks.some(block=>block.id.startsWith('starting-part-'))){
  const tips=plan.days.flat().filter(stop=>!stop.chargerNear&&stop.note).map(stop=>display(stop.note)).slice(0,3);
  const itinerary=places.map(place=>display(place.name));
  const content=[`Explore ${display(plan.destination)} with this ${days.length}-day outline. The route brings together ${itinerary.slice(0,3).join(', ')}${itinerary.length>3?' and more':''}, with time to adjust the plan to your own pace.`,`## Before you go`,...tips.map(tip=>`- ${tip}`),'','## Make the trip yours','The times are a suggested outline. Confirm current opening hours, reservations and transport before travelling, and leave room for breaks.','',...(plan.days.some(day=>day.some(stop=>stop.chargerNear))?['The Garage contains an example Navio catalogue EV setup. Confirm the actual vehicle, connector compatibility and live charging availability before using it.','']:[]),'The budget is an illustrative planning allowance, not quoted local prices. Edit it for your own trip.','',`[Planning help](/help)`].join('\n\n');
  blocks.unshift({id:`starting-part-${prefix}`,kind:'list',title:`Before exploring ${display(plan.destination).split(',')[0]}`,date,colorId:'teal',items:[{id:`${prefix}-introduction`,type:'note',content}]});
 }
 const listId=`${prefix}-ideas`;
 if(!blocks.some(block=>block.id===listId)){
  const saved=structuredClone(first);saved.id=`${prefix}-saved-place`;delete saved.time;delete saved.timeEnd;delete saved.schedule;delete saved.arrivalMode;delete saved.arrivalRouteKey;saved.isVisited=false;
  saved.notes=[saved.notes,'Saved reference from this itinerary; add another visit only if you want one.'].filter(Boolean).join('\n\n');
  const list={id:listId,kind:'list',title:`Notes and saved ideas - ${display(plan.destination).split(',')[0]}`,date,colorId:'cyan',items:[{id:`${prefix}-list-note`,type:'note',content:`## Keep a little room in the plan\n\nUse this list for arrangements and optional ideas. The saved reference below is already part of the itinerary.\n\n${display(first.notes)||'Review the stop notes before setting out.'}`},{id:`${prefix}-checklist`,type:'checklist',title:'Before setting out',items:['Check current opening times and any booking requirements','Review transport between the stops','Adjust the dates, pace and illustrative budget'].map((label,index)=>({id:`${prefix}-check-${index}`,label,checked:false}))},saved]};
  const startIndex=blocks.findIndex(block=>block.id.startsWith('starting-part-'));blocks.splice(startIndex+1,0,list);
 }
 const isEv=plan.days.some(day=>day.some(stop=>stop.chargerNear));
 if(isEv&&!source.energyState?.vehicles?.length&&!source.energyState?.vehicleSnapshot)source.energyState=exampleEnergy();
 if(!source.budget?.expenses?.length&&!source.budget?.amount)source.budget=exampleBudget(plan);
 const selectedLists=[...new Set([...(options.listIds??[]),listId])];
 source.blocks=blocks;
 source.options={...options,includeDates:options.includeDates??false,includeNotes:true,includeBudget:true,includeStartingPart:true,includeGarage:isEv||options.includeGarage===true,listIds:selectedLists,excludedVehicleIds:options.excludedVehicleIds??[],confirmedCustomVehicleIds:options.confirmedCustomVehicleIds??[]};
 return source;
}
