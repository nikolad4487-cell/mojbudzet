# Moj Budžet

Osobni planer financija na hrvatskom jeziku. Službeni repozitorij: https://github.com/nikolad4487-cell/mojbudzet.

React, TypeScript, Vite, Tailwind CSS, shadcn-style Button (Radix Slot / CVA), Lucide, Recharts, Supabase Auth/PostgreSQL/Realtime. Svi iznosi su cijeli centi (PostgreSQL bigint), prikaz EUR / hr-HR. Privatni podaci nisu pohranjeni u localStorage; Supabase SDK pohranjuje sesiju.

## Pokretanje

Node 22.12+ ili 24, npm:

```sh
npm ci
cp .env.example .env.local
# Upišite URL i publishable key svog Supabase projekta.
npm run dev
npm test
npm run build
```

Lokalno cloud okruženje blokira mrežne veze. Instalacija i provjere zato su provedene kroz GitHub Actions: `npm ci`, 8 financijskih testova, TypeScript, Vite produkcijska izgradnja, Chromium smoke testovi na 360/768/1440 px i SQL/RLS testovi na izoliranom PostgreSQL-u prolaze. Lockfile iz uspješne izgradnje spremljen je u repozitorij. To ne zamjenjuje provjeru stvarnog Supabase Autha, e-mail dostave i sinkronizacije uređaja.

Audit nakon ažuriranja React Routera i Vitea: 0 high / 0 critical, 2 low / 3 moderate. Preostali nalazi su tranzitivni build alati (`workbox-build`, `glob`, `minimatch`, `deepmerge`, `@rollup/plugin-node-resolve`); izvještaj se sprema kao CI artefakt. Potrebno ih je riješiti prije produkcije kompatibilnim izdanjima i provjeriti ponovnu izgradnju.

## Povezani Supabase projekt

Projekt **MojBudzet**, ref `knxhadgheqybthdfjqrq`, povezan je 6. studenoga 2026. Početna migracija primijenjena je na prethodno praznu shemu `public`. Ime datoteke migracije usklađeno je sa stvarno zabilježenom verzijom `20261106152035` iz Supabase migration historyja. Na ovom projektu nemojte ponovo ručno primijeniti početnu shemu.

Provjera konfiguracije potvrđuje svih osam tablica s uključenim RLS-om, po četiri CRUD pravila i uključivanje u publikaciju `supabase_realtime`. Security advisor nema nalaza. Performance advisor navodi informativne još nekorištene indekse u novoj bazi; nisu uklanjani.

Testna skripta koja privremeno stvara korisnike i izvršava rollback nije izvršena na povezanom projektu: alat je odbio zahtjev za izvršavanje SQL-a, bez dodatnog razloga. Prethodne CI provjere na izoliranom PostgreSQL-u ostaju valjane, ali nisu potvrda stvarne Supabase Auth prijave, e-mail dostave ili sinkronizacije uređaja.

Lokalni `.env.local` postavljen je pomoću URL-a projekta i aktivnog publishable ključa; datoteka je ignorirana u Gitu. Ključ nije spremljen u repozitorij. Za Vercel i druge lokalne kopije postavite obje varijable kroz njihovu konfiguraciju. SMTP, Auth redirectovi i Vercel integracija još nisu konfigurirani kroz ovaj rad.

## Supabase: postavljanje druge prazne baze

Povezani projekti `e-dnevnikskolehrme` i `StudyWorks` nisu mijenjani. Koristite novi ili izričito namijenjeni projekt. Ne upotrebljavajte postojeću bazu s istoimenim tablicama.

1. U SQL Editoru jednom izvršite početnu datoteku u `supabase/migrations/*_initial_budget.sql` (isti sadržaj kao `supabase/schema.sql`). Skripta je transakcijska početna shema; nije idempotentna.
2. Uključite Email provider i **Confirm email**. Postavite produkcijski SMTP; razvojni SMTP ima ograničenja slanja.
3. Auth → URL Configuration: Site URL `https://VAS-PROJEKT.vercel.app`. Dodajte dopuštene redirectove `http://localhost:5173/auth/callback`, `http://localhost:5173/auth/reset`, `https://VAS-PROJEKT.vercel.app/auth/callback`, `https://VAS-PROJEKT.vercel.app/auth/reset`. Dodajte konkretne preview adrese ako testirate preview. Zadržite Supabase predložak s `{{ .ConfirmationURL }}`.
4. API URL i **publishable** ključ upišite u `.env.local` i Vercel. Service-role / secret ključ nikad ne ide u VITE varijable.
5. Na odvojenoj testnoj bazi kao postgres pokrenite `psql "$TEST_DATABASE_URL" -f supabase/tests/security.sql`. Skripta koristi transakciju i rollback.
6. Pokrenite Supabase security/performance advisors u Dashboardu i riješite nalaze prije puštanja korisnicima.

Početni naziv migracije generiran je Supabase CLI-jem 2.81.3 preko `supabase migration new initial_budget` u CI-ju. CI provjerava da shema i migracija imaju jednak sadržaj i primjenjuje migraciju na prazni PostgreSQL. Za povezani Supabase CLI projekt koristite `supabase db push` nakon pregleda `supabase db push --help`; ako ste SQL već ručno primijenili, prvo uskladite migration history prema CLI dokumentaciji. Nemojte istu početnu shemu primijeniti dvaput.

## Vercel

Importirajte postojeći GitHub repozitorij, framework **Vite**, build `npm run build`, output `dist`. Dodajte `VITE_SUPABASE_URL` i `VITE_SUPABASE_PUBLISHABLE_KEY` u Production/Preview prema projektu koji koristite. `vercel.json` podržava izravne poveznice React Routera. Nakon odobrenja i mergea PR-a u `main`, povezana Vercel integracija automatski gradi aplikaciju. Nije potrebno unositi Vercel tokene u kod. Vercel projekt i njegova Git integracija još nisu konfigurirani ovim radom.

## Implementirano

- Registracija s imenom/prezimenom, potvrda lozinke, Supabase sesije, prijava/odjava, slanje potvrde i oporavka, nova lozinka, profil, brisanje korisnika i podataka.
- Vlasnički RLS za sva četiri CRUD postupka na svih osam tablica. Složeni FK-ovi provjeravaju da račun, odredište, kategorija i obveza pripadaju istom korisniku. Definer funkcije imaju prazan search_path i ograničena prava; brisanje provjerava aktivnu auth.sessions sesiju.
- Računi s početnim stanjima, prihodi/rashodi/prijenosi, uređivanje/brisanje transakcija, očekivane transakcije, kategorije i napomene. Budući datumi ne povećavaju današnje stanje.
- Ponavljajuće obveze materijaliziraju se za odabrani mjesec iz pravila. Plaćanje je atomski RPC pod RLS-om, s row lockom i jedinstvenim ključem po obvezi/mjesecu. Plaćena obveza ne rezervira ponovno novac; brisanje rashoda vraća obvezu u neplaćeno stanje.
- Dashboard, automatski/ručni limit, upozorenja 80/100/>100%, inclusive dani, mjesečni pregled, kalendar, godišnji i kategorijski grafovi, štednja, budući mjesečni planovi.
- Stanje se računa iz jedinstvene knjige transakcija do datuma. Nema dodatnih transakcija prijenosa salda koje bi dvostruko povećale stanje.
- Realtime osvježavanje, dohvat nakon reconnecta/fokusa i svakih 60 sekundi, paginirani dohvat, indikator stanja. Offline spremanje onemogućeno. UUID transakcije ostaje isti pri ponovnom pokušaju u otvorenom dijalogu.
- Tamni/svijetli prikaz, mobilna donja navigacija, PWA app-shell, CSV/JSON i ispis u PDF.

## Ograničenja i preostali razvoj

Ovo je početna implementacija, **nije potvrđena produkcijski spremna aplikacija**. Produkcijska izgradnja, Chromium smoke testovi i SQL/RLS testovi prolaze u CI-ju. Stvarni Supabase Auth/e-mail, Realtime između dvaju uređaja i produkcijska Vercel objava još nisu potvrđeni ; projekt je sada povezan, ali preostale integracijske provjere još nisu provedene.

- Povijesni saldo i transakcije su trajni; povijesni dnevni limit u kalendaru ponovno se računa prema današnjim pravilima štednje/limita. Za nepromjenjive povijesne limite treba dodati dnevne snapshotove i verzioniranje pravila.
- Štednja ima trenutačni ostvareni/rezervirani iznos, ali nema knjigu pojedinačnih uplata i mjesečnih snapshotova. Početna stanja računa vrijede od početka knjige; za račune otvorene kasnije treba dodati datum početnog stanja.
- Prvo pokretanje daje upute u tri koraka, a ne zaseban čarobnjak. Kategorije podržavaju dodavanje i brisanje; preimenovanje nije ugrađeno. Obveze se dodaju i brišu, ali UI još nema uređivanje/završetak pravila. Brisanje korištenih računa/kategorija/obveza odbija se radi integriteta podataka.
- PWA koristi SVG ikonu i cache app-shella, bez offline financijskih zapisa ili queuea. Za punu kompatibilnost instalacije dodati PNG 192/512 i maskable ikone te provjeriti Android/iOS.
- PDF je ispis odabranog prikaza; nije zaseban višestranični izvještaj sa svim podacima. JSON je potpuni izvoz dohvaćenih tablica.
- Kod prikazuje dio Supabase poruka grešaka na izvornom jeziku API-ja. Za ujednačen hrvatski UX dodati mapiranje kodova grešaka.
- Supabase/Vercel planovi, SMTP limiti, backupi i kapacitet određuju broj korisnika. Nema umjetnog ograničenja registracija u aplikaciji.

## Obvezna provjera prije produkcije

Pogledajte `TESTING.md`. Posebno provjerite izolaciju dvaju korisnika izravnim REST zahtjevima, linkove e-maila na drugom uređaju, dvije aktivne sesije, ponovljeno plaćanje obveze i brisanje računa. Nemojte objaviti aplikaciju dok CI build i sigurnosne provjere ne prođu.

## Produkcijska objava na povezani Vercel

Namjenski projekt: https://vercel.com/carnet-s-projects/mojbudzet, javna adresa: https://mojbudzet.vercel.app.

U Vercel Settings → Environment Variables postavite `VITE_SUPABASE_URL=https://knxhadgheqybthdfjqrq.supabase.co` i aktivni publishable ključ tog projekta kao `VITE_SUPABASE_PUBLISHABLE_KEY` za Production. Nakon postavljanja varijabli potrebna je nova izgradnja; Vite ih ugrađuje pri izgradnji. Skripta `scripts/check-vercel-env.mjs` odbija Vercel izgradnju bez konfiguracije i odbija secret/service-role ključeve. Vrijednosti ključeva ne zapisuju se u log niti u repozitorij.

U Supabase Auth URL Configuration postavite Site URL `https://mojbudzet.vercel.app` te dopuštene redirectove `https://mojbudzet.vercel.app/auth/callback` i `https://mojbudzet.vercel.app/auth/reset` uz lokalne adrese iz prethodnih uputa. Produkcijska grana Vercela treba biti `main`; merge odobrenog PR-a pokreće povezanu Git integraciju.
