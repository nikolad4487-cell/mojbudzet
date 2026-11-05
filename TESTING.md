# Evidencija provjera

## Izvršeno

`node src/finance.test.mjs`: 8/8 prolazi. Testirano pretvaranje decimala u cente, isključivanje očekivanih/budućih prihoda iz današnjeg salda, prijenos između računa, uključivanje današnjeg dana, rezervirana štednja, izbjegavanje dvostrukog odbijanja plaćene obveze, ponavljanje idućeg mjeseca, nedostatak sredstava uz ručni limit, prijenos salda, kraj mjeseca i prijestupna godina.

`npm test`: prolazi, ali runner ovog okruženja sažima datoteku kao jedan test; izravni poziv potvrđuje osam zasebnih slučajeva.

`npm run build`: pokušano; ne prolazi jer `tsc` nije instaliran. `npm install` blokiran mrežnim proxyjem (EPERM / connect failed). TypeScript i izvršavanje UI-ja nisu potvrđeni. CI workflow je pripremljen, rezultati nisu unaprijed proglašeni prolaznim.

## Pripremljeno, nije izvršeno

`supabase/tests/security.sql`: dva sintetička korisnika, SELECT svih privatnih tablica, zabrana tuđeg INSERT-a, zabrana promjene vlasnika, tuđi UPDATE/DELETE ne mijenjaju retke, zabrana stranog računa i dopušten vlastiti INSERT. Nema dostupnog psql/Supabase CLI-ja ni odabranog testnog projekta. Potrebno proširiti testove na sve FK-ove i CRUD slučajeve svake tablice.

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
