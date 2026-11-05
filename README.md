# Moj Budžet

Osobni planer financija na hrvatskom jeziku. Službeni repozitorij: https://github.com/nikolad4487-cell/mojbudzet.

React, TypeScript, Vite, Tailwind CSS, shadcn-style Button (Radix Slot / CVA), Lucide, Recharts, Supabase Auth/PostgreSQL/Realtime. Svi iznosi su cijeli centi (PostgreSQL bigint), prikaz EUR / hr-HR. Privatni podaci nisu pohranjeni u localStorage; Supabase SDK pohranjuje sesiju.

## Pokretanje

Node 22.12+ ili 24, npm:

```sh
npm install
cp .env.example .env.local
# Upišite URL i publishable key svog Supabase projekta.
npm run dev
npm test
npm run build
```

Instalacija u izvornom cloud okruženju blokirana je mrežnim proxyjem. Stoga lockfile i produkcijska izgradnja nisu lokalno potvrđeni. GitHub Actions instalira pakete, provjerava testove i build te objavljuje artefakt s lockfileom i distom; prije produkcije preuzmite i commitajte lockfile te zamijenite `npm install` s `npm ci` u CI-ju. Nemojte smatrati prolazak financijskih unit testova dokazom da Auth, RLS ili cijela aplikacija rade.

## Supabase: novi zasebni projekt

Povezani projekti `e-dnevnikskolehrme` i `StudyWorks` nisu mijenjani. Koristite novi ili izričito namijenjeni projekt. Ne upotrebljavajte postojeću bazu s istoimenim tablicama.

1. U SQL Editoru jednom izvršite `supabase/schema.sql`. Skripta je transakcijska početna shema; nije idempotentna.
2. Uključite Email provider i **Confirm email**. Postavite produkcijski SMTP; razvojni SMTP ima ograničenja slanja.
3. Auth → URL Configuration: Site URL `https://VAS-PROJEKT.vercel.app`. Dodajte dopuštene redirectove `http://localhost:5173/auth/callback`, `http://localhost:5173/auth/reset`, `https://VAS-PROJEKT.vercel.app/auth/callback`, `https://VAS-PROJEKT.vercel.app/auth/reset`. Dodajte konkretne preview adrese ako testirate preview. Zadržite Supabase predložak s `{{ .ConfirmationURL }}`.
4. API URL i **publishable** ključ upišite u `.env.local` i Vercel. Service-role / secret ključ nikad ne ide u VITE varijable.
5. Na odvojenoj testnoj bazi kao postgres pokrenite `psql "$TEST_DATABASE_URL" -f supabase/tests/security.sql`. Skripta koristi transakciju i rollback.
6. Pokrenite Supabase security/performance advisors u Dashboardu i riješite nalaze prije puštanja korisnicima.

CLI nije dostupan u početnom okruženju. Kada postane dostupan, provjerite `supabase --help`, inicijalizirajte lokalni projekt, generirajte početnu migraciju naredbom `supabase migration new initial_budget` i kopirajte `schema.sql` u generiranu datoteku. Provjerite migraciju na praznoj lokalnoj bazi prije povezivanja s produkcijom. Namjerno nije izmišljen naziv CLI migracije niti primijenjena shema na nepovezani projekt.

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

Ovo je početna implementacija, **nije potvrđena produkcijski spremna aplikacija**. Nisu izvršeni browser/E2E testovi, SQL/RLS testovi ni produkcijska izgradnja zbog nedostupnih paketa i neodabranog Supabase projekta.

- Povijesni saldo i transakcije su trajni; povijesni dnevni limit u kalendaru ponovno se računa prema današnjim pravilima štednje/limita. Za nepromjenjive povijesne limite treba dodati dnevne snapshotove i verzioniranje pravila.
- Štednja ima trenutačni ostvareni/rezervirani iznos, ali nema knjigu pojedinačnih uplata i mjesečnih snapshotova. Početna stanja računa vrijede od početka knjige; za račune otvorene kasnije treba dodati datum početnog stanja.
- Prvo pokretanje daje upute u tri koraka, a ne zaseban čarobnjak. Kategorije podržavaju dodavanje i brisanje; preimenovanje nije ugrađeno. Obveze se dodaju i brišu, ali UI još nema uređivanje/završetak pravila. Brisanje korištenih računa/kategorija/obveza odbija se radi integriteta podataka.
- PWA koristi SVG ikonu i cache app-shella, bez offline financijskih zapisa ili queuea. Za punu kompatibilnost instalacije dodati PNG 192/512 i maskable ikone te provjeriti Android/iOS.
- PDF je ispis odabranog prikaza; nije zaseban višestranični izvještaj sa svim podacima. JSON je potpuni izvoz dohvaćenih tablica.
- Kod prikazuje dio Supabase poruka grešaka na izvornom jeziku API-ja. Za ujednačen hrvatski UX dodati mapiranje kodova grešaka.
- Supabase/Vercel planovi, SMTP limiti, backupi i kapacitet određuju broj korisnika. Nema umjetnog ograničenja registracija u aplikaciji.

## Obvezna provjera prije produkcije

Pogledajte `TESTING.md`. Posebno provjerite izolaciju dvaju korisnika izravnim REST zahtjevima, linkove e-maila na drugom uređaju, dvije aktivne sesije, ponovljeno plaćanje obveze i brisanje računa. Nemojte objaviti aplikaciju dok CI build i sigurnosne provjere ne prođu.
