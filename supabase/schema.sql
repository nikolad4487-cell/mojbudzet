-- Initial schema. Apply ONCE to a new dedicated Moj Budžet project.
begin;
create table public.profiles(id uuid primary key default gen_random_uuid(),user_id uuid not null unique references auth.users(id) on delete cascade,first_name text not null default '',last_name text not null default '');
create table public.accounts(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,name text not null check(length(name) between 1 and 150),type text not null,opening_cents bigint not null default 0 check(abs(opening_cents)<=1000000000000),unique(id,user_id));
create table public.categories(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,name text not null check(length(name) between 1 and 100),unique(id,user_id),unique(user_id,name));
create table public.obligations(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,title text not null check(length(title) between 1 and 150),amount_cents bigint not null check(amount_cents>0 and amount_cents<=1000000000000),due_day integer not null check(due_day between 1 and 31),starts_on date not null,ends_on date,account_id uuid not null,unique(id,user_id),foreign key(account_id,user_id) references public.accounts(id,user_id),check(ends_on is null or ends_on>=starts_on));
create table public.transactions(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,title text not null check(length(title) between 1 and 150),amount_cents bigint not null check(amount_cents>0 and amount_cents<=1000000000000),date date not null,kind text not null check(kind in('income','expense','transfer')),status text not null check(status in('expected','received')),account_id uuid not null,to_account_id uuid,category_id uuid,note text not null default '' check(length(note)<=5000),obligation_id uuid,obligation_month text check(obligation_month ~ '^\d{4}-(0[1-9]|1[0-2])$'),foreign key(account_id,user_id) references public.accounts(id,user_id),foreign key(to_account_id,user_id) references public.accounts(id,user_id),foreign key(category_id,user_id) references public.categories(id,user_id),foreign key(obligation_id,user_id) references public.obligations(id,user_id),check((kind='transfer' and to_account_id is not null and to_account_id<>account_id and obligation_id is null) or (kind<>'transfer' and to_account_id is null)),check((obligation_id is null and obligation_month is null) or (obligation_id is not null and obligation_month is not null and kind='expense')),unique(user_id,obligation_id,obligation_month));
create table public.goals(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,title text not null check(length(title) between 1 and 150),target_cents bigint not null check(target_cents>0 and target_cents<=1000000000000),saved_cents bigint not null default 0 check(saved_cents>=0 and saved_cents<=1000000000000),reserved_cents bigint not null default 0 check(reserved_cents>=0 and reserved_cents<=1000000000000));
create table public.plans(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,month text not null check(month ~ '^\d{4}-(0[1-9]|1[0-2])$'),income_cents bigint not null default 0 check(income_cents>=0 and income_cents<=1000000000000),expense_cents bigint not null default 0 check(expense_cents>=0 and expense_cents<=1000000000000),saving_cents bigint not null default 0 check(saving_cents>=0 and saving_cents<=1000000000000),unique(user_id,month));
create table public.settings(id uuid primary key default gen_random_uuid(),user_id uuid not null unique references auth.users(id) on delete cascade,manual_limit_cents bigint check(manual_limit_cents>=0 and manual_limit_cents<=1000000000000),theme text not null default 'light' check(theme in('light','dark')));
create index transactions_user_date on public.transactions(user_id,date);
create index transactions_account_owner on public.transactions(account_id,user_id);
create index transactions_destination_owner on public.transactions(to_account_id,user_id);
create index transactions_category_owner on public.transactions(category_id,user_id);
create index transactions_obligation_owner on public.transactions(obligation_id,user_id);
create index obligations_account_owner on public.obligations(account_id,user_id);
do $$ declare t text; begin foreach t in array array['profiles','accounts','categories','obligations','transactions','goals','plans','settings'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('create policy own_select on public.%I for select to authenticated using ((select auth.uid())=user_id)',t);
 execute format('create policy own_insert on public.%I for insert to authenticated with check ((select auth.uid())=user_id)',t);
 execute format('create policy own_update on public.%I for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id)',t);
 execute format('create policy own_delete on public.%I for delete to authenticated using ((select auth.uid())=user_id)',t);
 execute format('grant select,insert,update,delete on public.%I to authenticated',t);
 execute format('revoke all on public.%I from anon',t);
 execute format('create index on public.%I(user_id)',t);
 execute format('alter publication supabase_realtime add table public.%I',t);
 end loop; end $$;
-- Trigger is internal, never exposed through the Data API.
create schema if not exists private;
revoke all on schema private from public,anon,authenticated;
create function private.initialize_user() returns trigger language plpgsql security definer set search_path='' as $$ begin
 insert into public.profiles(user_id,first_name,last_name) values(new.id,left(coalesce(new.raw_user_meta_data->>'first_name',''),150),left(coalesce(new.raw_user_meta_data->>'last_name',''),150));
 insert into public.settings(user_id) values(new.id);
 insert into public.categories(user_id,name) select new.id,x from unnest(array['Studentski posao','Stipendija','Hrana','Menza','Stanarina','Prijevoz','Pretplate','Ostalo']) x;
 return new; end $$;
revoke all on function private.initialize_user() from public,anon,authenticated;
create trigger initialize_budget after insert on auth.users for each row execute function private.initialize_user();
create function public.pay_obligation(p_id uuid,p_month text,p_request_id uuid) returns uuid language plpgsql security invoker set search_path='' as $$
declare r public.obligations; result uuid; m date; begin
 if auth.uid() is null then raise exception 'Potrebna je prijava'; end if;
 if p_month !~ '^\d{4}-(0[1-9]|1[0-2])$' then raise exception 'Neispravan mjesec'; end if;
 m:=(p_month||'-01')::date;
 select * into r from public.obligations where id=p_id and user_id=auth.uid() for update;
 if not found then raise exception 'Obveza nije dostupna'; end if;
 if m>date_trunc('month',current_date)::date or m<date_trunc('month',r.starts_on)::date or (r.ends_on is not null and m>date_trunc('month',r.ends_on)::date) then raise exception 'Obveza ne vrijedi za odabrani mjesec'; end if;
 select id into result from public.transactions where user_id=auth.uid() and obligation_id=p_id and obligation_month=p_month;
 if found then
 update public.transactions set status='received',amount_cents=r.amount_cents,account_id=r.account_id,date=least(current_date,(m+interval '1 month - 1 day')::date) where id=result and status='expected';
 return result;
 end if;
 insert into public.transactions(id,user_id,title,amount_cents,date,kind,status,account_id,obligation_id,obligation_month)
 values(p_request_id,auth.uid(),r.title,r.amount_cents,least(current_date,(m+interval '1 month - 1 day')::date),'expense','received',r.account_id,p_id,p_month) returning id into result;
 return result;
end $$;
revoke all on function public.pay_obligation(uuid,text,uuid) from public,anon;
grant execute on function public.pay_obligation(uuid,text,uuid) to authenticated;
-- Definer confined to private schema. Public wrapper preserves caller identity.
create function private.delete_user() returns void language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); sid uuid:=(auth.jwt()->>'session_id')::uuid; begin
 if uid is null or sid is null or not exists(select 1 from auth.sessions where id=sid and user_id=uid) then raise exception 'Potrebna je aktivna sesija'; end if;
 -- Remove dependent rows first because account/category composite FKs are restrictive.
 delete from public.transactions where user_id=uid;
 delete from public.obligations where user_id=uid;
 delete from auth.sessions where user_id=uid;
 delete from auth.users where id=uid;
end $$;
revoke all on function private.delete_user() from public,anon;
grant usage on schema private to authenticated;
grant execute on function private.delete_user() to authenticated;
create function public.delete_my_account() returns void language sql security invoker set search_path='' as $$ select private.delete_user() $$;
revoke all on function public.delete_my_account() from public,anon;
grant execute on function public.delete_my_account() to authenticated;
commit;
