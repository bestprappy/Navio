// Design experiment ONLY: manually annotated intent/evidence, not a production parser or semantic model.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
const rows=[];
function classify(q,p){
 if(!p.public||!p.listed||!p.active)return 'reject';
 if(q.country&&!p.countries.includes(q.country))return 'reject';
 if(q.days&&p.days!==q.days)return 'reject';
 if(q.year||q.conflict||q.unresolvedRequired)return 'unresolved';
 if((q.exclude??[]).some(x=>p.concepts.includes(x)))return 'reject';
 if((q.required??[]).some(x=>!p.concepts.includes(x)))return 'reject';
 if((q.any??[]).length&&!q.any.some(x=>p.concepts.includes(x)))return 'reject';
 if(q.weekend&&!p.concepts.includes('weekend'))return 'reject';
 if(q.unknownAccessClaim)return 'unresolved';
 if(q.event==='christmas'){
  const explicit=p.concepts.includes('christmas');
  const dec=p.months.includes(12);
  if(p.months.length&&!dec)return 'reject';
  if(!explicit&&!dec)return 'reject';
  if(!explicit)return 'relevant';
 }
 if(q.event==='new-year'){
  if(!p.concepts.includes('new-year')&&!p.nearNewYear)return 'reject';
  if(!p.concepts.includes('new-year'))return 'relevant';
 }
 return p.evidence==='weak'?'relevant':'matching';
}
const plan=(over={})=>({public:true,listed:true,active:true,countries:['TH'],days:3,concepts:['nature','mountain'],months:[],evidence:'strong',...over});
function check(name,q,p,expected){const actual=classify(q,p);assert.equal(actual,expected,name);rows.push({name,expected,actual});}
const scenic={country:'TH',required:['nature'],examples:['garden','forest','mountain']};
check('Examples: mountain alone satisfies like gardens forests mountains',scenic,plan(),'matching');
check('Examples: forest alone qualifies',scenic,plan({concepts:['nature','forest']}),'matching');
check('Examples: garden alone qualifies',scenic,plan({concepts:['nature','garden']}),'matching');
check('Examples do not exclude another genuine nature category',scenic,plan({concepts:['nature','waterfall']}),'matching');
check('Examples: food city plan cannot qualify',scenic,plan({concepts:['food']}),'reject');
check('Wrong country never rescued by scenery',scenic,plan({countries:['JP']}),'reject');
check('AND requires garden plus mountain',{country:'TH',required:['garden','mountain']},plan(),'reject');
check('AND complete evidence qualifies',{country:'TH',required:['garden','mountain']},plan({concepts:['garden','mountain']}),'matching');
check('OR allows garden',{country:'TH',any:['garden','mountain']},plan({concepts:['garden']}),'matching');
check('NOT rejects scheduled beach',{country:'TH',exclude:['beach']},plan({concepts:['nature','beach']}),'reject');
check('Excluded word in source is not positive evidence',{country:'TH',required:['beach']},plan({concepts:['nature']}),'reject');
check('Christmas explicit affirmative text qualifies',{country:'TH',event:'christmas'},plan({concepts:['christmas']}),'matching');
check('Christmas December alone is Relevant',{country:'TH',event:'christmas'},plan({months:[12]}),'relevant');
check('Christmas February rejects despite keyword',{country:'TH',event:'christmas'},plan({months:[2],concepts:['christmas']}),'reject');
check('Christmas ordinary undated coast rejects',{country:'TH',event:'christmas'},plan({concepts:['beach']}),'reject');
check('Christmas festival requires festival',{country:'TH',event:'christmas',required:['festival']},plan({months:[12]}),'reject');
check('Festival plus December is Relevant',{country:'TH',event:'christmas',required:['festival']},plan({months:[12],concepts:['festival']}),'relevant');
check('Christmas weekend needs weekend evidence',{country:'TH',event:'christmas',weekend:true},plan({months:[12]}),'reject');
check('Christmas weekend plus event text qualifies',{country:'TH',event:'christmas',weekend:true},plan({concepts:['christmas','weekend']}),'matching');
check('No year guess from public date',{country:'TH',event:'christmas',year:2026},plan({months:[12]}),'unresolved');
check('Filter conflict cannot silently choose country',{country:'JP',conflict:true},plan({countries:['JP']}),'unresolved');
check('Duration hard constraint',{country:'TH',days:4},plan(),'reject');
check('Ambiguous Georgia requires interpretation',{unresolvedRequired:true},plan(),'unresolved');
check('Unknown quoted specific term must not vanish',{unresolvedRequired:true},plan(),'unresolved');
check('Wheelchair friendly not inferred from park',{country:'TH',unknownAccessClaim:true},plan(),'unresolved');
check('Old or weak optional text cannot be Matching',scenic,plan({evidence:'weak'}),'relevant');
check('Private never enters candidate index',scenic,plan({public:false}),'reject');
check('Unlisted never enters autocomplete',scenic,plan({listed:false}),'reject');
check('Revoked never survives cached result',scenic,plan({active:false}),'reject');
check('New Year window needs explicit evidence',{country:'TH',event:'new-year'},plan({months:[12]}),'reject');
check('New Year Dec26-Jan7 date evidence Relevant',{country:'TH',event:'new-year'},plan({nearNewYear:true}),'relevant');
// Compare the failure-prone admission policies against the same explicit decision labels.
const evidenceCases=[
 {name:'Christmas coast undated',q:{country:'TH',event:'christmas'},p:plan({concepts:['coast']}),expected:'reject'},
 {name:'Festival no festival evidence',q:{country:'TH',event:'christmas',required:['festival']},p:plan({months:[12]}),expected:'reject'},
 {name:'Nature alternatives one actual mountain',q:scenic,p:plan(),expected:'matching'},
 {name:'Explicit AND incomplete',q:{country:'TH',required:['garden','mountain']},p:plan(),expected:'reject'},
 {name:'Exclusion contradicts plan',q:{country:'TH',exclude:['beach']},p:plan({concepts:['beach']}),expected:'reject'}
];
const comparison=evidenceCases.map(c=>({name:c.name,expected:c.expected,countryOnly:c.p.countries.includes(c.q.country)?'matching':'reject',everyMentionAnd:[...(c.q.required??[]),...(c.q.any??[])].every(x=>c.p.concepts.includes(x))?'matching':'reject',structured:classify(c.q,c.p)}));
assert.ok(comparison.some(c=>c.countryOnly!==c.expected));assert.ok(comparison.some(c=>c.everyMentionAnd!==c.expected));assert.ok(comparison.every(c=>c.structured===c.expected));
// Suggestion policy: preserve intent for rewrites; altered facets require labelled, opt-in changes.
function acceptable(original,candidate){
 const changes=['country','event','days','year','weekend'].filter(k=>JSON.stringify(original[k]??null)!==JSON.stringify(candidate.intent[k]??null));
 for(const key of ['required','exclude'])if(JSON.stringify(original[key]??[])!==JSON.stringify(candidate.intent[key]??[]))changes.push(key);
 return changes.length===0||candidate.kind==='alternative'&&changes.every(k=>candidate.changed.includes(k));
}
const original={country:'TH',event:'christmas',required:[],exclude:[]};
// Minimal composition spike: slot-based phrases, not a universal suffix list or an LLM.
function phrases(q){
 const location=q.country==='TH'?'Thailand':q.country==='JP'?'Japan':null;
 if(!location||q.year||q.unresolvedRequired)return [];
 const result=[];
 if(q.event==='christmas'){
  const lead=q.required?.includes('festival')?'Christmas festival':q.weekend?'Christmas weekend':'Christmas holiday';
  result.push({text:`${lead} trips in ${location}`,kind:'rewrite',intent:q,changed:[]});
  if(!q.required?.length&&!q.weekend){
   result.push({text:`Christmas festival trips in ${location}`,kind:'alternative',intent:{...q,required:['festival']},changed:['required']});
   result.push({text:`Christmas weekend trips in ${location}`,kind:'alternative',intent:{...q,weekend:true},changed:['weekend']});
   result.push({text:`December holidays in ${location}`,kind:'alternative',intent:{...q,event:'december'},changed:['event']});
  }
 }
 return result;
}
const christmasPhrases=phrases(original);assert.equal(christmasPhrases.length,4);
assert.ok(christmasPhrases.every(p=>acceptable(original,p)));
assert.equal(new Set(christmasPhrases.map(p=>p.text)).size,4);
rows.push({name:'Compositional Christmas grammar yields rewrite plus labelled refinements/broadening',expected:true});
const narrowed={...original,required:['festival']};assert.ok(phrases(narrowed).every(p=>acceptable(narrowed,p)));assert.equal(phrases(narrowed).length,1);
rows.push({name:'Festival already required cannot be silently removed to pad suggestions',expected:true});
for(const [name,candidate,expected] of [
 ['Natural reorder preserves Christmas',{intent:original,kind:'rewrite',changed:[]},true],
 ['December silently replaces Christmas',{intent:{...original,event:'december'},kind:'rewrite',changed:[]},false],
 ['December explicit alternative',{intent:{...original,event:'december'},kind:'alternative',changed:['event']},true],
 ['Festival silently added',{intent:{...original,required:['festival']},kind:'rewrite',changed:[]},false],
 ['Festival explicit refinement',{intent:{...original,required:['festival']},kind:'alternative',changed:['required']},true],
 ['Weekend silently added',{intent:{...original,weekend:true},kind:'rewrite',changed:[]},false],
 ['Weekend labelled alternative',{intent:{...original,weekend:true},kind:'alternative',changed:['weekend']},true],
 ['Remove geography silently',{intent:{...original,country:null},kind:'rewrite',changed:[]},false],
 ['Undisclosed removal inside alternative',{intent:{...original,country:null,event:'december'},kind:'alternative',changed:['event']},false]
]){assert.equal(acceptable(original,candidate),expected,name);rows.push({name,expected});}
// Monotonicity/privacy invariants over a small Cartesian evidence grid.
let properties=0;
for(const publicFlag of [false,true])for(const active of [false,true])for(const listed of [false,true])for(const country of ['TH','JP'])for(const days of [2,3,4])for(const concepts of [[],['mountain'],['nature','mountain'],['nature','mountain','beach']]){
 const p=plan({public:publicFlag,active,listed,countries:[country],days,concepts});
 const result=classify(scenic,p);
 if(!publicFlag||!active||!listed||country!=='TH')assert.equal(result,'reject');
 if(classify({...scenic,days:4},p)==='matching')assert.equal(classify(scenic,p),'matching');
 if(classify({...scenic,exclude:['beach']},p)==='matching')assert.equal(result,'matching');
 properties++;
}
await fs.mkdir('output',{recursive:true});
await fs.writeFile('output/smart-search-design-lab-20261103.json',JSON.stringify({scope:'Offline admission/suggestion policy experiment. Inputs manually annotated; does NOT test a natural-language parser, embeddings, UI, database or performance.',cases:rows.length,propertyCombinations:properties,comparison,rows},null,2));
console.log(`PASS ${rows.length} labelled policy cases and ${properties} evidence combinations. Counterexamples reject country-only/every-word admission. Not a production implementation test.`);
