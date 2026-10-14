# Datacenterplaner i Sverige, Norge och Finland

Projektregister med villkorade scenarier. Alla projekt och kandidater finns i varje scenarios översikt, också när effekt eller datum saknas. Okänd effekt är okänd, inte noll. Resultat och begränsningar redovisas i chatten.

## Det du underhåller

| Fil | Innehåll |
| --- | --- |
| `data/projects.csv` | Projekt, kandidater, identitet, land/elområde, län/region, typ och status. 15 kolumner. |
| `data/capacity.csv` | Källornas kapacitetsuppgifter, mått, datum och samband. 21 kolumner. |
| `data/sources.csv` | Källor, korta utdrag, datum och hänvisningar. 9 kolumner. |
| `config/pipeline.json` | Scenarier, beräkningsantaganden och deras källor/tillämpningsgränser. |

Tre tabeller, sammanlagt 45 kolumner. Inga separata granskningsregister eller lokala arkivkopior. Git håller historiken. Uppdatera tabellerna som en sammanhängande ändring, med en uppdaterare i taget.

`scripts/model.R` räknar och kontrollerar; `scripts/tracker.R` skriver den publika trackerns filer; `scripts/pipeline.R` är ingången. `tests/method.R` testar beteendet med syntetiska projekt. `prompts/update.md` styr landsuppdateringen. Sju kartfiler täcker tio elområden.

## Metod

### Kapacitet, infasning och energi

Redovisa tre saker tillsammans:

1. **Nameplate / annonserad kapacitetsram, MW** (`nameplate_mw_low/high`): hela den kända, odaterade ramen för tillkommande anläggningskapacitet, efter hantering av överlapp och befintlig drift. Samma inventering visas bredvid varje scenario; den är ingen extra scenariofamilj.
2. **Infasad kapacitet vid målåret, MW** (`mw_low/high`): den del av ramen som scenariots urval och tidsantaganden tar i bruk. Detta är kapacitet inklusive kylning och övrig hjälplast, inte faktisk eller uppmätt topplast.
3. **Årsenergi vid denna utbyggnadsnivå, TWh** (`annual_twh_low/high`): infasad kapacitet gånger årlig användningsfaktor och 8 760 timmar. En årsekvivalent, inte exakt förbrukning under driftsättningsåret.

Källans MW, definition, datum och status bevaras separat. [EPRI:s måttdefinitioner](https://powering-intelligence.epri.com/understanding-metrics.html) skiljer IT-kapacitet, total anläggningskapacitet, aktiv kapacitet och faktisk topp. Dessa är inte utbytbara.

| Källmått | Tillämpning i modellen |
| --- | --- |
| IT-effekt | Omräkning till anläggningssidan med PUE 1,1–1,5 som känslighetsfall. Lokal design-PUE ersätter det övre fallet. |
| Anläggningskapacitet | Behåll angivet MW-tal. |
| Nätanslutning | Behåll ramen och märk antagandet att den används till datacenter. En ansökan är inte en beviljad anslutning eller faktisk last. |
| Ospecificerat datacenter-MW | Intervall mellan två läsningar: MW×1 som anläggnings-/nätsida (nedre) och MW×PUE som nominell IT-effekt (övre). EPRI 2026, s. 10–11, anger att nominell IT-effekt typiskt är det som annonseras; nordiska källor anger ofta "power". Klassas om efter ordalydelse vid varje körning (`prompts/update.md`). Den publika trackern använder den nedre läsningen. |
| Explicit toppeffekt | Bevara toppvärdet. För kapacitetsjämförelsen används ett uttryckligt känslighetsfall: topp / 0,80 till topp / 0,62. Årsenergi beräknas direkt från ursprunglig topp. |
| Reservkraft, generation, rackdensitet | Behåll observationen utan automatisk omräkning till datacenterlast. En publicerad, motiverad skattning av datacenterlast kan registreras som egen kapacitetsuppgift med källa. |

PUE-fallen och energi-/toppfaktorerna kommer från [EPRI:s energianalys, 2026](https://powering-intelligence.epri.com/annual-peak-use.html). PUE 1,5 är inte ett absolut tak. Att invertera toppfaktorn är vår tillämpning av källans observerade samband, inte en uppgift om projektets verkliga nameplate. Intervallen är känslighetsfall, inte konfidensintervall. `at_least` utan belagd övre gräns behåller okänd övre effekt; `up_to` är en annonserad ram.

### Befintliga scenarier

| Scenario | ID | Urval |
| --- | --- | --- |
| Low 2030 | `low_2030` | Beslutad kapacitetsuppgift med tidsankare; infasas till 2030. |
| Stated 2030 | `stated_2030` | Kapacitetsuppgift med tidsankare; infasas till 2030. |
| Stated 2035 | `stated_2035` | Samma urval; infasas till 2035. |
| High 2035 | `high_2035` | Alla aktiva kapacitetsuppgifter, även odaterade; tidsosäkerhet visas som intervall. |

Namnen, ID:na och urvalen kommer från projektets tidigare metod (`bb15b4e`). En källa till byggstart, första drift, full kapacitet eller nätår kan vara tidsankare. Fullbyggnadsår är inte ett krav. Infasningen ersätter det tidigare antagandet att hela campuset var tillgängligt vid första bygg-/driftår. Kända datum efter målåret respekteras även i High; hela ramen ligger fortfarande i nameplate-indikatorn.

[National Grid DSO/Regen, november 2025, s. 28–30](https://dso.nationalgrid.co.uk/downloads/15083/data-centre-impact-study2.pdf) använder projektinventering, planerings-/anslutningsläge och tidsuppgifter i scenarier. Rapporten stöder arbetssättet, inte våra exakta scenarioetiketter eller urval. Urvalen är villkorade definitioner, inte sannolikhetsprognoser. EPRI:s amerikanska mognadsprocent för 2030 används inte som generella projektrabatter eller extrapoleras till 2035. Tillstånd eller byggnation av en etapp gör inte hela campuset beslutat.

### Generell infasning

**Standard: 20, 40, 60, 80 och 100 procent från första driftåret.** Detta är samma operativa infasningsantagande som EPRI använder. Det införs oberoende av projektstorlek; den tidigare 100 MW-gränsen tas bort. National Grid/Regen beskriver flerårig utbyggnad och variation mellan anläggningar (s. 27). Fem år är alltså en belagd modellstandard, inte en nordisk observation eller en garanti för varje projekt.

| Tillgängligt underlag | Automatisk behandling |
| --- | --- |
| Första driftår | Femårsinfasning från detta år. Ett datumintervall ger ett tidigt och ett sent förlopp. |
| Enbart byggstart | Första drift antas 2–3 år senare, därefter samma femårsinfasning. |
| Full kapacitet uttryckligen daterad för samma omfattning | Hela omfattningen är tillgänglig då. Innan dess fördelas standardrampen bakåt från slutåret, begränsad av känd byggstart. Bakåtfördelningen är en modellberäkning. |
| Enbart nätår | Tidigast möjlig start. Lägre utbyggnadsfall är 0; övre följer standardrampen från tidigaste nätår, med byggtidsbegränsning om byggstart finns. Ingen påhittad extra ettårsfördröjning. |
| Inget användbart år | Inget startår uppfinns. High visar 0–100 % tidsosäkerhet; hela nameplate-ramen finns kvar bredvid samtliga scenarier. |

Byggtiden 2–3 år är en uttrycklig tillämpning av [IEA, Energy and AI, 2025](https://www.iea.org/reports/energy-and-ai/energy-demand-from-ai), som beskriver att datacenter kan bli operativa inom 2–3 år. Den avser inte all föregående tillstånds- eller nätprocess och garanterar inte att förseningar uteblir. Alla antagna datum stannar i beräkningen, aldrig i källfälten.

Mer precist källunderlag används med samma regler för alla projekt. En uttryckligen fullt driftsatt etapp får ingen andra femårsinfasning. Saknas sådan precision används standarden. Landsuppdateraren tolkar omfattning och datum; användaren behöver inte lägga in undantag. Ett campus kan ha en känd första etapp och en större odaterad ram samtidigt.

### Överlapp och befintlig drift

`parent_id/relation` samlar campus, ingående etapper och kunder i en fysisk ram. Inom en sådan grupp används största tillämpliga omfattning, inte summan av campus och innehåll. Separata additiva utbyggnader har `independent` eller `incremental_to`; modellen antar inte att två namn är additiva. Om summan av etapper är dokumenterad registreras också den gemensamma omfattningen i samma kapacitetstabell.

En känd etapp kan bidra även om campusets eget MW-tal eller fullbyggnadsår saknas. Vid osäkert kundöverlapp antas tills vidare inneslutning; båda projekt syns och antagandet märks. `related_project_id` håller en möjlig dubblett synlig utan ett extra MW-bidrag innan identiteten lösts.

Befintlig drift är inte ny utbyggnad. En jämförbar känd bas subtraheras före PUE-omräkning. Okänd bas ger 0 till möjlig ram för tillskottet; kända nya etapper kan höja den lägre nivån. Detta är bokföringsgränser utifrån tillgängliga fakta, inte skattade sannolikheter. Avbrutna projekt kvarstår som historik. Felattribuerade siffror och reservkraft får inte bli datacenterlast, men projektet behålls.

### Energi, tolkning och täckning

Årlig användningsfaktor beror på anläggningstyp (`config/pipeline.json` → `type_assumptions`, samma tabell som den publika trackern): hyperskala 0,75 och colocation 0,57 relativt nameplate, 0,94 respektive 0,88 relativt explicit topp ([EPRI 2026, s. 15](https://powering-intelligence.epri.com/annual-peak-use.html)). Colocation/AI 0,60 och AI/HPC 0,80 är egna bedömningar; AI/HPC-värdet vilar på LBNL:s driftstid för AI-servrar, som inte är en anläggningsfaktor, och är tabellens svagaste värde. Projekt utan typ får intervallet 0,57–0,75 (0,88–0,94 mot topp). Faktorerna bygger på ett litet amerikanskt anläggningsurval och är inte universella nordiska lastfaktorer. Infasning tillämpas en gång. Ingen extra beläggnings-/mognadsrabatt läggs ovanpå den. Ingen timprofil, samtidighetsprognos eller nätanslutningsgaranti räknas fram här.

Summeringar visar den kvantifierade delen och antal projekt utan användbart MW. Okänt elområde ligger i landets `unassigned`. Projekt utan MW är inte nollförbrukare. Alla registrerade projekt får en indikator i varje scenario, men detta bevisar inte fullständig marknadstäckning.

Kontrollen och landspaketet lyfter också källutdrag med MW/GW som ännu saknar en motsvarande användbar kapacitetsobservation på samma projekt. Det fångar källor som annars bara blivit liggande på en kandidat. Det är ett sökstöd för automatisk uppföljning, inte en garanti för att alla tal i en källa är korrekt tolkade. Det blockerar inte befintliga beräkningar eller tar bort projekt. Uppdateraren följer upp dessa träffar och samtliga projekt utan MW, enligt `prompts/update.md`.

## Standardiserad inventering

En inventering körs ett land i taget i Codex (Sverige, Norge, Finland). Startprompterna finns överst i `prompts/update.md`; klistra in den för landet i en ny session. Agenten kör `prepare`, söker, går igenom arbetslistan, kör `apply` och redovisar, men committar inte.

Mellan länderna (för dig):

1. Läs redovisningen i chatten och körloggen i `runs/`.
2. Granska `git diff data/` (registret) och `git diff assets/data/datacenters/scenario_zone.json` (sajtens zonsummor).
3. Godkänn kandidater som ska bli publika genom att ändra `record_type` till `existing` i `data/projects.csv`, och kör sedan `Rscript scripts/pipeline.R tracker`.
4. Committa. Starta nästa land i en ny session.
5. När alla tre är klara: kopiera `assets/data/datacenters/` till sajtens `assets/data/datacenters/`.

| Steg | Fast uppgift |
| --- | --- |
| Prepare | Skapa arbetskopior av de tre tabellerna och ett paket med instruktion, landsprofil, utgångsdata, identitetsindex, ID-gränser och arbetslista. |
| Discover | Sök brett i landet via operatörer, plan/tillstånd, nät, branschpress och landssökning, på alla angivna språk. |
| Audit | Följ upp varje befintligt och nytt projekt och alla kapacitetsuppgifter; klassa MW efter ordalydelse; arbeta igenom arbetslistan. |
| Reconcile/review | Stäm av projekt och MW mot resultatet, granska ändringar, gör en andra sök-/granskningspassage och följ upp bortfall. |
| Apply/report | Inför hela ändringen, bygg resultatet och trackerfilerna och redovisa per elområde/scenario i chatten. |

Agenten genomför hela processen enligt `prompts/update.md`; användaren behöver inte fördela projekt eller starta varje delsteg. `scratch` börjar med tomma arbetsregister för valda länder och stämmer senare av mot tidigare identiteter; tidigare observationer försvinner inte bara för att bredsökningen missade dem.

Miljön är låst i `renv.lock`; återställ vid behov med `Rscript -e 'renv::restore()'`. Agentens gemensamma ingång är:

```sh
Rscript scripts/pipeline.R prepare --country=SE --mode=refresh
# Efter källarbete och granskning, använd arbetskatalogen som prepare skrev ut:
Rscript scripts/pipeline.R check --data=/sökväg/till/arbetskatalog
Rscript tests/method.R
Rscript scripts/pipeline.R apply --data=/sökväg/till/arbetskatalog
```

`prepare` skapar endast tre CSV-kopior och ett packet.json i en unik tillfällig katalog; det ändrar inte registret. Paketet innehåller också svenska/norska/finska sökord, måttbegrepp, källvägar och språkkrav från de tidigare landsprofilerna. Inga nya permanenta tabeller eller kolumner tillkommer. Metodens källdatum i konfigurationen är inte bevis på en ny inventering; paketet och det införda resultatets inventory_run anger körningens datum och länder.

`check` validerar och visar luckor/ändringar. `apply` kontrollerar utgångsläge, bevarade ID:n och landsavgränsning, inför de tre tabellerna och bygger resultatet. Vanliga skrivfel återställer tidigare filer; ett avbrutet system under införandet behöver kontrolleras innan arbetet fortsätter. Sökningens kvalitet bedöms i promptens granskningssteg, inte genom en metadataflagga.

För fristående, läsande förberedelse och beräkning finns även:

```sh
Rscript scripts/pipeline.R packet --country=FI --output=/tmp/fi-packet.json
Rscript scripts/pipeline.R check
Rscript scripts/pipeline.R build --output=/tmp/datacenters-preview.json
Rscript scripts/pipeline.R tracker --output-dir=/tmp/tracker-preview
```

Varken paketförberedelse, kontroller eller `build` utför webbinventering. Agenten behöver fungerande sök-/läsverktyg för den delen. En omräkning av gamla data får aldrig presenteras som en ny inventering. Standardresultatet är en JSON med register, metod, projekt/scenarier, täckning och karta. Ingen extern publicering sker.

## Koppling till trackern (dfornis.github.io)

Sidan `/projects/datacenter-tracker/` läser fyra filer: `projects.json`, `capacity.json`, `scenario_zone.json` och `bidding_zones.geojson` i `assets/data/datacenters/`. `apply` skriver dem i samma steg som registret förs in, och `Rscript scripts/pipeline.R tracker` skriver dem fristående. Kopiera mappen till sajtens `assets/data/datacenters/`; inga ändringar i sajtens kod behövs.

Filerna har exakt samma fält och fältordning som tidigare och samma scenarioregler som sidans JavaScript (år = tidigaste av drift- och byggstartsår; Low kräver beslut; High tar med odaterat). Tabellens summa och kartans Σ blir därmed samma, utom när en kund ligger inom ett annat projekts campusram: kartan räknar den en gång, tabellen visar båda raderna.

- **Urval:** `record_type = existing` och status som inte är Operational, Dormant eller Cancelled. Nya projekt läggs in som `candidate` och syns inte publikt förrän de ändras till `existing`. Det är granskningssteget innan något publiceras.
- **Punktvärden:** typbaserad PUE och årlig lastfaktor från `config/pipeline.json` → `type_assumptions`, samma tabell som sidan redovisar och som modellen använder för lastfaktorn. En källbelagd design-PUE på kapacitetsraden ersätter typvärdet.
- **Tolkning:** IT-effekt × PUE ger nätsidan. Anläggnings-, nät- och ospecificerat MW används som nätsidans MW och IT = MW / PUE (`tracker.unspecified_headline_as = facility`). Reservkraft, reaktoreffekt och felattribuerade uppgifter blir ingen last.
- **Krav för publicering:** publika projekt behöver `type`, elområde och koordinater; annars stoppar `apply` innan något ersätts.
- **Text:** "data centre/center" skrivs "datacenter" i de publicerade fälten, som på sajten. Källutdragen ändras inte.

Intervall och femårsinfasning finns kvar i `assets/datacenters.json` för analysen; den publika sidan visar punktvärden utan infasning.

## Status och historik

Metod 3.2 (oktober 2026) lägger till intervallet för ospecificerat MW, typberoende lastfaktor och exporten till den publika trackern. Det är metodändringar inför landsuppdateringen, inte en ny inventering: de 52 projektposterna, 46 kapacitetsuppgifterna och 130 källorna är oförändrade. Kända luckor (15 ospecificerade MW-rader i Sverige, projekt utan datum eller MW) står i arbetslistan för nästa landskörning.

Tidigare underlag och körningshistorik finns i Git, bland annat `9779acc`. Behåll stabila ID:n; nya löpnummer ska ligga över högsta använda nummer även i historiken. Utdataformat 3.1 återställer ursprungliga scenario-ID:n och skiljer nameplate från infasad kapacitet. Det saknar en femte potential-scenariofamilj. Kartornas ursprung/återanvändningsrätt är olösta och koordinaterna är ungefärliga visningspunkter.
