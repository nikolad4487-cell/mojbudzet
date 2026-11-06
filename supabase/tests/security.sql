-- Run with psql as postgres against a disposable migrated Supabase database.
-- Rollback keeps the test isolated. Failures abort with nonzero psql exit status.
\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) values('11111111-1111-4111-8111-111111111111','budget-a@example.invalid'),('22222222-2222-4222-8222-222222222222','budget-b@example.invalid');
insert into public.accounts(id,user_id,name,type) values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111','A','Gotovina'),('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222','B','Gotovina');
insert into public.obligations(id,user_id,title,amount_cents,due_day,starts_on,account_id) values('cccccccc-cccc-4ccc-8ccc-cccccccccccc','22222222-2222-4222-8222-222222222222','B rent',100,1,'2026-01-01','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
insert into public.categories(id,user_id,name) values('dddddddd-dddd-4ddd-8ddd-dddddddddddd','22222222-2222-4222-8222-222222222222','Private');
insert into public.goals(user_id,title,target_cents) values('22222222-2222-4222-8222-222222222222','B goal',100);
insert into public.plans(user_id,month) values('22222222-2222-4222-8222-222222222222','2026-11');
insert into public.transactions(user_id,title,amount_cents,date,kind,status,account_id) values('22222222-2222-4222-8222-222222222222','B expense',100,current_date,'expense','received','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',true);
do $$ declare t text;n integer; begin
 foreach t in array array['profiles','accounts','categories','obligations','transactions','goals','plans','settings'] loop
 execute format('select count(*) from public.%I where user_id<>auth.uid()',t) into n;
 if n<>0 then raise exception 'RLS SELECT failed: %',t; end if;
 execute format('update public.%I set user_id=user_id where user_id<>auth.uid()',t); get diagnostics n=row_count;
 if n<>0 then raise exception 'RLS UPDATE failed: %',t; end if;
 execute format('delete from public.%I where user_id<>auth.uid()',t); get diagnostics n=row_count;
 if n<>0 then raise exception 'RLS DELETE failed: %',t; end if;
 end loop;
 begin insert into public.accounts(user_id,name,type) values('22222222-2222-4222-8222-222222222222','Forbidden','Gotovina'); raise exception 'RLS INSERT failed'; exception when insufficient_privilege then null; end;
 begin update public.accounts set user_id='22222222-2222-4222-8222-222222222222' where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'; raise exception 'RLS ownership UPDATE failed'; exception when insufficient_privilege then null; end;
 update public.accounts set name='Hacked' where id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'; get diagnostics n=row_count; if n<>0 then raise exception 'RLS UPDATE failed'; end if;
 delete from public.accounts where id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'; get diagnostics n=row_count; if n<>0 then raise exception 'RLS DELETE failed'; end if;
 begin insert into public.transactions(user_id,title,amount_cents,date,kind,status,account_id) values(auth.uid(),'Invalid foreign owner',100,current_date,'expense','received','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'); raise exception 'Foreign ownership failed'; exception when foreign_key_violation then null; end;
 begin insert into public.transactions(user_id,title,amount_cents,date,kind,status,account_id,to_account_id) values(auth.uid(),'Foreign destination',100,current_date,'transfer','received','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'); raise exception 'Destination ownership failed'; exception when foreign_key_violation then null; end;
 begin insert into public.transactions(user_id,title,amount_cents,date,kind,status,account_id,category_id) values(auth.uid(),'Foreign category',100,current_date,'expense','received','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd'); raise exception 'Category ownership failed'; exception when foreign_key_violation then null; end;
 begin perform public.pay_obligation('cccccccc-cccc-4ccc-8ccc-cccccccccccc','2026-11',gen_random_uuid()); raise exception 'Foreign RPC permitted'; exception when raise_exception then if sqlerrm='Foreign RPC permitted' then raise; end if; end;
 insert into public.accounts(user_id,name,type) values(auth.uid(),'Allowed','Gotovina');
end $$;
-- Own obligation payment is atomic and idempotent, then becomes unpaid after deletion.
insert into public.obligations(id,user_id,title,amount_cents,due_day,starts_on,account_id) values('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',auth.uid(),'Own rent',30000,1,'2020-01-01','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
do $$ declare first_id uuid; second_id uuid; n integer; begin
 first_id:=public.pay_obligation('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',to_char(current_date,'YYYY-MM'),gen_random_uuid());
 second_id:=public.pay_obligation('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',to_char(current_date,'YYYY-MM'),gen_random_uuid());
 if first_id<>second_id then raise exception 'Payment retry created a duplicate'; end if;
 select count(*) into n from public.transactions where obligation_id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
 if n<>1 then raise exception 'Payment count must be one'; end if;
 update public.transactions set note='Edited',status='expected' where id=first_id;
 perform public.pay_obligation('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',to_char(current_date,'YYYY-MM'),gen_random_uuid());
 select count(*) into n from public.transactions where id=first_id and status='received';
 if n<>1 then raise exception 'Expected payment must become received'; end if;
 delete from public.transactions where id=first_id;
 select count(*) into n from public.transactions where obligation_id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
 if n<>0 then raise exception 'Own DELETE failed'; end if;
 perform public.pay_obligation('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',to_char(current_date,'YYYY-MM'),gen_random_uuid());
end $$;
reset role;
rollback;
