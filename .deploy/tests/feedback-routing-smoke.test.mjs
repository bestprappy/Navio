import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createServer} from 'node:http';
import vm from 'node:vm';
import {test} from 'node:test';
const deployment=await readFile(new URL('../scripts/deploy.sh',import.meta.url),'utf8');
const smoke=[...deployment.matchAll(/compose exec -T navio-web node <<'NODE'\r?\n([\s\S]*?)\r?\nNODE/g)]
  .map(match=>match[1]).find(script=>script.includes('Feedback route check:'));
assert.ok(smoke,'The feedback deployment check must exist.');
async function run({missing=false,empty=false,missingFavorites=false,malformedFavorites=false}={}){
 const calls=[],messages=[];
 const server=createServer((request,response)=>{
  calls.push([request.method,request.url]);response.setHeader('Content-Type','application/json');
  if(request.url.startsWith('/v1/saved-content/favorites?')){
   response.statusCode=missingFavorites?404:200;
   const identity=new URL(request.url,'http://localhost').searchParams.get('identity');
   return response.end(JSON.stringify(malformedFavorites?{}:[{identity,count:0}]));
  }
  if(request.url.startsWith('/v1/shared-plans?'))return response.end(JSON.stringify({content:empty?[]:[{token:'listed-test-token'}]}));
  response.statusCode=request.method==='PUT'||request.url.endsWith('/reports')?401:missing?404:200;
  response.end('{}');
 });
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const process={env:{NAVIO_API_BASE_URL:`http://127.0.0.1:${server.address().port}`},exitCode:0};
 try{await vm.runInNewContext(smoke,{process,fetch,URL,AbortSignal,console:{log:value=>messages.push(value),error:value=>messages.push(value)}});return {calls,messages,exitCode:process.exitCode};}
 finally{await new Promise(resolve=>server.close(resolve));}
}
test('deployment smoke verifies actual public feedback paths and rejected writes',async()=>{
 const result=await run();assert.equal(result.exitCode,0);assert.equal(result.calls.length,6);
 assert.deepEqual(result.calls.at(-1),['PUT','/v1/shared-plans/listed-test-token/feedback/rating']);
 assert.ok(result.messages.some(message=>message.includes('verified')));
});
test('a healthy feed with missing feedback routing fails deployment smoke',async()=>{
 const result=await run({missing:true});assert.equal(result.exitCode,1);assert.match(result.messages.at(-1),/404.*200/);
});
test('an empty catalogue does not cause production data to be seeded',async()=>{
 const result=await run({empty:true});assert.equal(result.exitCode,0);assert.equal(result.calls.length,2);assert.match(result.messages.at(-1),/skipped/);
});


test('production mounted gateway configuration routes the exact Favorites aggregate to IAM',async()=>{
 const config=await readFile(new URL('../config/api-gateway.yml',import.meta.url),'utf8');
 const iam=config.split('- id: user-management-service')[1]?.split('- id:')[0];
 assert.ok(iam,'Production must route to IAM');
 const paths=iam.match(/Path=([^\r\n]+)/)[1].split(',').map(path=>path.trim());
 assert.ok(paths.includes('/v1/saved-content/favorites'),'Production Favorites aggregate route is missing');
 assert.ok(!paths.includes('/v1/saved-content/**'),'Do not expose a new wildcard route');
 const compose=await readFile(new URL('../compose.production.yml',import.meta.url),'utf8');
 assert.match(compose,/SPRING_CLOUD_CONFIG_SERVER_NATIVE_SEARCH_LOCATIONS: file:\/config/);
 assert.match(compose,/\.\/config:\/config:ro/);
});
test('deployment smoke catches a missing Favorites route even when the plan feed works',async()=>{
 const result=await run({missingFavorites:true});
 assert.equal(result.exitCode,1);
 assert.match(result.messages.at(-1),/404.*200/);
});
test('deployment smoke validates Favorites response shape instead of accepting any HTTP200',async()=>{
 const result=await run({malformedFavorites:true});
 assert.equal(result.exitCode,1);
 assert.match(result.messages.at(-1),/Favorites/);
});
test('an empty plan catalogue still checks Favorites without writing any content',async()=>{
 const result=await run({empty:true});
 assert.ok(result.calls.some(([method,url])=>method==='GET'&&url.startsWith('/v1/saved-content/favorites?')));
 assert.ok(result.calls.every(([method])=>method==='GET'));
});
