# monet2010.com — stav obnovy

Obnova archivované Flash verze `monet2010.com` (retrospektiva Clauda Moneta,
Galeries nationales, Grand Palais, 22. 9. 2010 – 24. 1. 2011; studio Les 84
pro RMN a faberNovel).

Poslední aktualizace: 2026-08-31

---

## Jak to spustit

Potřebuješ `pwsh` (PowerShell 7+ — na macOS `brew install powershell/tap/powershell`).

```powershell
./play-monet2010.ps1              # server + Ruffle desktop, ~10 s na Home
./play-monet2010.ps1 -Browser     # jen server, otevři si /fr sám
```

**Ruffle binárka není v repu** (je velká a platformně specifická). Stáhni si
build pro svou platformu z https://github.com/ruffle-rs/ruffle/releases
a rozbal do `monet/ruffle-desktop/`, nebo dej `ruffle` do PATH.
Web build Ruffle (pro prohlížeč) v repu **je**, v `monet2010/ruffle/`.

Výchozí port je 8080. Na macOS a Linuxu porty pod 1024 vyžadují root,
na Windows ne — proto ne 80.

**Pozor u prohlížeče:** nech záložku vepředu. Skrytá záložka škrtí
`requestAnimationFrame` a Ruffle pak běží řádově pomaleji — vypadá to jako
zamrznutí na loaderu, ale není.

---

## Co funguje

Ověřeno nativním Ruffle (`0.6.0-nightly.2026.8.30`), načtení ~12 s, bez chyb:

- splash s výběrem jazyka
- intro animace + loader
- hudba (`lancement du son`)
- header, menu, footer
- **sekce Home** — originální kód i grafika

Trace potvrzující průchod: `swfAddress ====> home/` → `rub ok` →
`sisi la push` → `fin de l'intro on tape le code`.

## Co chybí a proč

| soubor | sekce |
|---|---|
| `lib/galerie_lib_fr.swf` | Galerie |
| `lib/actu_lib_fr.swf` | Actualités |
| `lib/infos_lib_fr.swf` | Infos pratiques |
| `myvoyage_fr.swf` | Le Voyage |
| `/xml/galerie/fr`, `/xml/actu/fr`, `/vote/` | serverové endpointy |
| `*_thumb.jpg`, `*_default.jpg`, `*_hd.jpg` | fotky obrazů (názvy byly v tom XML) |

Tahaly se dynamicky až za běhu, proto je žádný crawler nezachytil.
**Prověřeno a vyčerpáno:** web.archive.org, Common Crawl (10 indexů 2013–2017),
archive.today. Všechny tři mají jen vstupní HTML.

Existují jen francouzské varianty (`_fr`). `/en`, `/es`, `/jp`, `/ch` spadnou
hned na `lib/header_lib_en.swf` a spol.

---

## Nedořešené stopy (blokované firemní sítí Zscaler — zkusit ze soukromého stroje)

1. **`https://monet2010.fr/`** — živá doména se stejným titulkem
   „Exposition Monet 2010 - RMN - Grand Palais - Paris". Neví se, jestli je to
   původní web, mirror, nebo cizí rekonstrukce. **Otestovat, jestli servíruje
   ty chybějící soubory** — kdyby ano, je hotovo:
   `/lib/galerie_lib_fr.swf`, `/lib/actu_lib_fr.swf`, `/lib/infos_lib_fr.swf`,
   `/myvoyage_fr.swf`, `/xml/galerie/fr`
2. **`https://flashmuseum.org/monet-2010/`** — archiv hratelného Flash obsahu.
   Může mít kompletní sadu souborů ke stažení.
3. `https://idarchive.com/project/exhibition-monet-2010/`
4. `https://thefwa.com/cases/monet-2010` — credits
5. `https://www.dandad.org/awards/professional/2011/digital-design/18350/monet-2010/`
   — credits jsou za odkazem „View all credits"
6. `https://www.commarts.com/webpicks/exposition-monet-2010`

**BnF a INA** (francouzský povinný depozit webu) Flash archivovaly, ale
konzultovat se dá jen z terminálů v budově v Paříži.

**Les 84 už neexistuje** — doména `les84.com` je zaparkovaná (Trellian/Above.com,
`103.224.182.x`), archiv z 2021 ukazuje, že ji převzal čínský spamový web.
Kontaktní cesta přes ni je mrtvá. Zbývá RMN (dnes RMN–Grand Palais) a faberNovel.

---

## Technické poznatky z dekompilace

Nástroje: JPEXS ffdec 26.2.1 + portable JRE 21.

- `/_assets/assets.swf` v `[Embed]` metadatech je **authoring-time cesta, ne
  runtime fetch**. Grafika je zabudovaná uvnitř SWF (296 objektů v `index.swf`,
  185 v `home_lib_fr.swf`).
- `Path.getInstance().path` se nikde nenastavuje → zůstává `""`, takže XML
  endpointy jsou root-relativní.
- Jediné absolutní URL v celém webu: `splash.swf` frame129 dělá
  `navigateToURL("http://www.monet2010.com/" + jazyk)`. Kvůli tomu je splash
  jediná část, která potřebuje mapování domény na localhost. Bez admin práv:
  `chrome --host-resolver-rules="MAP monet2010.com 127.0.0.1,..."`.
- Celá aplikace je řízená SWFAddress přes ExternalInterface. `analyseSWFaddress`
  defaultuje na `"home"`, takže prázdná adresa je v pořádku.
- Home si sama vyžádá `myvoyage_fr.swf` (obsahuje upoutávku na Le Voyage).
  Řeší to prázdný validní SWF z `make-stub-swf.ps1`.
- XMP metadata: `Adobe Flash CS4 Professional`, vytvořeno 21.–23. 7. 2010,
  přebuildováno 10. 3. 2011. Jméno autora tam není.

### Co musí splňovat náhradní moduly

| modul | požadavky |
|---|---|
| Voyage | `Loader.content` musí být MovieClip s metodou `startVoyage()`, dispatchuje `VoyageEvent.CLOSE` s `.destination` |
| Infos | třída `InfosManager`; **neregistruje fonty → nejsnazší cíl** |
| Actu | třída `ActuManager` + font `PoliceTexteFiche` (registruje se hned v `initHandler`) |
| Galerie | třída `GalerieManager(xml:XML)` + fonty `ChronicleDisplayItalic`, `ChronicleDisplaySemi`, `DateItalic`; pak načítá `/xml/galerie/fr` |

Prázdný stub stačí jen pro Voyage. Ostatní potřebují skutečné třídy a fonty,
tedy AS3 kompilátor (Apache Flex SDK poběží na už staženém portable JRE).

---

## Soubory v repu

Vše je ve složce `monet/`:

| soubor | co dělá |
|---|---|
| `monet2010/` | stažený archiv (25 souborů) + `ruffle/` web build + `*.orig` zálohy HTML |
| `monet2010/myvoyage_fr.swf` | **náhrada, ne originál** — prázdný stub, aby loader nevisel |
| `serve-monet2010.ps1` | statický server, TcpListener, loguje 404 |
| `play-monet2010.ps1` | spouštěč: server + Ruffle desktop |
| `make-stub-swf.ps1` | generátor minimálního validního SWF |
| `ruffle-desktop/` | *(není v repu — stáhni si sám, viz výše)* |
