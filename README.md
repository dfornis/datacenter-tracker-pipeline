# Datacenterplaner i Sverige, Norge och Finland

Projektregister och villkorade planeringsscenarier. Ett projekt försvinner inte för att MW-tal, granskningsmarkering eller fullbyggnadsår saknas. Alla registrerade projekt och kandidater visas i varje scenario: beräknad kapacitet, del av ett campus, projekt utan MW, befintlig drift eller avbrutet projekt.

## Det du underhåller

| Fil | Innehåll |
| --- | --- |
| `data/projects.csv` | Projekt och kandidater, identitet, land/elområde, status och källor. 13 kolumner. |
| `data/capacity.csv` | Kapacitetsuppgifter och etapper, mått, tid och samband. 21 kolumner. |
| `data/sources.csv` | Källregister med utdrag, datum och hänvisning. 9 kolumner. |
| `config/pipeline.json` | Samtliga scenarioregler, antaganden, kolumner, språk och kartfiler. |

Kopplingar går från projekt/kapacitet till källor; källregistret upprepar inte kopplingarna tillbaka. Granskningsköer, fältgranskningsregister, ID-register, separata antagandetabeller och kopior av kompletta dataversioner är borttagna ur den aktiva strukturen. Git håller historiken. Rätta och granska de tre tabellerna som en sammanhängande ändring; en uppdaterare i taget.

`scripts/model.R` innehåller beräkningen och kontrollerna. `scripts/pipeline.R` är den gemensamma ingången. `tests/method.R` prövar metodens beteende. `prompts/update.md` är instruktionen för landsuppdateringar. Sju kartfiler under `data/reference/bidding-zones/` täcker tio elområden.

## Metod

### Projektöversikt och definitioner

Varje projekt får en indikator i samtliga scenarier. Projekt utan MW räknas som projekt med saknad effektuppgift; deras effekt är okänd, inte noll. Okänt elområde placeras under landets `unassigned`. Avbrutna projekt ligger kvar som historik med noll nytillkommande kapacitet. Befintlig drift redovisas som drift, inte som ny utbyggnad.

Kandidater ligger i samma projekttabell med `record_type=candidate`. De är inte verifierade bara för att de finns där. Kända identitetskonflikter spärrar den felattribuerade siffran, men inte projektets synlighet. `related_project_id` markerar en möjlig dubblett; separata MW räknas först när identiteten har lösts.

Källans MW och definition bevaras. Scenarierna visar **modellerad nominell anläggningseffekt**, i MW. Det är ett gemensamt kapacitetsmått, inte uppmätt topplast eller beställd nätkapacitet.

| Källans mått | Beräkning |
| --- | --- |
| IT-effekt | Multiplicera med PUE 1,1–1,5; använd tillgänglig lokal design-PUE som övre scenarioantagande. |
| Nominell anläggningseffekt | Behåll MW. |
| Explicit toppeffekt | Dividera med toppeffekt/märkeffekt 0,62–0,80 för jämförbar nominell effekt. Årsenergin använder fortfarande ursprunglig toppeffekt och dess egen användningsfaktor. |
| Nätanslutning | Modellera att scenariots andel av anslutningsramen tas i bruk som anläggningskapacitet; märk antagandet. |
| Ospecificerat datacenter-MW | Lägre fall: anläggningseffekt. Högre fall: IT-effekt × övre PUE. Källans definition ändras inte. |
| Reservkraft, reaktor, rackdensitet | Ingen omräkning till datacenterlast. Projektet syns med saknad datacentereffekt. |

Intervallen är beräkningsfall, inte konfidensintervall eller garanterade gränser. `up_to` är en annonserad ram som scenariot använder, inte säkert byggd kapacitet. Ett `at_least`-tal utan övre belägg får ingen påhittad ändlig övre gräns.

### Mognad och scenarier

Byggnation avser den aktuella kapacitetsuppgiften/etappen. Avancerad plan är beslutad eller tillåten etapp, eller en planerad utbyggnadsram på ett campus under byggnation/i drift. Det senare märks uttryckligen: hela ramen är inte därmed beslutad. Övriga aktiva planer och koncept räknas som tidiga.

Andel av annonserad omfattning som antas vara tillgänglig vid målåret:

| Scenario | Byggnation | Avancerad plan | Tidig plan |
| --- | ---: | ---: | ---: |
| Försiktig 2030 | 90 % | 25 % | 0 % |
| Planering 2030 | 100 % | 75 % | 10 % |
| Planering 2035 | 100 % | 100 % | 30 % |
| Hög utbyggnad 2035 | 100 % | 100 % | 60 % |
| Odaterad potential | 100 % | 100 % | 100 % |

Andelarna är portföljantaganden om genomförande och utbyggnad, inte sannolikheter för enskilda projekt. 2030-värdena följer EPRI:s scenarioupplägg som utgångspunkt. Mappningen av vårt register till grupperna och 2035-värdena är analysval, inte kalibrerade nordiska prognoser. [EPRI, kapacitetsscenarier](https://powering-intelligence.epri.com/nominal-capacity.html).

Granskningsmetadata påverkar inte andelarna. Befintligt källstött innehåll kan användas utan en ny verifieringsmarkering. Fel fakta rättas i källdata; osäker utveckling hanteras i scenarierna.

### Tid utan utslagning

Saknat fullbyggnadsår ger inget generellt bortfall. Mognadsandelen används när tid saknas helt. Mer information begränsar vad som kan antas vara tillgängligt:

- Angiven full kapacitet senast målåret ger ingen ytterligare tidsbegränsning.
- Om källan anger ett datumintervall används det senaste angivna året för tidsbegränsningen.
- Första kapacitet är start för modellerad infasning: två år för en omfattning under 100 MW, fem år från 100 MW. Första året räknas som första andelen. Detta är en analysregel, inte ett nytt källpåstående.
- Känd byggstart utan driftår ger antagen första kapacitet två år senare. Ett nätår ger antagen första kapacitet ett år senare.
- Framtida fullbyggnad fördelas från känd byggstart plus två år, annars över antagen infasningstid före slutåret.
- Använd **den lägsta av mognadsandel och tidsandel**, inte produkten av två rabatter för samma utbyggnad. Start efter målåret ger noll i just det tidsscenariot; projektet finns i senare scenarier och potential.

Etappvis utveckling stöds som princip av [National Grid DSO/Regen](https://dso.nationalgrid.co.uk/downloads/15083/data-centre-impact-study2.pdf). Våra två-/femårsregler är startantaganden och ersätts av projektspecifika etapper där sådant underlag finns.

### Campus, etapper och befintlig drift

`parent_id` och `relation` kopplar etapper/kunder till samma ram. Inom gruppen används ett gemensamt kapacitetskuvert: största tillämpliga omfattning, inte summan av kuvert och innehåll. Ett möjligt kundöverlapp antas ingå i campuset i beräkningen; båda projekten syns. En känd tidig etapp kan bidra även om hela campuset saknar fullbyggnadsår eller eget MW-tal. I det senare fallet redovisas den kända etappens bidrag på campuset, medan källuppgiften om hela campusets effekt förblir tom.

Verkligt separata, additiva utbyggnader ska vara separata uppgifter med `independent` eller `incremental_to`. Om två etapper kan adderas inom en ram behöver deras gemensamma omfattning beläggas; modellen antar inte detta från två namn.

Installerad kapacitet subtraheras bara mot samma projekt och mått. Vid samma IT-mått görs subtraktionen före PUE-omräkning. Om installerad bas är okänd behålls rapporterad anläggningsram och tillskottet anges som **0 till möjlig ram**. En känd ny etapp kan höja den lägre nivån. Tillgänglig nätkapacitet blir inte automatiskt installerad datacenterlast.

### Energi och redovisning

Årsekvivalent = scenariots effekt på rätt måttgrund × årlig användningsfaktor × 8 760 timmar. Märkkapacitet använder 0,57–0,75; explicit toppeffekt använder 0,88–0,94 på ursprungligt toppvärde, inte den omräknade nominella effekten. Även omräkningsfaktorn topp/märkeffekt 0,62–0,80 hämtas från [EPRI:s energianalys](https://powering-intelligence.epri.com/annual-peak-use.html). Intervallen är känslighetsfall, inte en nordisk empirisk kalibrering.

**TWh avser årsbehov vid scenariots utbyggnadsnivå**, inte exakt förbrukning under driftsättningsåret. Ingen andra beläggningsrabatt läggs ovanpå scenariots utbyggnadsandel. Detta ersätter ett separat årsvis driftsättningsregister.

Utdata visar projektantal, kandidater, drift, avbrutna projekt, projekt utan MW, modellerat MW-intervall och TWh-intervall per elområde/scenario. Summeringar omfattar den kvantifierade delen. När inget användbart MW-tal finns visas okänt. Ingen nationell fullständighet påstås.

## Köra och uppdatera

Miljön är låst i `renv.lock`. Återställ vid behov med `Rscript -e 'renv::restore()'`.

```sh
Rscript tests/method.R
Rscript scripts/pipeline.R check
Rscript scripts/pipeline.R packet --country=FI --output=/tmp/fi-packet.json
Rscript scripts/pipeline.R build --output=/tmp/datacenters-preview.json
```

`check` prövar befintligt underlag utan att ändra något. `packet` skapar ett landspaket; det är inte en utförd sökning. `build` skriver en JSON-fil med register, scenarier, projektvis beräkning, källor, metod och karta. Standarddestination: `assets/datacenters.json`. Filen ersätts först när hela beräkningen och alla tio kartområden är klara. Ingen extern publicering sker.

Vid landsuppdatering används `prompts/update.md`. Arbeta på en kopia av tre tabeller, kontrollera med `--data=/sökväg/till/kopia`, granska ändrade fakta och för över en sammanhängande ändring. Spara med Git. Kör en uppdaterare i taget. Körningspaket och arbetsfiler kan ligga tillfälligt; de är inte nya permanenta tabeller.

## Status och historik

Metod 3 bygger på tidigare insamlat underlag med brytdatum 2026-10-11. Metodarbetet är inte en ny landsinventering. Registret har 38 tidigare projekt och 14 kvarvarande kandidater efter att en dubblett av Nebius Lappeenranta förts till P035. Undheim är fortfarande kopplat till den oklara äldre Kalberg/Undheim-identiteten. P035/C040 är Nebius; den äldre pilotens etikett XTX var fel. XTX är P037/C043.

Tidigare arbetsversion, körningshistorik, kommunreferenser och granskningsspår finns i Git-commit `9779acc`, utan en parallell aktiv arkivstruktur. Återanvänd aldrig pensionerade ID:n; nya löpnummer ska ligga över högsta använda nummer även i historiken.

Format 3 ersätter separata exportfiler med ett objekt. Konsumenter läser `version`, `scenarios`, `project_scenarios` och `ledger`; gamla filnamn/scenario-ID:n är inte kompatibla. Kartornas ursprung och återanvändningsrätt är fortfarande olösta. Befintliga koordinater är ungefärliga visningspunkter, inte verifierade anläggningspositioner.
