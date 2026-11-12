import {createHash} from 'node:crypto';
import {mkdir,readFile,writeFile} from 'node:fs/promises';
import {join} from 'node:path';
/** Temporary maintenance lookup cache. Never stores private trips, credentials or errors. */
export function resolutionCache({directory,requireCached=false,fetchImpl=globalThis.fetch}){
 const stats={hits:0,misses:0};
 return {stats,fetch:async(input,options={})=>{
  const url=new URL(input),method=options.method??'GET';
  if(url.protocol!=='http:'||!['localhost','127.0.0.1','mobility-and-ev-service'].includes(url.hostname)||method!=='GET'||!['/v1/geo/places/search','/v1/ev/chargers/near'].includes(url.pathname))throw Error('Unsupported provider cache request');
  const key=createHash('sha256').update(url.href).digest('hex'),path=join(directory,key+'.json');
  try{const saved=JSON.parse(await readFile(path,'utf8'));const ttl=url.pathname.includes('/ev/')?3600000:86400000;
   if(saved.url===url.href&&Date.now()-saved.savedAt<ttl){stats.hits++;return Response.json(saved.data);}
  }catch(error){if(error.code!=='ENOENT')throw error;}
  if(requireCached)throw Error('Missing current dry-run resolution: '+url.pathname);
  stats.misses++;const response=await fetchImpl(input,options);
  if(response.ok){const data=await response.clone().json();await mkdir(directory,{recursive:true,mode:0o700});await writeFile(path,JSON.stringify({url:url.href,savedAt:Date.now(),data}),{mode:0o600});}
  return response;
 }};
}
