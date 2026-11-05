-- Run with psql as postgres against a disposable migrated Supabase database.
-- Rollback keeps the test isolated. Failures abort with nonzero psql exit status.
\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) values('11111111-1111-4111-8111-111111111111','budget-a@example.invalid'),('22222222-2222-4222-8222-222222222222','budget-b@example.invalid');
insert into public.accounts(id,user_id,name,type) values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111','A','Gotovina'),('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222','B','Gotovina');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',true);
do $$ declare t text;n integer; begin
 foreach t in array array['profiles','accounts','categories','obligations','transactions','goals','plans','settings'] loop
 execute format('select count(*) from public.%I where user_id<>auth.uid()',t) into n;
 if n<>0 then raise exception 'RLS SELECT failed: %',t; end if;
 end loop;
 begin insert into public.accounts(user_id,name,type) values('22222222-2222-4222-8222-222222222222','Forbidden','Gotovina'); raise exception 'RLS INSERT failed'; exception when insufficient_privilege then null; end;
 begin update public.accounts set user_id='22222222-2222-4222-8222-222222222222' where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'; raise exception 'RLS ownership UPDATE failed'; exception when insufficient_privilege then null; end;
 update public.accounts set name='Hacked' where id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'; get diagnostics n=row_count; if n<>0 then raise exception 'RLS UPDATE failed'; end if;
 delete from public.accounts where id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'; get diagnostics n=row_count; if n<>0 then raise exception 'RLS DELETE failed'; end if;
 begin insert into public.transactions(user_id,title,amount_cents,date,kind,status,account_id) values(auth.uid(),'Invalid foreign owner',100,current_date,'expense','received','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'); raise exception 'Foreign ownership failed'; exception when foreign_key_violation then null; end;
 insert into public.accounts(user_id,name,type) values(auth.uid(),'Allowed','Gotovina');
end $$;
reset role;
rollback;
