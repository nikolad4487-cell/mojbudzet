-- CI-only Auth contract for testing PostgreSQL RLS, not a replacement for Supabase Auth E2E.
create role anon nologin;
create role authenticated nologin;
create schema auth;
create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb);
create table auth.sessions(id uuid primary key,user_id uuid references auth.users(id) on delete cascade);
create function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
create function auth.uid() returns uuid language sql stable as $$ select (auth.jwt()->>'sub')::uuid $$;
grant usage on schema auth to authenticated,anon;
grant execute on function auth.jwt(),auth.uid() to authenticated,anon;
create publication supabase_realtime;
