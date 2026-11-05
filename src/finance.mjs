export const money = n => new Intl.NumberFormat('hr-HR',{style:'currency',currency:'EUR'}).format(n/100)
export const dateKey = (d = new Date()) => `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`
export function cents(value) { const n=Number(String(value).replace(',','.')); if(!Number.isFinite(n)||Math.abs(n)>1e10) throw Error('Neispravan iznos'); return Math.round(n*100) }
export function balance(accounts, transactions, through, accountId) {
 return accounts.filter(a=>!accountId||a.id===accountId).reduce((s,a)=>s+Number(a.opening_cents),0)+transactions.filter(t=>t.status==='received'&&t.date<=through).reduce((s,t)=>{
 if(t.kind==='transfer') return s+(accountId?(t.to_account_id===accountId?t.amount_cents:0)-(t.account_id===accountId?t.amount_cents:0):0)
 return s+(!accountId||t.account_id===accountId?(t.kind==='income'?1:-1)*t.amount_cents:0)
 },0)
}
export function obligationsForMonth(rules, transactions, month) {
 return rules.filter(r=>r.starts_on.slice(0,7)<=month&&(!r.ends_on||r.ends_on.slice(0,7)>=month)).map(r=>({...r,paid:transactions.some(t=>t.obligation_id===r.id&&t.obligation_month===month&&t.status==='received')}))
}
export function summary(accounts, transactions, rules, goals, settings, day=dateKey()) {
 const month=day.slice(0,7), d=new Date(day+'T12:00:00'), days=new Date(d.getFullYear(),d.getMonth()+1,0).getDate()-d.getDate()+1
 const current=balance(accounts,transactions,day), unpaid=obligationsForMonth(rules,transactions,month).filter(r=>!r.paid).reduce((s,r)=>s+r.amount_cents,0)
 const reserved=goals.reduce((s,g)=>s+g.reserved_cents,0), available=current-unpaid-reserved
 const limit=available<=0?0:settings.manual_limit_cents??Math.floor(available/days)
 const spent=transactions.filter(t=>t.date===day&&t.kind==='expense'&&t.status==='received'&&!t.obligation_id).reduce((s,t)=>s+t.amount_cents,0)
 return {current,unpaid,reserved,available,days,limit,spent,remaining:limit-spent}
}
