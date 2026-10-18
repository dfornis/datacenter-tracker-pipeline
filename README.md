# Datacenterplaner i Sverige, Norge och Finland

Ett register och en scenariomodell för både chatten och sajten. Godkända totalsummor omfattar manuellt godkända projekt. Alla projekt, även väntande kandidater och projekt utan MW eller datum, finns kvar i indikatorerna. Kandidater redovisas separat med sin effekt innan användaren godkänner namngivna ID:n här i chatten. Okänd effekt är okänd, inte noll.

## Det du underhåller

| Fil | Innehåll |
| --- | --- |
| `data/projects.csv` | Projekt, kandidater, identitet, land/elområde, län/region, typ och status. 15 kolumner. |
| `data/capacity.csv` | Källornas kapacitetsuppgifter, mått, datum och samband. 30 kolumner. |
| `data/sources.csv` | Källor, korta utdrag, datum och hänvisningar. 9 kolumner. |
| `data/actors.csv` | Separat aktörsregister med hela projektets ID, aktör, roll, verksamhetstyp, globalt huvudkontor, ägarbeskrivning, källor och granskning. 11 kolumner. |
| `config/pipeline.json` | Scenarier, beräkningsantaganden och deras källor/tillämpningsgränser. |

Fyra tabeller, sammanlagt 65 kolumner. Aktörsregistret är uttryckligen beställt som en separat projektrelation. Före upptäcktssteget kopieras de fyra tabellerna till en datummärkt mapp under `runs/snapshots/`. Kopian är körningens utgångsläge, inte ett parallellt register. Git håller den övriga historiken. Uppdatera tabellerna som en sammanhängande ändring, med en uppdaterare i taget.

`scripts/model.R` räknar och kontrollerar; `scripts/tracker.R` formaterar samma godkända beräkning för sajten; `scripts/pipeline.R` är ingången. `tests/method.R` testar beteendet med syntetiska projekt. `prompts/update.md` styr landsuppdateringen. Sju kartfiler täcker tio elområden.

Testsviten omfattar beräkningsregler, käll- och identitetsvalidering, aktörsklassning samt arbetsflödet i isolerade testrepon. Antalet utskrivna testgrupper är inte ett täckningsmått: en grupp kan pröva flera kombinationer. Statusbyte till drift prövas exempelvis tillsammans med ny kapacitet, känd eller okänd äldre driftbas och leverans före/efter basåret. Överlappande export- och CLI-kontroller delar samma körning; skydd för godkännanden, landsgränser och återställning vid olika skrivfel behålls. Det aktuella registrets sparade resultat verifieras separat av `check`.

## Aktörer, huvudkontor och ägarbeskrivning

`prompts/actors.md` styr en separat inventering av aktörerna i redan registrerade projekt. Aktörsinventeringen omfattar Sveriges 31, Finlands 46 och Norges 32 projekt som inte är `out_of_scope`. Ingen kapacitet, projektstatus eller godkännandestatus ändras av klassningen.

`actors.csv` har den sammansatta nyckeln `project_id` + `actor_name`. Ett samarbetsprojekt kan därför ha flera rader, medan etapper och kapacitetsuppgifter aldrig får egna aktörsrader. Lokala bolag och historiska namn beskrivs i notes; finansiella ägare bakom den operativa aktören beskrivs i ownership_notes. Källor länkas till befintliga sources.csv. `checked_at` är granskningsdag och `identity_status` skiljer identifierad aktör från en anonym/olöst identitet.

Kartans **HQ**-knappar väljer projekt med minst en aktör med globalt huvudkontor i projektlandet (Domestic), i ett annat europeiskt land (Other Europe) eller utanför Europa (Outside Europe). All återställer hela scenariot. Punkterna är alltid solida och har fasta lägen mellan scenarier. Projekt som deltar i valt scenario och matchar HQ-urvalet får färg. Vid ett HQ-val markeras också projekt med okända MW när deras huvudkontor matchar. Övriga är samma ljusgrå. Projekt som inte deltar i något scenario och saknar okänd ny kapacitet visas inte på kartan. Klickrutan skiljer okänt från ett känt uteblivet bidrag. Siffror i färgade punkter räknar valda projekt.

HQ-valet styr också kartans områdesfärger och summeringen under kartan. Samma färdigräknade projektrader summeras utan att ändra modellvärden eller fördela kapacitet mellan aktörer. Tabellen och dess sammanfattning påverkas inte. HQ-valet ligger kvar vid scenariobyten. Ett streck i HQ-filtrerade siffror markerar länder utan HQ-underlag. Okänd kapacitet visas som Unknown eller med en asterisk efter den kvantifierade delen. Asterisken förklaras i kartans explainer.

HQ beskriver huvudkontor, inte ett fastställt ägarland. Ett samarbetsprojekt kan matcha flera HQ-grupper men räknas en gång i varje urval. En känd aktör kan matcha även när en annan är anonym. Okända och ogranskade huvudkontor ger ingen träff. Granskningens täckning och HQ-metoden beskrivs i sajtens explainer och metodavsnitt.

Modellen exporterar också samlad inhemsk, utländsk, blandad eller okänd HQ-klassning. Om någon relevant aktör saknar identitet eller land blir den samlade klassningen okänd. EU, EU/EES och den bredare Europagruppen har explicita landlistor i config/pipeline.json; Island ingår i EU/EES men inte EU. Verksamhetstypen påverkar aldrig anläggningens energifaktor. Befintliga campus-/kundrelationer och färdigräknade projekt/scenariorader används oförändrade. Expandera projektet för huvudkontor, roller, typ, daterad ägarbeskrivning och källor.

## Metod

### Kapacitet, infasning och energi

Redovisa tre saker tillsammans:

1. **Nameplate / annonserad kapacitetsram, MW** (`nameplate_mw_low/high`): hela den kända, odaterade ramen för anläggningskapacitet tillkommande efter basåret, efter hantering av överlapp och befintlig drift. Samma inventering visas bredvid varje scenario; den är ingen extra scenariofamilj.
2. **Infasad kapacitet vid målåret, MW** (`mw_low/high`): den del av ramen som scenariots urval och tidsantaganden tar i bruk efter det fasta basåret. Detta är kapacitet inklusive kylning och övrig hjälplast, inte faktisk eller uppmätt topplast.
3. **Årsenergi vid denna utbyggnadsnivå, TWh** (`annual_twh_low/high`): infasad kapacitet gånger årlig användningsfaktor och 8 760 timmar. En årsekvivalent, inte exakt förbrukning under driftsättningsåret.

Källans MW, definition, datum och status bevaras separat. [EPRI:s måttdefinitioner](https://powering-intelligence.epri.com/understanding-metrics.html) skiljer IT-kapacitet, total anläggningskapacitet, aktiv kapacitet och faktisk topp. Dessa är inte utbytbara.

| Källmått | Tillämpning i modellen |
| --- | --- |
| IT-effekt | Omräkning till anläggningssidan med PUE 1,1–1,5 som känslighetsfall. Lokal design-PUE ersätter det övre fallet. |
| Anläggningskapacitet | Behåll angivet MW-tal. |
| Nätanslutning | Behåll ramen och märk antagandet att den används till datacenter. En ansökan är inte en beviljad anslutning eller faktisk last. |
| Ospecificerat datacenter-MW | Behåll källans MW-tal eller källintervall utan PUE-konvertering. Klassas om efter ordalydelse vid varje körning (`prompts/update.md`). PUE används endast när källan uttryckligen anger IT-effekt. Samma regel används på sajten. |
| Explicit toppeffekt | Bevara toppvärdet. För kapacitetsjämförelsen används ett uttryckligt känslighetsfall: topp / 0,80 till topp / 0,62. Årsenergi beräknas direkt från ursprunglig topp. |
| Reservkraft, generation, rackdensitet | Behåll observationen utan automatisk omräkning till datacenterlast. En publicerad, motiverad skattning av datacenterlast kan registreras som egen kapacitetsuppgift med källa. |

PUE-fallen och energi-/toppfaktorerna kommer från [EPRI:s energianalys, 2026](https://powering-intelligence.epri.com/annual-peak-use.html). PUE 1,5 är inte ett absolut tak och används bara för uttryckligen IT-klassade MW. Att invertera toppfaktorn är vår tillämpning av källans observerade samband, inte en uppgift om projektets verkliga nameplate. Intervallen är känslighetsfall, inte konfidensintervall. `at_least` utan `mw_max` räknas som det angivna MW-talet i alla scenarier och vid full utbyggnad. Måttets vanliga omräkning och avdrag för jämförbar driftbas gäller. Ett minimum på 100 MW IT ger därför 110–150 MW anläggningskapacitet med standard-PUE. Källans kvalificering bevaras och **≥ X** visas bara vid källuppgiften i detaljraden. Beräknade intervall och summor har ändliga gränser. En minimiuppgift gör aldrig kapaciteten okänd. `up_to` är en annonserad ram.

### Befintliga scenarier

| Scenario | ID | Urval |
| --- | --- | --- |
| Low 2030 | `low_2030` | Beslutad kapacitetsuppgift med tidsankare; infasas till 2030. |
| Stated 2030 | `stated_2030` | Kapacitetsuppgift med eget aktuellt tidsankare, samt odaterad campusram med genomförandeetapp enligt nedan; infasas till 2030. |
| Stated 2035 | `stated_2035` | Samma urval; infasas till 2035. |
| High 2035 | `high_2035` | Alla aktiva annonserade MW, fullt utbyggda senast 2035 efter överlapp och driftbas. Samma MW/TWh som Full build-out. |

Namnen och ID:na kommer från projektets tidigare metod (`bb15b4e`). Metod 4.1 ändrar uttryckligen Stateds campusurval och Highs horisontantagande; Low behåller sitt urval. En källa till byggstart, första drift, full kapacitet eller nätår kan vara tidsankare. Fullbyggnadsår är inte ett krav. Infasningen ersätter det tidigare antagandet att hela campuset var tillgängligt vid första bygg-/driftår. Low/Stated respekterar egna daterade begränsningar. High är hela annonserade ramen inom horisonten, även om ett källmål ligger senare.

[National Grid DSO/Regen, november 2025, s. 28–30](https://dso.nationalgrid.co.uk/downloads/15083/data-centre-impact-study2.pdf) använder projektinventering, planerings-/anslutningsläge och tidsuppgifter i scenarier. Rapporten stöder arbetssättet, inte våra exakta scenarioetiketter eller urval. Urvalen är villkorade definitioner, inte sannolikhetsprognoser. EPRI:s amerikanska mognadsprocent för 2030 används inte som generella projektrabatter eller extrapoleras till 2035. Tillstånd eller byggnation av en etapp gör inte hela campuset beslutat.

### Första drift, fysisk utbyggnad och basdatum

Metod 4.1.1 skiljer **källbelagda tidsankare**, **scenariourval** och **beräknad leverans**. Modellberäknade år blir aldrig källfält. Low kräver beslut och aktuellt källdatum för just omfattningen. Stated omfattar också följande uttryckliga campusregel.

**Campus under genomförande.** En odaterad ram med MW tas med i Stated när den innehåller en datacenteretapp i samma projekt med observerad byggstart eller `decision=yes`, samt eget källbelagt första drift-, bygg- eller fullbyggnadsår. Etappens MW kan vara känt eller okänt. Campusets tidiga förlopp börjar vid tidigaste beräknade första drift och det sena vid den senaste bland de kvalificerande etapperna. Med enbart byggstart används 2–3 år till första drift. Båda förloppen fördelas linjärt från startåret till 2035, med en lika stor andel per kalenderår inklusive startåret. Femårsrampen används inte när starten är härledd från en etapp. Skälet är att bara starten har belägg i etappen, medan slutåret är ett horisontantagande. En omfattning med eget källdatum följer sina vanliga regler. Regeln exporteras som `executing_campus_full_by_horizon` tillsammans med `executing_phase_ids`. Detta är ett antagande om campusets fortsättning, inte ett källbelagt fullbyggnadsår eller beslut för hela ramen.

Rader med `basis=grid`, `backup`, `generation` eller `density` kan aldrig aktivera campusregeln. Observerad byggstart för nätanläggningar hör till nätraden. Byggstart och investeringsbeslut för datacenterkapacitet kräver belägg för just datacentret. Planerade etapper utan beslut, etapper i andra projekt och äldre driftbas aktiverar inte heller regeln. Avbrutna och vilande etapper utesluts. Kända etapp-MW utgör golv under de första åren genom samma största-omfattning-regel som tidigare. Low tar bara med etappens eget bidrag; saknas MW kvarstår den som okvantifierad. I Stated 2035 omfattas etappen av den fullt utbyggda campusramen. En uttryckligt länkad senare nätöppning har fortfarande företräde i Low/Stated och flaggas som konflikt om den ligger bortom horisonten.

Första drift beräknas före full utbyggnad:

1. Ett användbart källbelagt första driftår används för samma omfattning. Ett preciserat projektschema ersätter generell byggtid. Ett passerat, ej bekräftat mål räknas däremot om från dagens genomförandeläge. Ett driftår före byggstart markeras som konflikt.
2. Med enbart byggstart används 2–3 år till första drift. En gammal planerad byggstart är inte en inträffad händelse. Ett bygge som fortfarande inte är färdigt efter den antagna byggtiden får återstående byggtid från bedömningsåret.
3. Annars används följande **egna, preliminära känslighetsantaganden**, uttryckta i hela kalenderår. De är inte tidigare beslutade värden, observerade nordiska ledtider eller konfidensintervall.

| Genomförandeläge för omfattningen | Till byggstart, tidigt–sent | Byggtid/återstående byggtid | Första drift från bedömningsåret |
| --- | ---: | ---: | ---: |
| Konceptstudie eller oklart läge | 2–5 | 2–3 | +4–8 |
| Planerad | 1–3 | 2–3 | +3–6 |
| Tillståndsgiven | 0–1 | 2–3 | +2–4 |
| Byggnation pågår, användbar byggstart saknas | 0 | 0–2 | +0–2 |

Noll betyder möjlig leverans senare under bedömningsåret, inte att kapaciteten redan finns. Ett tillstånd är inte i sig investeringsbeslut. Parametrarna ligger i `assumptions.stage_lead_times`; de gäller kapacitetsradens eget läge, aldrig en annan etapp eller projektets övergripande etikett. [IEA](https://www.iea.org/reports/energy-and-ai/energy-demand-from-ai) stöder 2–3 år som möjlig utvecklingstid och pekar på längre nätledtider. [National Grid/Regen, s. 26–28](https://dso.nationalgrid.co.uk/downloads/15083/data-centre-impact-study2.pdf) beskriver nätbegränsningar och varierande etappförlopp. Källorna fastställer **inte** tabellens exakta planerings- eller återstående ledtider. Dessa ska kalibreras med daterade tillstånd, faktisk byggstart och faktisk drift för jämförbara genomförda etapper, med separata fall för förseningar och ännu oavslutade projekt.

**Utbyggnad.** En källbelagd enskild leverans (`delivery_profile=single_phase`) tas in vid sitt eget driftår utan en andra ramp. En etapp med både första drift och full kapacitet använder sitt eget schema. För stegvis eller okänd utbyggnad, utom campusförlopp med härledd start enligt ovan, behålls tills vidare fem år (20/40/60/80/100 procent) som en fysisk utbyggnadsschablon. EPRI:s tidigare operativa ramp är inte direkt belägg för fysisk färdigställning; användningen här är en osäker modellanpassning, med stöd för fleråriga etapper i National Grid/Regen. Den får inte samtidigt användas som en andra upptrappning av elanvändning. Årsenergi är färdig kapacitet gånger befintlig användningsfaktor, en årsekvivalent och inte uppmätt förbrukning.

**Fullbyggnadsmål och konflikter.** Ett användbart källbelagt fullbyggnadsår gäller för den angivna omfattningen och har företräde framför generella ledtider och femårsschablonen. Första drift uppskattas inom tiden fram till målåret; schablonens utbyggnad komprimeras vid behov. Ingen obelagd historisk drift skapas. Exempel: Torsbodas angivna 650 MW färdigt 2030 ligger på 650 MW 2030, med uppskattad första drift 2029–2030 utifrån nuvarande planeringsstatus. Årtalet överförs inte till ramarna på 1 000 eller 2 000 MW. Modellen antar inte försening därför att schablonen är längre.

En senare källbelagd byggstart, första drift eller uttryckligen tillämplig nätöppning kan däremot motsäga ett fullbyggnadsår. Då begränsar den belagda händelsen förloppet och en konflikt exporteras i `timing_flags`. Ett passerat mål utan verifierad leverans får ett nytt antaget förlopp från nuvarande läge och en uppföljningspunkt. Källvärden ändras aldrig av beräkningen. Faktiskt färdigställd kapacitet tas in vid det belagda året; modellen hittar inte på en historisk ramp före denna händelse. Faktisk driftsättning behålls också vid konflikt med ett planerat nätbesked, och konflikten markeras för granskning.

**Nät.** `grid_claim_id` kopplar en omfattning till en uttryckligen tillämplig nätobservation i samma kapacitetstabell, projekt och överlappsgrupp, så att nätet inte skapar ett extra MW-bidrag. Anslutningsår begränsar första drift i Low/Stated. Nätets MW är **inget tak** för lastens bidrag: jämförbara nätdokument saknas för stora delar av registret. En ansökt eller oklar anslutning har noll som lägre fall endast i Low/Stated. High bortser från dessa nätbegränsningar. Ingen nätbegränsning överförs automatiskt mellan etapper. Flera anslutningssteg ska beskrivas med egna avgränsade etapper och nätobservationer; en enda länk återger inte ett helt nätutbyggnadsschema.

**Basdatum och historia.** `timeline.base_year=2025` är fast: grafen visar tillskott efter årsskiftet 2025/2026. Bedömningsdatum är det senaste av den explicita startpunkten i konfigurationen, kapacitetsradernas statusdatum och åtkomstdatum för deras direkt kopplade källor. Det ändras med kapacitetsunderlaget, aldrig med datorns klocka eller en fristående aktörsgranskning. Det daterar beräkningen, inte projektets händelser. Äldre statusuppgifter blir uppföljningspunkter.

En faktiskt daterad leverans efter basåret ligger kvar när status ändras till Operational. En äldre driftbas räknas inte igen. Saknas faktisk datering kan historiskt tillskott inte rekonstrueras säkert; detta går till arbetslistan. Ett nytt basår kräver ett uttryckligt metodbeslut och omräkning, inte en automatisk rullning.

**Horisontprincip.** Redovisningen slutar 2035. En total ram utan år antas fullt utbyggd senast då. High 2035 är lika med full utbyggnad per projekt och totalt; spannet kommer från MW-mått, PUE, källintervall och avdrag för befintlig drift/överlapp, aldrig från tid, nät eller genomförandeläge. Highs årsförlopp kan behålla form från ledtiderna men komprimeras till 2035. Det är en övre ram, inte en prognos.

Årsexporten i `timeline.json` har separata färdigräknade mått: `mw_*` (kumulativa tillskott), `annual_addition_mw_*` (årets tillskott), `future_addition_mw_*` (leverans efter bedömningsårets slut) och `remaining_mw_*` (annonserad ram som ännu inte levererats). Årets intervall kommer från förändringen längs både tidigt och sent förlopp, med vardera nedre och övre MW-fall. En större redan levererad etapp kan ge ett mindre senare tillskott till samma ram. Därför tas minsta och största årsändring över alla fyra kombinationer. Dess separata gränser ska inte summeras till ett kumulativt intervall. Återstående ram omfattar också kapacitet som scenariourvalet inte tar i drift. MW saknas fortfarande när underlaget saknas.

### Tidsuppgifter i de befintliga tabellerna

`capacity.csv` behåller samtliga tidigare fält, ID:n och källvärden. Åtta tillägg uttrycker skillnader som inte var maskinläsbara: `construction_event` och `timing_event` (planned/actual/unknown), `status_as_of`, `delivery_profile` (single_phase/staged/unknown), `full_capacity_year` och `full_capacity_last_year` (eget slutår när timing=first_capacity), `grid_claim_id` och `grid_status` (requested/reserved/contracted/available/unknown). Tomt betyder okänt. De gamla fälten `timing`, `first_year`, `last_year` och `construction_year` behåller sin betydelse. Käll-ID och det precisa belägget för varje datum/klassning anges i befintliga `source_ids` och `notes`; en åtkomstdag får inte användas som händelsedag.

Metod 4.1 lägger till `timing_status` (tomt/current/superseded). Om en senare källa för samma eller jämförbar omfattning utelämnar eller ersätter ett äldre mål markeras det äldre målet superseded och behandlas som odaterat. Behåll målår och MW i källfälten, och dokumentera båda källorna, deras ordning och omfattningsjämförelsen i notes. Enbart senare åtkomstdag räcker inte. Faktiska händelser ogiltigförklaras inte: dela upp blandade mål/händelser i rätt omfattningar. En ny användbar datering får återställa current med dokumenterat belägg.

`prepare` och `check` bygger `timing_followups` från dessa fält och befintliga källutdrag. Listan prioriteras efter den största möjliga skillnaden mellan tidigt och sent MW-bidrag från bedömningsåret till 2030, därefter omfattningens MW. Även en daterad slutfas kan därför prioriteras för osäkerhet under åren före färdigställandet. Överlappande raders prioritetstal får inte summeras. Den kompletterar befintliga listor för odaterade projekt, etapper utan MW och möjliga lånade campusdatum med passerade mål, oklart läge, nätluckor och tidskonflikter.

Varje punkt avslutas med kompletterade källfält eller en substantiell kvarstående osäkerhet i samma kapacitetsrads notes: `Timing review ÅÅÅÅ-MM-DD [review_key]: förklaring av sökt underlag och vad som fortfarande är okänt.` Nyckeln följer med arbetslistan. `check` visar öppna och dokumenterade luckor separat; ändrat underlag eller bedömningsdatum öppnar granskningen igen. Modellen läser inga körloggar och inget separat granskningsregister skapas. Automatisk validering kontrollerar struktur och beräkning, inte om en sökning verkligen genomförts.

### Överlapp och befintlig drift

`parent_id/relation` samlar campus, ingående etapper och kunder i en fysisk ram. Inom en sådan grupp används största tillämpliga omfattning, inte summan av campus och innehåll. Separata additiva utbyggnader har `independent` eller `incremental_to`; modellen antar inte att två namn är additiva. Om summan av etapper är dokumenterad registreras också den gemensamma omfattningen i samma kapacitetstabell.

En innesluten rad (`included_in` eller `possibly_included_in`) som överstiger sin direkta överordnade ram flaggas som `containment_conflict` i `timing_followups` och `check`. Jämförelsen gäller motsvarande nedre och övre brutto-MW efter måttomräkning, före infasning och basavdrag. Beräkningen använder fortfarande den största omfattningen. Uppföljningen visar båda radernas källor och avslutas med källbelagd rättning av MW, mått eller relation, eller källanknuten kvarstående osäkerhet. Ändringar i den överordnade ramen eller dess källor öppnar uppföljningen igen.

En känd etapp kan bidra även om campusets eget MW-tal eller fullbyggnadsår saknas. Vid osäkert kundöverlapp antas tills vidare inneslutning; båda projekt syns och antagandet märks. `related_project_id` håller en möjlig dubblett synlig utan ett extra MW-bidrag innan identiteten lösts.

Befintlig drift är inte ny utbyggnad. En jämförbar känd bas subtraheras före PUE-omräkning. Okänd bas ger 0 till möjlig ram för tillskottet; kända nya etapper kan höja den lägre nivån. Detta är bokföringsgränser utifrån tillgängliga fakta, inte skattade sannolikheter. Avbrutna projekt kvarstår som historik. Felattribuerade siffror och reservkraft får inte bli datacenterlast, men projektet behålls.

### Energi, tolkning och täckning

Årlig användningsfaktor beror på anläggningstyp (`config/pipeline.json` → `type_assumptions`, gemensamt för samtliga resultat): hyperskala 0,75 och colocation 0,57 relativt nameplate, 0,94 respektive 0,88 relativt explicit topp ([EPRI 2026, s. 15](https://powering-intelligence.epri.com/annual-peak-use.html)). Colocation/AI 0,60 och AI/HPC 0,80 är egna bedömningar; AI/HPC-värdet vilar på LBNL:s driftstid för AI-servrar, som inte är en anläggningsfaktor, och är tabellens svagaste värde. Projekt utan typ får intervallet 0,57–0,75 (0,88–0,94 mot topp). Faktorerna bygger på ett litet amerikanskt anläggningsurval och är inte universella nordiska lastfaktorer. Infasning tillämpas en gång. Ingen extra beläggnings-/mognadsrabatt läggs ovanpå den. Ingen timprofil, samtidighetsprognos eller nätanslutningsgaranti räknas fram här.

Summeringar visar den kvantifierade delen och antal projekt utan användbart MW. Okänt elområde ligger i landets `unassigned`. Projekt utan MW är inte nollförbrukare. Alla registrerade projekt får en indikator i varje scenario, men detta bevisar inte fullständig marknadstäckning.

Kontrollen och landspaketet lyfter också källutdrag med MW/GW som ännu saknar en motsvarande användbar kapacitetsobservation på samma projekt. Det fångar källor som annars bara blivit liggande på en kandidat. Det är ett sökstöd för automatisk uppföljning, inte en garanti för att alla tal i en källa är korrekt tolkade. Det blockerar inte befintliga beräkningar eller tar bort projekt. Uppdateraren följer upp dessa träffar och samtliga projekt utan MW, enligt `prompts/update.md`.

## Standardiserad inventering

En inventering körs ett land i taget i Codex (Sverige, Norge, Finland). Startprompterna finns överst i `prompts/update.md`; klistra in den för landet i en ny session. Agenten kör `prepare`, söker, går igenom arbetslistan, kör `apply` och redovisar, men committar inte.

Mellan länderna (för dig):

1. Läs redovisningen i chatten och körloggen i `runs/`.
2. Granska `git diff data/` (registret) och `git diff assets/data/datacenters/scenario_zone.json` (sajtens zonsummor).
3. Granska kandidaternas källuppgifter och MW/TWh-bidrag per scenario i chatten. Godkänn uttryckligen valda projekt-ID:n här, exempelvis ”Godkänn P039 och P055”. Agenten inför bara dessa med `approve` och uppdaterar samtliga resultat samt den lokala sajten när dess checkout finns bredvid pipelinen. Övriga förblir kandidater.
4. Granska och committa ändringarna. Publicering görs separat på din instruktion. Starta nästa land i en ny session.

| Steg | Fast uppgift |
| --- | --- |
| Prepare | Spara en daterad lägesbild och skapa arbetskopior av de fyra tabellerna samt ett paket med instruktion, landsprofil, utgångsdata, identitetsindex, ID-gränser och arbetslista. Aktörsrader följer med. Separat aktörsinventering styrs av prompts/actors.md. |
| Discover | Sök brett i landet via operatörer, plan/tillstånd, nät, branschpress och landssökning, på alla angivna språk. |
| Audit | Följ upp varje befintligt och nytt projekt och alla kapacitetsuppgifter; klassa MW efter ordalydelse; arbeta igenom arbetslistan. |
| Reconcile/review | Stäm av projekt och MW mot resultatet, granska ändringar, gör en andra sök-/granskningspassage och följ upp bortfall. |
| Apply/report | Inför källinventeringen, bygg godkända resultat och redovisa per elområde/scenario samt kandidaternas villkorade effekt i chatten. |
| Manuellt godkännande | Användaren godkänner namngivna kandidater här i chatten; agenten ändrar bara dessa och bygger om samma beräkning för chatten och sajten. |

Agenten genomför hela processen enligt `prompts/update.md`; användaren behöver inte fördela projekt eller starta varje delsteg. `scratch` börjar med tomma arbetsregister för valda länder och stämmer senare av mot tidigare identiteter; tidigare observationer försvinner inte bara för att bredsökningen missade dem.

Miljön är låst i `renv.lock`; återställ vid behov med `Rscript -e 'renv::restore()'`. Agentens gemensamma ingång är:

```sh
Rscript scripts/pipeline.R prepare --country=SE --mode=refresh
# Efter källarbete och granskning, använd arbetskatalogen som prepare skrev ut:
Rscript scripts/pipeline.R check --data=/sökväg/till/arbetskatalog
Rscript tests/method.R
Rscript scripts/pipeline.R apply --data=/sökväg/till/arbetskatalog
Rscript scripts/pipeline.R check
```

`prepare` kopierar först de fyra aktuella CSV-filerna i `data/` till `runs/snapshots/ÅÅÅÅ-MM-DD-<land>-before-discovery/data/`. Därefter skapar kommandot fyra arbetskopior och ett packet.json i en unik tillfällig katalog. Sökvägen till den daterade datakopian finns i paketets `baseline_snapshot`. En identisk kopia återanvänds. Om data har ändrats samma dag skapas ett numrerat namn, så en tidigare kopia aldrig skrivs över. Kopian används inte av modellen och ändrar inte registret.

Paketet innehåller också svenska/norska/finska sökord, måttbegrepp, källvägar och språkkrav från de tidigare landsprofilerna samt aktörsinstruktion och projektlista. Metodens källdatum i konfigurationen är inte bevis på en ny inventering. Paketet och det införda resultatets inventory_run anger kapacitetskörningens datum och länder. Aktörernas granskning har egna checked_at-datum och täckningsuppgifter.

`check --data=...` validerar arbetskopian och visar luckor/ändringar. Vanlig `check` kontrollerar dessutom att sparade analys- och sajtfiler motsvarar dagens register och modell, inklusive den lokala sajtkopian när den finns. Saknade eller inaktuella filer ger fel; kör `build` efter metodändringar eller vid första installationen. `apply` kontrollerar utgångsläge, bevarade ID:n, godkännandestatus och landsavgränsning och inför tabeller och resultat tillsammans. Vanliga skrivfel återställer tidigare filer; ett avbrutet system under införandet behöver kontrolleras innan arbetet fortsätter. Sökningens kvalitet bedöms i promptens granskningssteg.

För fristående, läsande förberedelse och beräkning finns även:

```sh
Rscript scripts/pipeline.R packet --country=FI --output=/tmp/fi-packet.json
Rscript scripts/pipeline.R check
Rscript scripts/pipeline.R build --output=/tmp/datacenters-preview.json
Rscript scripts/pipeline.R tracker --output-dir=/tmp/tracker-preview
```

Varken paketförberedelse, kontroller eller `build` utför webbinventering. Agenten behöver fungerande sök-/läsverktyg för den delen. En omräkning av gamla data får aldrig presenteras som en ny inventering. Standardresultatet är en JSON med register, metod, projekt/scenarier, täckning och karta. Ingen extern publicering sker.

## Avgränsning

Registret gäller ny datacenterlast. Ett projekt registreras när det har en identifierad plats, en namngiven datacenteraktör eller slutkund, ny kapacitet (nybygge eller belagd utbyggnad) och ett platsspecifikt belägg utöver marknadsföring (markavtal, plan, MKB/YVA, tillstånd, nätavtal eller byggnation). Driftanläggningar utan utbyggnad, datacenterfärdig mark som marknadsförs utan aktör, konceptstudier utan operatör och projekt utan plats hör inte dit; sådana spår noteras i körloggen. `record_type=out_of_scope` är rader som redan fanns men inte uppfyller regeln: de behåller ID och källor för identitetsmatchning men räknas aldrig, syns inte på sajten och ger ingen arbetslista. En körning kan flytta kandidater dit; godkända projekt flyttas bara på ditt beslut med `exclude --ids=... --reason=...`.

En inventering ändrar bara registret, körloggen, den daterade lägesbilden och de utdata som byggs av flödet. Kod- och metodändringar görs i separata sessioner och committas för sig. `prepare` vägrar starta på ett repo med ocommittade ändringar.

## Kandidater och manuellt godkännande

`record_type=candidate` betyder att användarens godkännande väntar, oberoende av projektets byggstatus. `existing` är det befintliga interna värdet för en manuellt godkänd post; det betyder inte driftsatt. Byggstatus och kapacitetsradens genomförandebeslut är källuppgifter och ändras inte vid godkännande.

Agenten skapar ett aktuellt beslutsunderlag:

```sh
Rscript scripts/pipeline.R review --country=SE --output=/tmp/se-review.json
```

Det visar per kandidat käll-MW, netto/ram, infasad kapacitet och TWh per scenario, källa och effekt på landets godkända totalsumma om just den kandidaten godkänns. Okänt MW förblir okänt. Effekter för överlappande kandidater får inte summeras mekaniskt; ett kombinerat godkännande räknas om tillsammans. Underlaget är en tillfällig körfil, inget ytterligare register.

Agenten presenterar underlaget här i chatten och inväntar uttryckligt godkännande av ID:n. Först därefter kör agenten exempelvis:

```sh
Rscript scripts/pipeline.R approve --ids=P039,P055 --review=/tmp/se-review.json
```

Kommandot kontrollerar att underlaget fortfarande gäller, ändrar enbart valda kandidater till `existing` och bygger godkända analys- och sajtfiler tillsammans med samma modell. Den lokala sajtkopian ingår när den finns enligt nedan. Hela filändringen återställs vid ett normalt installationsfel. `apply` får varken godkänna nya projekt eller återkalla befintliga godkännanden. Byggstatus kan uppdateras med källstöd utan att godkännandet ändras. Kommandot kan inte verifiera en mänsklig chatt; agenten får anropa `approve` endast efter användarens uttryckliga godkännande här. Kör därefter `check` och redovisa de faktiska MW/TWh-ändringarna.

## Koppling till trackern (dfornis.github.io)

`assets/datacenters.json` innehåller registret, godkända scenariototaler och en indikator för varje projekt. Väntande kandidater är tydligt markerade och påverkar inte de godkända totalerna. `assets/data/datacenters/results.json` är samma beräkning filtrerad till godkända projekt, källor och indikatorer för sajten.

`projects.json`, `capacity.json`, `scenario_zone.json`, `timeline.json` och `bidding_zones.geojson` finns kvar som formaterade vyer av samma resultat. Råkapaciteten är källans observationer, inte en separat scenarioberäkning. Inga gamla punktvärden räknas fram. Godkända projekt utan MW eller geografi behålls; okänt elområde redovisas i landets `unassigned`. Drift/vilande/avbrutna projekt behålls som indikatorer medan modellen avgör deras eventuella nya kapacitet.

`web/datacenter-tracker.md` och `assets/js/datacenter-tracker.js` är den gemensamma visningen. Tabellen och kartan läser färdiga projekt/scenariovärden ur `results.json`. Webbläsaren får filtrera och summera dessa men räknar ingen egen PUE, infasning, scenariokvalificering eller avdubbling. Intervall visas som intervall; kartfärgen använder uttryckligen det övre värdet. Käll-MW, tillkommande kapacitetsram och infasad kapacitet hålls isär.

```sh
# Bygg resultat och uppdatera även syskonkatalogen ../dfornis.github.io när den finns:
Rscript scripts/pipeline.R tracker
# Om sajtens checkout ligger någon annanstans, ange samma sökväg vid införande och kontroll:
Rscript scripts/pipeline.R tracker --site=/sökväg/till/dfornis.github.io
Rscript scripts/pipeline.R check --site=/sökväg/till/dfornis.github.io
```

`apply`, `approve`, vanlig `build` och `tracker` använder samma införande: register, analys, sajtunderlag och den lokala sajtens filer uppdateras tillsammans. Syskonkatalogen `../dfornis.github.io` hittas automatiskt. För annan plats används `--site=...` på dessa kommandon och på `check`. Saknas en lokal checkout byggs bara pipelinens filer; ingen publicering sker. Sajtens `scripts/build_datacenter_data.R` och `scripts/build_datacenter_timeline.R` delegerar till samma ingång. Årsexporten byggs, införs och kontrolleras i samma transaktion som övriga resultat. Grafens mall, JavaScript och stil har sin gemensamma källa i pipeline-repot; ingen separat årsexport behöver köras efter registerändringar.

Förhandsvisningar kräver egen destination: `build --data=... --output=/tmp/preview.json` eller `tracker --data=... --output-dir=/tmp/tracker-preview`. De får inte skriva över aktiva resultat eller kombineras med `--site`. Utan `--data` kan samma alternativ användas för en fristående kopia av registret. `apply --output=...` ger en extra kopia och uppdaterar fortfarande alla ordinarie resultat. Ingen av dessa åtgärder committar eller pushar något.

## Status och historik

Metod **4.1.1** (18 oktober 2026) räknar minimiuppgifter som angivet MW med vanlig måttomräkning, inför uppföljning av motsägande inneslutning och fördelar båda härledda campusförloppen linjärt till 2035. Endast datacenterkapacitet kan utlösa campusregeln. Egna källdatum, Low-urval, Highs fulla utbyggnad och hanteringen av nätdatum och inaktuella mål behålls. Ingen ny källsökning eller godkännandeprocess ingår. [Jämförelse per regel, projekt, land och elområde](runs/2026-10-18-method-4.1.1.md).

Metod **4.1** (18 oktober 2026) sätter High 2035 lika med full utbyggnad, inför ett explicit Stated-urval för odaterade campus med genomförandeetapp, tar bort nät-MW-tak, räknar minimiuppgifter med öppen övre gräns och skiljer inaktuella mål från aktuella tidsankare. Typtaggen `AI/HPC` normaliseras till `AI; HPC`; parsern accepterar båda. Detta är en metodändring av befintligt underlag, ingen ny inventering. [Jämförelse och tillämpning](runs/2026-10-18-method-4.1.md).

Metod 4.0 (18 oktober 2026) inför separata käll-/modellår, genomförandebaserade ledtider, begränsad bakåträkning, explicit nätkoppling, fast historisk bas och integrerad årsexport. Undantaget som lät en okvantifierad etapp datera hela ramen är borttaget. Detta är metodutveckling och omräkning av samma källfakta; vid metodens införande var kompletteringen förberedd. Därefter genomfördes landskompletteringarna och de separat godkända kandidatbesluten före 4.1.

Metod 3.5 (oktober 2026) daterar bara de MW-tal källan daterar, ger etapper under genomförande utan MW spannet 0 till ramen, lägger till elanvändning vid full utbyggnad och döper om sajtens kolumner. Metod 3.4 (oktober 2026) inför avgränsningsregeln, `out_of_scope`, `exclude` och kravet på committat utgångsläge före en landskörning. Metod 3.3 (oktober 2026) ersätter den separata äldre sajtberäkningen med den gemensamma modellen. Manuellt kandidatgodkännande här i chatten styr nu godkända totalsummor i samtliga resultat. Detta är en flödesändring och omräkning av befintliga källuppgifter, inte en ny webbinventering. Metod 3.2 införde intervallet för ospecificerat MW och typberoende årsenergifaktorer.

Tidigare underlag och körningshistorik finns i Git, bland annat `9779acc`. Behåll stabila ID:n; nya löpnummer ska ligga över högsta använda nummer även i historiken. Utdataformat 3.1 återställer ursprungliga scenario-ID:n och skiljer nameplate från infasad kapacitet. Det saknar en femte potential-scenariofamilj. Kartornas ursprung/återanvändningsrätt är olösta och koordinaterna är ungefärliga visningspunkter.
