import {test} from 'node:test'; import assert from 'node:assert/strict'; import {balance,summary,obligationsForMonth,cents} from './finance.mjs'
const a=[{id:'a',opening_cents:100000},{id:'b',opening_cents:0}]
const t=(x)=>({id:'t',kind:'expense',amount_cents:1000,date:'2026-11-05',account_id:'a',status:'received',...x})
test('EUR decimals use cents',()=>assert.equal(cents('12,39'),1239))
test('expected and future income excluded',()=>assert.equal(balance(a,[t({kind:'income',status:'expected'}),t({kind:'income',date:'2026-12-01'})],'2026-11-05'),100000))
test('transfers conserve wealth and move account balances',()=>{const ts=[t({kind:'transfer',to_account_id:'b'})];assert.equal(balance(a,ts,'2026-11-05'),100000);assert.equal(balance(a,ts,'2026-11-05','b'),1000)})
test('inclusive days and reserved savings',()=>{const s=summary(a,[],[],[{reserved_cents:10000}],{},'2026-11-05');assert.equal(s.days,26);assert.equal(s.limit,3461)})
test('paid obligation not deducted twice',()=>{const rules=[{id:'r',starts_on:'2026-01-01',amount_cents:30000}];const ts=[t({obligation_id:'r',obligation_month:'2026-11',amount_cents:30000})];const s=summary(a,ts,rules,[],{},'2026-11-05');assert.equal(s.current,70000);assert.equal(s.unpaid,0);assert.equal(s.spent,0);assert.equal(obligationsForMonth(rules,ts,'2026-12')[0].paid,false)})
test('insufficient funds overrides manual limit',()=>assert.equal(summary(a,[],[{starts_on:'2026-01-01',amount_cents:200000}],[],{manual_limit_cents:900},'2026-11-05').limit,0))
test('month rollover no synthetic double carry',()=>{const ts=[t({date:'2026-10-31'}),t({date:'2026-11-01'})];assert.equal(balance(a,ts,'2026-10-31'),99000);assert.equal(balance(a,ts,'2026-11-30'),98000)})
test('last day and leap day inclusive',()=>{assert.equal(summary(a,[],[],[],{},'2028-02-29').days,1);assert.equal(summary(a,[],[],[],{},'2028-02-01').days,29)})
