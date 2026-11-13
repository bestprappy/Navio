import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {resolutionCache} from './resolution-cache.mjs';
test('validated geo responses survive another process instance without repeating lookup',async()=>{
 const directory=await mkdtemp(join(tmpdir(),'navio-seed-'));let calls=0;
 try{const a=resolutionCache({directory,fetchImpl:async()=>{calls++;return Response.json({items:[{name:'A'}]});}});const u='http://mobility-and-ev-service:8083/v1/geo/places/search?query=A';await a.fetch(u);const b=resolutionCache({directory,requireCached:true,fetchImpl:async()=>{throw Error('Must not request provider');}});assert.equal((await(await b.fetch(u)).json()).items[0].name,'A');assert.equal(calls,1);assert.equal(b.stats.hits,1);await assert.rejects(b.fetch(u+'B'),/Missing/);}finally{await rm(directory,{recursive:true,force:true});}
});
test('private trip requests and external hosts are refused by the provider cache',async()=>{
 const c=resolutionCache({directory:tmpdir(),fetchImpl:async()=>{throw Error('Unexpected request');}});
 await assert.rejects(c.fetch('http://trip-planning-service:8082/v1/trips'),/Unsupported/);
 await assert.rejects(c.fetch('https://example.com/v1/geo/places/search'),/Unsupported/);
});
