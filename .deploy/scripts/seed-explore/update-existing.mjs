#!/usr/bin/env node
import {pathToFileURL} from 'node:url';
import {mkdir,writeFile} from 'node:fs/promises';
import {plans} from './plans.mjs';
import {completeSample} from './complete-sample.mjs';
export const TEAM_OWNER='0ae736e4-a315-456e-bb2e-7257d419b2d9';
/** Existing managed samples only. Never creates/deletes a trip or revives a revoked link. */
export async function updateExistingSamples({owner,definitions=plans,call,apply=false,backup}){
 if(owner!==TEAM_OWNER)throw new Error('This update is restricted to the dedicated Navio Team seed account.');
 if(apply&&typeof backup!=='function')throw new Error('A backup destination is required before applying.');
 const owned=[];
 for(let page=0;page<50;page++){
  const result=await call('GET',`/v1/trips?page=${page}&size=100`);
  if(!Array.isArray(result.content))throw new Error('Unexpected owned trip response');
  owned.push(...result.content);const total=result.totalPages??result.page?.totalPages;
  if(!Number.isInteger(total))throw new Error('Missing pagination metadata');
  if(page+1>=total)break;if(page===49)throw new Error('Trip listing limit reached; refusing partial discovery');
 }
 const results=[];
 for(const plan of definitions){
  const matches=owned.filter(trip=>trip.displayName===plan.title);
  if(matches.length!==1){results.push({slug:plan.slug,status:'skipped',reason:matches.length?'Ambiguous title':'Missing maintained sample'});continue;}
  const id=matches[0].id;
  const publication=await call('GET',`/v1/trips/${id}/publication`);
  if(!publication.published||!publication.listedInExplore||publication.authorDisplayName!=='Navio Team'||!publication.token){results.push({slug:plan.slug,status:'skipped',reason:'Not an active listed Navio Team publication'});continue;}
  const planner=await call('GET',`/v1/trips/${id}/planner`);
  if(!planner.capabilities?.includes('publication-sections-v1')||!planner.capabilities.includes('trip-vehicles-v1'))throw new Error('Connected backend lacks complete section support');
  const complete=completeSample(plan,planner,publication.options);
  if(!apply){results.push({slug:plan.slug,status:'ready',tripId:id});continue;}
  await backup({trip:matches[0],planner,publication});
  const saved=await call('PUT',`/v1/trips/${id}/planner`,{version:planner.version,blocks:complete.blocks,budget:complete.budget,energyState:complete.energyState??undefined});
  const published=await call('PUT',`/v1/trips/${id}/publication`,{expectedTripVersion:saved.version,expectedRevision:publication.revision,options:complete.options,listInExplore:true,authorDisplayName:publication.authorDisplayName,title:publication.title??plan.title});
  if(published.token!==publication.token)throw new Error(`Public link changed unexpectedly for ${plan.slug}`);
  const reloaded=await call('GET',`/v1/trips/${id}/planner`);
  const publicPlan=(await call('GET',`/v1/shared-plans/${publication.token}`)).plan;
  const intro=complete.blocks.find(block=>block.id.startsWith('starting-part-'));
  if(!reloaded.blocks.some(block=>block.id===intro.id)||publicPlan?.startingPart?.content!==intro.items.find(item=>item.type==='note').content||!publicPlan.lists?.length||!publicPlan.budget)throw new Error(`Published content verification failed for ${plan.slug}; backup retained.`);
  if(complete.energyState?.vehicles?.length&&complete.options.includeGarage&&!publicPlan.garage?.length)throw new Error(`Garage missing for ${plan.slug}; backup retained.`);
  results.push({slug:plan.slug,status:'updated',tripId:id,token:publication.token});
 }
 return results;
}
async function main(){
 const base=process.env.TRIP_URL??'http://trip-planning-service:8082';
 const url=new URL(base);
 if(!['localhost','127.0.0.1','trip-planning-service'].includes(url.hostname)||url.protocol!=='http:')throw new Error('Use only the trusted private trip-service endpoint; never expose X-User-Id publicly.');
 const apply=process.env.APPLY==='1';
 const selected=(process.env.ONLY??'').split(',').filter(Boolean);
 if(selected.some(slug=>!plans.some(plan=>plan.slug===slug)))throw new Error('Unknown sample slug');
 const directory=process.env.BACKUP_DIR??'./sample-backups';
 const run=new Date().toISOString().replace(/[:.]/g,'-');
 const call=async(method,path,body)=>{const response=await fetch(new URL(path,base),{method,headers:{'X-User-Id':TEAM_OWNER,'Content-Type':'application/json',Accept:'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(30000)});if(!response.ok)throw new Error(`${method} ${path}: HTTP ${response.status}`);return response.json();};
 const results=await updateExistingSamples({owner:TEAM_OWNER,definitions:selected.length?plans.filter(plan=>selected.includes(plan.slug)):plans,call,apply,backup:async data=>{await mkdir(directory,{recursive:true,mode:0o700});await writeFile(`${directory}/${run}-${data.trip.id}.json`,JSON.stringify(data,null,2),{mode:0o600,flag:'wx'});}});
 console.log(JSON.stringify({mode:apply?'apply':'dry-run',results},null,2));
 if(results.some(result=>result.status==='skipped'))process.exitCode=2;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href)main().catch(error=>{console.error(error.message);process.exitCode=1;});
