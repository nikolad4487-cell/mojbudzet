# Evidencija provjera

## Izvršeno

`node src/finance.test.mjs`: 8/8 prolazi. Testirano pretvaranje decimala u cente, isključivanje očekivanih/budućih prihoda iz današnjeg salda, prijenos između računa, uključivanje današnjeg dana, rezervirana štednja, izbjegavanje dvostrukog odbijanja plaćene obveze, ponavljanje idućeg mjeseca, nedostatak sredstava uz ručni limit, prijenos salda, kraj mjeseca i prijestupna godina.

`npm test` u GitHub Actionsu: 8/8 prolazi. `npm ci`, TypeScript `tsc --noEmit` i Vite produkcijska izgradnja prolaze. Lokalna mreža nije dopuštala instalaciju, pa je izvršavanje prebačeno u CI; nije zaobiđena mrežna politika.

`supabase/tests/security.sql` na PostgreSQL 17, uz `bootstrap.sql` koji simulira minimalni Supabase Auth ugovor: prolazi. Provjereni su SELECT/UPDATE/DELETE za tuđe retke svih osam tablica, INSERT s tuđim vlasnikom, promjena vlasništva, strani račun/odredište/kategorija i zabranjeni RPC na tuđoj obvezi. Dodatno je provjereno atomsko/idempotentno plaćanje vlastite obveze, uređivanje i brisanje plaćanja. To je provjera stvarnog PostgreSQL RLS mehanizma, ali ne potpuni test servisa Supabase Auth ni PostgREST API-ja.

`npm run test:browser` u Chromiumu: prolazi. Zaštićeni izravni put `/kalendar` bez sesije prikazuje prijavu. Provjereni obrasci registracije i nove lozinke, nedostupna prijava bez konfiguracije, odsutnost vodoravnog prelijevanja na širinama 360/768/1440 px i odsutnost JS grešaka. Screenshotovi obrazaca su CI artefakti. Privatni dashboard nije testiran u pregledniku sa stvarnom prijavom.

Supabase CLI 2.81.3 generirao je početnu migraciju u uspješnom CI izvršavanju. Nakon toga migracija je spremljena u repozitorij; CI provjerava njezinu usklađenost sa shemom.

Audit: 0 visokih/kritičnih nalaza; ostaje 5 niskih/srednjih nalaza u tranzitivnim build alatima. To nije tvrdnja da su sve ovisnosti bez ranjivosti.

## Ručni E2E scenariji nakon konfiguracije

1. Registrirajte A i B; nepotvrđeni korisnik ne ulazi u privatni prostor. Potvrdite A putem e-maila; prijavite se i odjavite. Probajte netočnu lozinku i istekli link.
2. Pošaljite reset, otvorite link, postavite novu lozinku i ponovno se prijavite. Provjerite produkcijske i lokalne redirectove, uključujući drugi preglednik.
3. A doda račun 1000 €, prihod 100 €, očekivani prihod 200 €, rashod 20 € i prijenos 50 € na drugi vlastiti račun. Stvarni saldo = 1080 €; prijenos ne mijenja ukupni saldo.
4. B izravno REST API-jem pokušava dohvatiti, izmijeniti i obrisati A retke; ne smije uspjeti. B pokušava INSERT i UPDATE na A user_id, account_id, to_account_id, category_id i obligation_id; odbijanje je obvezno.
5. U dvije A sesije dodajte/uredite/obrišite transakciju. Drugi uređaj treba osvježiti stanje. Isključite i vratite vezu; indikator i dohvat moraju se oporaviti. Offline submit se odbija.
6. Dodajte obvezu 300 €, platite je istodobno na dva uređaja. Samo jedan rashod; dnevni budžet ne oduzima je ponovno. Sljedeći mjesec obveza je neplaćena. Obrišite plaćanje; ponovo se rezervira obveza.
7. Provjerite zadnji dan mjeseca, 29. veljače, negativni saldo, ručni limit i točno 80/100/>100%. Budući plan ne mijenja današnje stanje.
8. Provjerite kalendar, odabir datuma i unos s tim datumom, uređivanje i brisanje. Provjerite tamni način, širine 360/768/1440 px, tipkovnicu i čitač ekrana.
9. Izvezite CSV s navodnicima, Unicode tekstom i nazivom koji počinje znakom =. Provjerite JSON i ispis u PDF. Instalirajte PWA na podržanom mobitelu.
10. Osvježite izravne `/kalendar`, `/statistika`, `/auth/reset` poveznice na Vercelu. Obrišite testni račun; provjerite sve retke i da stari JWT više ne pristupa podacima.
