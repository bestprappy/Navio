import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createServer} from 'node:http';
import vm from 'node:vm';
import {test} from 'node:test';
const deployment=await readFile(new URL('../scripts/deploy.sh',import.meta.url),'utf8');
const smoke=[...deployment.matchAll(/compose exec -T navio-web node <<'NODE'\r?\n([\s\S]*?)\r?\nNODE/g)]
  .map(match=>match[1]).find(script=>script.includes('Feedback route check:'));
assert.ok(smoke,'The feedback deployment check must exist.');
async function run({missing=false,empty=false}={}){
 const calls=[],messages=[];
 const server=createServer((request,response)=>{
  calls.push([request.method,request.url]);response.setHeader('Content-Type','application/json');
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
 const result=await run();assert.equal(result.exitCode,0);assert.equal(result.calls.length,5);
 assert.deepEqual(result.calls.at(-1),['PUT','/v1/shared-plans/listed-test-token/feedback/rating']);
 assert.ok(result.messages.some(message=>message.includes('verified')));
});
test('a healthy feed with missing feedback routing fails deployment smoke',async()=>{
 const result=await run({missing:true});assert.equal(result.exitCode,1);assert.match(result.messages.at(-1),/404.*200/);
});
test('an empty catalogue does not cause production data to be seeded',async()=>{
 const result=await run({empty:true});assert.equal(result.exitCode,0);assert.equal(result.calls.length,1);assert.match(result.messages.at(-1),/skipped/);
});
