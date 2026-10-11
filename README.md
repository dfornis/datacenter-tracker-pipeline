# Datacenterplaner i Sverige, Norge och Finland

Projektregister med villkorade scenarier. Alla projekt och kandidater finns i varje scenarios översikt, också när effekt eller datum saknas. Okänd effekt är okänd, inte noll. Resultat och begränsningar redovisas i chatten.

## Det du underhåller

| Fil | Innehåll |
| --- | --- |
| `data/projects.csv` | Projekt, kandidater, identitet, land/elområde och status. 13 kolumner. |
| `data/capacity.csv` | Källornas kapacitetsuppgifter, mått, datum och samband. 21 kolumner. |
| `data/sources.csv` | Källor, korta utdrag, datum och hänvisningar. 9 kolumner. |
| `config/pipeline.json` | Scenarier, beräkningsantaganden och deras källor/tillämpningsgränser. |

Tre tabeller, sammanlagt 43 kolumner. Inga separata granskningsregister eller lokala arkivkopior. Git håller historiken. Uppdatera tabellerna som en sammanhängande ändring, med en uppdaterare i taget.

`scripts/model.R` räknar och kontrollerar; `scripts/pipeline.R` är ingången. `tests/method.R` testar beteendet med syntetiska projekt. `prompts/update.md` styr landsuppdateringen. Sju kartfiler täcker tio elområden.

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
| Ospecificerat datacenter-MW | Behåll talet som anläggningsram, enligt ursprungsregistrets konvention. Märk definitionen som antagen; ingen extra PUE-uppräkning. |
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

Årlig användningsfaktor är 0,57–0,75 relativt nameplate, eller 0,88–0,94 relativt explicit topp. Faktorerna bygger på EPRI:s lilla amerikanska anläggningsurval; de är känslighetsfall för denna inventering, inte universella AI- eller nordiska lastfaktorer. Infasning tillämpas en gång. Ingen extra beläggnings-/mognadsrabatt läggs ovanpå den. Ingen timprofil, samtidighetsprognos eller nätanslutningsgaranti räknas fram här.

Summeringar visar den kvantifierade delen och antal projekt utan användbart MW. Okänt elområde ligger i landets `unassigned`. Projekt utan MW är inte nollförbrukare. Alla registrerade projekt får en indikator i varje scenario, men detta bevisar inte fullständig marknadstäckning.

Kontrollen och landspaketet lyfter också källutdrag med MW/GW som ännu saknar en motsvarande användbar kapacitetsobservation på samma projekt. Det fångar källor som annars bara blivit liggande på en kandidat. Det är ett sökstöd för automatisk uppföljning, inte en garanti för att alla tal i en källa är korrekt tolkade. Det blockerar inte befintliga beräkningar eller tar bort projekt. Uppdateraren följer upp dessa träffar och samtliga projekt utan MW, enligt `prompts/update.md`.

## Köra och uppdatera

Miljön är låst i `renv.lock`; återställ vid behov med `Rscript -e 'renv::restore()'`.

```sh
Rscript tests/method.R
Rscript scripts/pipeline.R check
Rscript scripts/pipeline.R packet --country=FI --output=/tmp/fi-packet.json
Rscript scripts/pipeline.R build --output=/tmp/datacenters-preview.json
```

`check` ändrar ingenting. `packet` förbereder ett landspaket och är inte en utförd sökning. `build` skriver en JSON med register, metod, projekt/scenarioberäkningar, täckning och karta. Standarddestination är `assets/datacenters.json`; först en komplett, validerad fil ersätter tidigare resultat. Ingen extern publicering sker.

Landsuppdateringar använder `prompts/update.md`. Arbeta på en tillfällig kopia av de tre tabellerna och kontrollera med `--data=/sökväg/till/kopia`. Granska och för över en sammanhängande ändring. Inga nya permanenta kontrolltabeller behövs.

## Status och historik

Metod 3.1 är en metodkorrigering inför landsuppdatering; den är inte en ny inventering. De 52 projektposterna, 46 kapacitetsuppgifterna och 130 källorna har inte uppdaterats genom denna metodändring. Kända luckor i källextraktionen återstår inför nästa landskörning.

Tidigare underlag och körningshistorik finns i Git, bland annat `9779acc`. Behåll stabila ID:n; nya löpnummer ska ligga över högsta använda nummer även i historiken. Utdataformat 3.1 återställer ursprungliga scenario-ID:n och skiljer nameplate från infasad kapacitet. Det saknar en femte potential-scenariofamilj. Kartornas ursprung/återanvändningsrätt är olösta och koordinaterna är ungefärliga visningspunkter.
