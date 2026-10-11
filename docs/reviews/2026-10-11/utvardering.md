# Utvärdering inför nya landskörningar

Bedömning den 11 oktober 2026 av datacenter-tracker-pipeline, inklusive den aktuella arbetskopians ändringar och filer som ännu inte är versionshanterade.

**Rekommendation: behåll grundarkitekturen, men åtgärda dataintegriteten och fastställ scenariometoden innan nästa fullständiga körning för Sverige, Norge och Finland.** Projektet är en användbar grund för ett källbaserat register över offentliggjorda datacenterplaner. Nuvarande utdata är däremot inte tillräckligt säkra för att utan förbehåll beskrivas som prognoser över installerad effekt eller faktisk elförbrukning 2030 och 2035.

De mest betydelsefulla problemen är felkopplade finska källposter, otillräcklig kontroll vid införande av granskade ändringar, sammanblandning av byggstart och driftsättning, bortfall av utbyggnader vid anläggningar i drift samt ofullständig hantering av överlappande kapacitet. Mer sökning med oförändrade instruktioner skulle förstora dessa problem.

## Omfattning och verifiering

Hela filträdet utanför Git har inventerats: 495 filer, varav nio `.DS_Store` och 486 innehållsfiler. Granskningen omfattar samtliga fyra R-skript, aktuell och arkiverad dokumentation, alla promptar och landstillägg, åtta huvudtabeller, sju granskningsfiler, två granskningsarkiv, genererade data och äldre utdata. Alla CSV-tabeller har lästs. Samtliga 449 GeoJSON-filer har kontrollerats för läsbar JSON, koordinatintervall och slutna polygonringar. Det är inte en oberoende geografisk verifiering av varje gräns.

| Land | Projekt i huvuddata | Kapacitetsuppgifter | Projekt i publicerade JSON | Kapacitetsuppgifter i publicerade JSON |
| --- | ---: | ---: | ---: | ---: |
| Sverige | 15 | 22 | 14 | 21 |
| Norge | 9 | 11 | 3 | 3 |
| Finland | 14 | 13 | 10 | 10 |
| Totalt | 38 | 46 | 27 | 34 |

Det finns 83 källänkar, 956 administrativa enheter och tio konfigurerade elområden. Senaste registrerade källkontroll är 14 maj 2026. Danmark och Island ingår inte i nuvarande landkonfiguration trots benämningen Nordic.

Alla sex kombinationer av land och uppgift kunde generera promptar. Beräkningsdelen kördes i en separat kopia och återskapade innehållet i `projects.json`, `capacity.json` och `scenario_zone.json` exakt. Fullständig ordinarie körning stoppades av att `sf` saknas i den aktiva R 4.6-miljön. En äldre installation av paketet kunde inte laddas kompatibelt. Kartgenereringen är därför inte verifierad genom en full körning; den har kodgranskats och befintliga geometrier har strukturkontrollerats.

Felprov gjordes i den separata kopian. Negativ kapacitet, okänd kapacitetstyp, dubblerat kapacitets-ID och en källänk till obefintliga ID:n accepterades alla av beräkningsdelen. En provkörning av svenska kapacitetsändringar rapporterade framgång, medan faktisk tillämpning i kopian avbröts på ett redan genomfört förslag.

Litteraturjämförelsen använder forskningsartiklar, forskningsrapporter och dokument från berörda nätaktörer. Ett urval projektkällor öppnades för att kontrollera centrala tolkningsproblem. Detta är en genomgång av systemet och dess data, inte en genomförd ny faktauppdatering av varje projekt eller en kontroll av tillgängligheten för alla 83 registrerade källänkar.

## Det som bör behållas

- Åtskillnaden mellan projekt, kapacitetsuppgifter och källor är riktig. Ett investeringsbeslut för en första etapp ska inte automatiskt gälla hela campuset.
- Separata arbetssteg för granskning av befintliga poster och upptäckt av nya är lämpliga.
- Huvuddata, granskningsförslag och genererade utdata ligger åtskilda. CSV och R är fullt tillräckliga för denna storlek; en databas eller en ny agentplattform är inte en förutsättning.
- Gemensamma promptmallar med landstillägg minskar risken för att länderna använder olika definitioner.
- Kommun- och regionreferenser från statistikmyndigheterna samt uttryckligen ungefärliga kartpunkter är bra val.
- Reglerna mot att omvandla reservkraft, reaktoreffekt, investeringar eller GPU-antal direkt till IT-last bör behållas.

## Ändringar som behöver föregå en full landskörning

### 1 Återställ korrekta källkopplingar och stabila identiteter

**Prioritet: stoppar nästa körning. Bekräftat datafel.**

Källposterna S044–S056 följer en tidigare finsk projektindelning som inte längre stämmer med projekttabellen. Exempelvis kopplas S044, vars utdrag beskriver Microsoft Espoo, till P025, som nu är Borealis Kajaani. S047 beskriver Google Hamina men pekar på Microsoft Vihti. S056 beskriver CSC LUMI-AI men pekar på XTX Kajaani. Senare poster innehåller motsvarande källtexter med korrekta projektlänkar.

Arkivet visar 13 äldre tilldelningar av projekt-ID:n som motsägs av nuvarande huvuddata. Det stödjer förklaringen att en tidigare import delvis gjorts om. Den exakta historiska händelsekedjan går inte att fastställa enbart från nuvarande filer.

Vanlig kontroll av att ett ID existerar skulle inte hitta detta: ID:n existerar, men avser fel anläggningar. En LLM som följer instruktionen att börja med registrerade källor kan därför få fel plats, operatör och status presenterade som granskad evidens.

Åtgärda genom att stämma av hela FI-importen mot arkivet, markera den äldre importen som ersatt och rätta eller avveckla felaktiga källrelationer med dokumenterad historik. Behåll nuvarande projekt-ID:n där de går att bevara. ID-tilldelningen måste även minnas historiskt använda ID:n; dagens `max(existerande ID) + 1` kan återanvända borttagna identifierare.

Underlag: [källregistret](/Users/fornborg/Documents/GitHub/datacenter-tracker-pipeline/data/master/sources_master.csv:45), [projektarkivet](/Users/fornborg/Documents/GitHub/datacenter-tracker-pipeline/data/audit/archive/promoted_new_project_candidates.csv:2) och [ID-tilldelningen](/Users/fornborg/Documents/GitHub/datacenter-tracker-pipeline/scripts/promote_review_rows.R:87).

### 2 Gör införandet av ändringar validerat och spårbart

**Prioritet: stoppar nästa körning. Bekräftade datafel och brister i arbetsflödet.**

Av 30 kvarvarande svenska kapacitetsförslag har 26 redan samma värde i huvuddata som sitt föreslagna värde. Bara AC001–AC004 återstår som direkt tillämpbara kapacitetsförslag; dessutom finns två projektförslag. En ny granskning måste kunna skilja genomfört, öppet, avvisat och ersatt.

Provkörningen av ändringar avbryts före kontrollen av nuvarande värden. Därför upptäcker den inte att AC005 förväntar sig `Planned` för C019 trots att huvuddata redan säger `Operational`. Att använda `--force` för att komma vidare skulle kringgå just den kontroll som behövs.

När en auditändring införs uppdateras projekt- eller kapacitetstabellen och granskningsarkivet, men inte källregistret. Ett separat prov med AP001 bekräftade att källfilen förblev identisk. Nya evidenslänkar följer alltså inte automatiskt med till det register som nästa granskning och uppdateringsdatum bygger på. Skriptet saknar också stöd för införande av `suggested_source_updates.csv`.

Kandidatinförandet kallas atomärt, men skriver projekt, kapacitet och källor i tre efterföljande skrivningar. Ett avbrott kan lämna dem i olika tillstånd. Vidare fyller det automatiskt `supports_fields` med en bred standardlista, oavsett vilka fält det faktiska utdraget stöder. Okända domäner klassificeras normalt som företagskällor.

Inför följande:

- Samma fullständiga förkontroll för provkörning och faktisk tillämpning, inklusive jämförelse med aktuella värden.
- Granskningsstatus, granskare, tidpunkt och körnings-ID samt uttryckligt urval av godkända rader.
- Samordnad hantering av ändringen, dess evidens och ersättningshistorik.
- Skrivning till en mellanversion som valideras i sin helhet innan den blir aktuell, med återställning vid fel.
- Återkörning som inte skapar ytterligare poster eller återinför gamla förslag.
- Fältspecifikt källstöd och källtyp som granskade uppgifter; ingen generell företagsklassning för okända källor.

Underlag: [auditinförande](/Users/fornborg/Documents/GitHub/datacenter-tracker-pipeline/scripts/promote_review_rows.R:200), [automatiska källfält](/Users/fornborg/Documents/GitHub/datacenter-tracker-pipeline/scripts/promote_review_rows.R:450) och [successiva filskrivningar](/Users/fornborg/Documents/GitHub/datacenter-tracker-pipeline/scripts/promote_review_rows.R:486).

### 3 Definiera vad scenarierna faktiskt mäter

**Prioritet: metodbeslut före nästa körning.**

Nu blandas offentliggjorda planer, genomförandemognad, möjlig nätlast och årsenergi i samma scenarier. Välj en tydlig redovisning av tre separata resultat:

| Resultat | Innebörd |
| --- | --- |
| Offentliggjord projektportfölj | Dokumenterad kapacitet, inklusive osäker och odaterad potential, med tydlig grund och status. |
| Kapacitet i drift vid ett målår | De etapper som enligt specificerade antaganden kan vara driftsatta då. |
| Elenergi under målåret | Driftandel av året, faktiskt utbyggd kapacitet och användning under året. |

Fastställ också om måttet är nytillkommande kapacitet efter ett basdatum eller all kapacitet i drift vid målåret. Nuvarande modell tar bort redan operativa poster men kan samtidigt räkna hela framtida campustotaler som inkluderar befintlig kapacitet. Det blir ingen entydig stock eller tillkommande volym.

Benämningen `low_2030` bör beskriva ett villkorat scenario med dokumenterade åtaganden, inte ett statistiskt golv eller en garanterad leverans. `high_2035` saknar i dag tidsgräns i urvalet: även en uppgift med känd start efter 2035 kan komma med. En odaterad portfölj bör antingen redovisas utan målår eller få öppet redovisade antaganden om genomförande före 2035.

IEA:s rapport från april 2026 behandlar nät- och leveranskedjebegränsningar samt alternativa anslutningslösningar. Den ger stöd för att modellera genomförandevillkor, men inte för en universell sannolikhet att ett enskilt nordiskt projekt realiseras. [IEA, Key Questions on Energy and AI](https://www.iea.org/reports/key-questions-on-energy-and-ai/executive-summary).

### 4 Skilj byggstart från driftsättning och första etapp från full utbyggnad

**Prioritet: före nästa körning. Bekräftat metodproblem med konkret resultatpåverkan.**

`scenario_time_year()` väljer det tidigaste av driftsättningsår och byggstartsår. Ett prov med byggstart 2029 och driftstart 2034 gav 2029 och gör därmed kapaciteten valbar till 2030. Detta följer nuvarande dokumentation, så både kod och metodtext behöver ändras tillsammans.

Ett befintligt exempel är Nebius Lappeenranta, C040: hela 310 MW räknas i Finlands låga 2030-scenario. Den registrerade företagskommunikationen säger att den första kapaciteten ska bli tillgänglig 2027; den daterar inte därmed hela 310 MW till det året. Posten står för cirka 68 procent av modellens nuvarande finska låga scenario på 457 MW. Det visar varför en etapptolkning är avgörande, men är inte i sig ett belägg för vilket korrigerat MW-värde som ska användas. [Nebius företagsmeddelande den 31 mars 2026](https://www.nasdaq.com/press-release/nebius-construct-310-mw-ai-factory-finland-2026-03-31).

Instruktionen att använda källdatum eller läsdatum som byggstartsår gör dessutom en observation till en historisk händelse. Att byggnation observeras 2026 visar inte att den började 2026.

Inför skilda uppgifter för faktisk eller planerad byggstart, observation av byggnation, första driftsättning, full utbyggnad och datumprecision. Spara intervall och kvartal när källan anger dem. Odaterad full utbyggnad ska inte få första etappens år genom arv. Modellera etappvis infasning där källor finns; använd uttryckligt märkta alternativ där de saknas.

Regen och National Grid DSO beskriver etappvis utbyggnad över flera år och använder sådan information i modelleringen. Det stöder ändringen, men deras brittiska intervjuexempel ska inte bli automatiska byggtider för Norden. [Data Centre Impact Study, 2025, sidorna 27–28](https://dso.nationalgrid.co.uk/downloads/15083/data-centre-impact-study2.pdf).

Underlag: [val av scenarioår](/Users/fornborg/Documents/GitHub/datacenter-tracker-pipeline/scripts/build_datacenter_data.R:631), [scenariourval](/Users/fornborg/Documents/GitHub/datacenter-tracker-pipeline/scripts/build_datacenter_data.R:683) och [tidstolkning i auditprompten](/Users/fornborg/Documents/GitHub/datacenter-tracker-pipeline/prompts/audit_template.md:121).

### 5 Bevara framtida utbyggnader på operativa anläggningar

**Prioritet: före nästa körning. Bekräftat bortfall.**

Koden tar först bort alla projekt med status `Operational` och därefter deras kapacitetsposter. Därmed försvinner C026, Hamar 150 MW fullcampuspotential, och C031, Lefdal 200 MW potential, trots att båda kapacitetsposterna är `Planned`.

Gör urvalet på etappnivå och låt en anläggning samtidigt ha operativa och framtida etapper. För en modell av tillkommande kapacitet måste framtida totaler reduceras med en kompatibel basnivå. Hamar 150 och 90 MW kan exempelvis ge 60 MW återstående potential om definitionerna är jämförbara och basnivån verifierad. Man ska inte bara släppa igenom hela 150 MW. Lefdals ”available power” behöver motsvarande kontroll innan den används som operativ basnivå.

Underlag: [bortfiltrering via projektstatus](/Users/fornborg/Documents/GitHub/datacenter-tracker-pipeline/scripts/build_datacenter_data.R:674) och [de norska kapacitetsposterna](/Users/fornborg/Documents/GitHub/datacenter-tracker-pipeline/data/master/capacity_master.csv:25).

### 6 Gör fysisk identitet och överlapp maskinläsbara

**Prioritet: före nästa körning. Bekräftad begränsning och stark dubbelräkningsrisk.**

Avdubbling sker bara inom samma `project_id`. EcoDataCenter Borlänge P003 och Mistral/EcoDataCenter P010 summeras var för sig. Företagets meddelande placerar Mistrals anläggning på EcoDataCenters Borlängesite. Det är starkt stöd för ett gemensamt fysiskt sammanhang, men källan avgör inte ensam exakt hur 23 MW förhåller sig till alla andra MW-tal. Relationen måste granskas innan summan används. [EcoDataCenter den 11 februari 2026](https://ecodatacenter.tech/press/mistral-ai-and-ecodatacenter-partner-to-build-ai-focused-data-center-in-sweden-3431886).

Även inom ett projekt är ”största total vinner” en grov regel. Den kan dölja en senare nedrevidering eller välja ett gammalt 100 MW-campustak framför en ny 200 MW-etapp. Ett funktionsprov med just dessa storlekar valde 100 MW. Två självständiga byggnader som båda anges som `facility_capacity` kan i stället reduceras till bara den största.

Behåll källornas kapacitetspåståenden separat från den fysiska etapp som modelleras. Inför exempelvis `physical_site_id`, etapp-ID, `overlap_group_id` och relationer som ingår i, tillkommer till, ersätter eller alternativ till. Lägg till giltighetsperiod och markering av vilken tolkning som gäller. Ett kundavtal kan vara separat evidens utan att bli ett ytterligare fysiskt campus i summorna.

Publicera en förklarande beräkningstabell med vilka poster som räknades, vilka som uteslöts och varför. Den mellanliggande tabellen finns redan i minnet som `scenario_counted_rows`, men exporteras inte.

Underlag: [val av summeringsposter](/Users/fornborg/Documents/GitHub/datacenter-tracker-pipeline/scripts/build_datacenter_data.R:735).

### 7 Skilj kapacitetsmått och gör energiomräkningen villkorad

**Prioritet: före nästa körning av scenarier.**

Att bevara `reported_capacity_basis` är bra. Däremot behandlar modellen total anläggningseffekt, nätanslutning och otydliga MW-rubriker likadant. `grid_connection` rymmer både ansökt, reserverad, avtalad och tillgänglig kapacitet utan separata statusfält.

För dessa rader divideras MW med PUE och multipliceras sedan med samma PUE för att få nätlast. Om ingen manuell överstyrning finns tar PUE ut sig: nätlasten blir exakt det ursprungliga MW-talet. Årsenergin blir sedan detta tal gånger en generell lastfaktor och 8 760 timmar. Beräkningen kan beskriva ett villkorat utnyttjande av ett kapacitetstak, men divisionen med PUE gör inte resultatet till en försiktig prognos över faktisk förbrukning.

14 av 34 publicerade kapacitetsrader har `unspecified_headline`. Dessa bör behållas som observerade uppgifter, men deras oklara innebörd behöver synas i resultaten. Om de är med i ett scenario måste det framgå vilken antagen tolkning som används och hur känsligt resultatet är för den.

En källa kan legitimt ange både IT-kapacitet och total effekt för samma etapp. Då bör båda observationerna lagras med en uttrycklig icke-additiv relation. Nu försvinner sådan information ofta till anteckningar: C042 anger exempelvis 100 MW IT medan källutdraget även anger cirka 130 MW total effekt; modellen använder i stället standard-PUE 1,2 och räknar 120 MW. Källans avgränsning måste granskas, men det andra måttet ska inte gå förlorat. Detsamma gäller 28 MW IT och cirka 40 MW elförsörjning för Conapto.

Lägg till mått, enhet, systemgräns, kvalificering som ”upp till” eller ”minst”, samt nätanslutningens stadium och villkor. Skilj MW elektrisk effekt från MW termisk effekt; Horndals 1 500 MWth ligger nu i ett generellt MW-fält även om text och undantagsregler hindrar IT-omräkning.

En transparent energimodell kan utgå från IT-kapacitet gånger användning och PUE, eller från nätkapacitet gånger en lastfaktor definierad mot just nätkapaciteten. Använd sedan en tidsprofil eller infasningsandel endast om den inte redan ingår i lastfaktorn. Separera årsmedeleffekt från sammanfallande topplast i elnätet. Undvik att både beläggning och lastfaktor råkar innehålla samma nedskalning.

LBNL:s *2025 Update*, publicerad i juni 2026, skiljer uttryckligen mellan nätanslutning, märkkapacitet, maxeffekt och medeleffekt och beskriver osäkerheten i omräkningen. Rapportens 80 procent för AI-träning är serverutnyttjande, inte en direkt uppmätt nordisk lastfaktor för en hel anläggning. Därför räcker hänvisningen i `LF_AI_HPC` inte för att validera värdet 0,80 på anläggningsnivå. [Smith med flera, 2026, särskilt sidorna 9–10 och 20–22](https://www.energy.gov/documents/united-states-data-center-energy-usage-report-2025-update).

EPRI anger 75 procent relativt märkkapacitet för den observerade hyperskaleanläggningen och 57 procent i genomsnitt för de mindre samlokaliseringsanläggningarna. Det är relevant empiriskt stöd, men inte en generell skattning för varje nordiskt projekt eller för alla slags anslutningskapacitet. Behåll värdena som prövbara antaganden med intervall, definition av nämnaren och källans urval. [EPRI, Annual and Peak Electricity Use, 2026](https://powering-intelligence.epri.com/annual-peak-use.html).

Underlag: [omräkningen](/Users/fornborg/Documents/GitHub/datacenter-tracker-pipeline/scripts/build_datacenter_data.R:489) och [antagandetabellen](/Users/fornborg/Documents/GitHub/datacenter-tracker-pipeline/data/master/assumptions.csv:2).

### 8 Rätta typklassning och skilj AI-användning från affärsmodell

**Prioritet: före nästa scenariokörning. Bekräftat kod- och datafel.**

Koden känner igen taggarna `AI` och `HPC` men inte `AI/HPC`. Nio finska kapacitetsposter använder den senare formen. `AI/HPC; cloud` och `AI/HPC; enterprise` faller tillbaka till `Hyperscale`, medan `colocation; AI/HPC` blir vanlig `Colocation`. Bland annat C040 och C043 får därför andra antaganden än vad deras beteckningar antyder.

Normalisera befintliga taggar och validera tillåtna värden. Ersätt sedan den sammanblandade listan med separata dimensioner: affärsmodell, arbetslast och eventuell kylteknik. AI-träning, inferens, vetenskaplig HPC och okänd AI-användning behöver kunna skiljas åt utan att allt görs till en känd energiprofil. Ett marknadsfört AI-ready-campus visar inte att hela kapaciteten används för LLM-träning.

Låt okänd typ förbli okänd eller använda ett redovisat osäkerhetsintervall. Tyst standardklassning till hyperscale ger ogrundad precision. Möjligheten att ange källbelagd PUE per etapp bör också finnas, med uppdelning mellan designvärde och uppmätt värde. FIN04:s aktuella webbplats anger exempelvis PUE högst 1,2, medan standardklassningen använder 1,35; designvärdet är i sin tur inte ett bevis på faktisk års-PUE. [atNorth FIN04](https://www.atnorth.com/nordic-data-centers/finland-data-centers/myllykoski-mega-site/).

Underlag: [klassningsfunktionen](/Users/fornborg/Documents/GitHub/datacenter-tracker-pipeline/scripts/build_datacenter_data.R:446).

### 9 Förtydliga investeringsbeslut och bevisvärdering

**Prioritet: metodregler före nya bedömningar.**

`investment_decision = no` betyder i dag ofta att ett beslut inte har hittats, snarare än att ett uttryckligt negativt beslut finns. `yes` kan samtidigt betyda formellt investeringsbeslut, byggstart eller en tolkning av avtal. Två signaler från ett och samma pressmeddelande riskerar att uppfattas som oberoende bevis.

Behåll en sammanfattande klassning om den behövs för visning, men komplettera med beslutsgrund: uttryckligt beslut, belagd genomförandestart, indirekt åtagande, inget offentligt belägg eller uttryckligt avvaktan/avslag. Ett tidsatt, villkorat kundavtal ska inte utan vidare likställas med oåterkalleligt beslut att bygga hela campuset.

Gör källhierarkin fältspecifik. Företaget är en viktig källa för avsikt och kommersiell omfattning, tillståndsmyndigheten för beslutad tillståndsstatus och nätägaren för anslutningsvillkor. Auditpromptens generella rangordning med företagsuttalanden först bör inte avgöra alla konflikter. En tillståndsansökan är inte ett beviljat tillstånd.

Skilj dessutom källans trovärdighet, säkerheten i extraktionen och osäkerheten om framtida genomförande. En korrekt återgiven uppgift om ”upp till 1 GW” kan ha mycket starkt textstöd och samtidigt stor genomförandeosäkerhet. Dagens `confidence` ska inte behandlas som realiseringssannolikhet.

Underlag: [statusreglerna](/Users/fornborg/Documents/GitHub/datacenter-tracker-pipeline/docs/status_rules.md:1) och [källhierarkin i prompten](/Users/fornborg/Documents/GitHub/datacenter-tracker-pipeline/prompts/audit_template.md:57).

### 10 Ge LLM ett avgränsat och mätbart arbetsflöde

**Prioritet: före full landskörning.**

Promptarna är omsorgsfulla men förlitar sig på att modellen ensam håller reda på söktäckning, identitet, semantik, datum, källstöd och CSV-konsistens. Körningarna har ingen sparad specifikation av modellversion, promptversion, brytdatum, indatatillstånd eller genomförda sökningar. Gemensamma utdatafiler och sekventiella modellskapade ID:n ger dessutom konflikt- och överskrivningsrisk vid flera körningar.

Rekommenderat flöde:

1. Skapa ett låst landspaket med berörda poster och deras källor, relevanta administrationsdata, gemensamma definitioner och tydlig uppgift.
2. Sök och registrera söksträng, språk, källa, datum, kandidat samt varför kandidaten tas med eller utesluts.
3. Extrahera bokstavliga uppgifter till ett validerat schema: citat på originalspråk, separat översättning, URL, sida/avsnitt, mått, enhet, datum och vilken anläggning eller etapp texten gäller.
4. Gör tolkningar separat från citaten. Bevara alternativa tolkningar där källan inte avgör saken. Tillåt uttryckligen ”okänt”.
5. Låt deterministisk kod kontrollera struktur, ID:n, enheter och beräkningar. Låt modellen föreslå evidens och tolkning.
6. Granska särskilt stora bidrag, ändringar av identitet, borttagningar och motsägelsefulla källor innan de förs in.

Spara utdata under körning och land, och tilldela stabila ID:n vid kontrollerad sammanslagning. Lägg till en täckningslogg även för poster som inte ändras. Annars betyder noll ändringsrader både ”kontrollerad och korrekt” och ”aldrig granskad”. Lägg också in en regel att instruktioner i hämtade källor ska behandlas som källtext, inte som arbetsorder.

Bygg ett mindre facit med svenska, norska, finska och engelska exempel från detta projekt: IT kontra nätkapacitet, termisk reservkraft, första etapp kontra fullcampus, kund kontra operatör, inaktuella pressmeddelanden och uttryckligt kontra tolkat beslut. Mät korrekt fältextraktion, faktiskt källstöd, upptäckta dubbletter och förmåga att avstå från obelagda slutsatser. Välj sedan modell och arbetsmängd efter uppmätta resultat. En andra modellbedömning kan vara ett stöd, men ersätter inte detta facit eller sakkunnig granskning.

ALCE skiljer faktakorrekthet från kvaliteten på citeringsstödet. Det motiverar kontroll av att varje länk verkligen stöder det specifika fältet. [Gao med flera, 2023](https://aclanthology.org/2023.emnlp-main.398/). NIST rekommenderar verifiering av källor, spårbarhet och dokumenterad utvärdering för generativ AI. [NIST AI 600-1](https://nvlpubs.nist.gov/nistpubs/ai/NIST.AI.600-1.pdf).

Studien *Lost in the Middle* visar problem med hur modellerna i studien använde långa kontexter. Det är ett skäl att testa avgränsade projektpaket, inte ett belägg för att alla modeller 2026 har samma begränsning. [Liu med flera, 2024](https://aclanthology.org/2024.tacl-1.9/). PRISMA-S ger användbara principer för dokumenterade sökningar och avdubbling; de kan anpassas hit utan att projektregistret kallas en systematisk litteraturöversikt. [Rethlefsen med flera, 2021](https://link.springer.com/article/10.1186/s13643-020-01542-z).

### 11 Inför gemensamma datakontroller och versionsbundna leveranser

**Prioritet: före nästa införande av data.**

Valideringen kontrollerar redan bland annat land, elområde, kommun, region och vissa kategorier. Följande behöver också stoppa en leverans: dubbla primärnycklar, brutna relationer, fel land på en länkad post, okända typer, negativa eller orimliga MW, felaktiga numeriska värden, ogiltiga datum, orimlig PUE/lastfaktor och oförenliga tids- eller kapacitetsrelationer. Kontrollen ska användas vid import, provkörning, införande och export.

Fyra befintliga källdatum, S056, S070, S078 och S080, anger bara år eller år–månad. De blir tyst saknade vid datumtolkningen. Spara originaldatum och precision; fyll inte på ett påhittat datum. Separera publicerad, observerad, senast kontrollerad och senast ändrad. Ett gammalt publiceringsdatum ska inte dölja en nylig kontroll, och en kontroll ska inte se ut som ny publicering.

Kontrollera även vad en scenariotagg betyder. Huvudtabellens taggar kastas och räknas om av byggskriptet. Därför påverkar ett granskningsförslag som enbart tömmer taggen inte nödvändigtvis utdata. Dokumentationen kräver dessutom ifylld IT-last för taggning samtidigt som den normalt ska lämnas tom och härledas. Gör taggar helt härledda och skilj visningsrelevans från att kapaciteten faktiskt räknas.

Lås R- och paketversioner, exempelvis med `renv`, och dokumentera systemberoendena. Lägg till en automatisk kontrollkörning och regressionstester för de verkliga feltyperna ovan. Bind varje publicerad leverans till indatahashar, metodversion, antagandeversion, brytdatum och vald beräkningstabell.

Kartfelet ska ge avbruten leverans. Nu skriver skriptet JSON före kartsteget och fångar kartfel utan att låta körningen misslyckas. Om målkartan saknas kan det dessutom kopiera en reservkarta som bara innehåller Sveriges fyra områden. Det kan ge kompletta landtabeller men en ofullständig eller gammal karta.

Underlag: [källdatum](/Users/fornborg/Documents/GitHub/datacenter-tracker-pipeline/scripts/build_datacenter_data.R:582), [ersättning av scenariotaggar](/Users/fornborg/Documents/GitHub/datacenter-tracker-pipeline/scripts/build_datacenter_data.R:814) och [kartexport och reservförfarande](/Users/fornborg/Documents/GitHub/datacenter-tracker-pipeline/scripts/build_datacenter_data.R:894).

## Bedömning av mappar och instruktioner

| Del | Bedömning och föreslagen ändring |
| --- | --- |
| `README.md` | Bra översikt. Lägg till måttdefinition, brytdatum, verifierad körmiljö, obligatoriska kontroller och exakt landsomfattning. Beskriv atomiskt införande först när det är implementerat. |
| `docs/schema.md` och `docs/status_rules.md` | Behåll som huvudreferenser, men centralisera maskinläsbara kategorier och undvik dubblerade metodregler. Rätta tid, operativa projekt, beslut, taggar och energiomräkning tillsammans. |
| `docs/old/schema.md` | Tydligt märkt som gammal, vilket är bra. Behåll i arkiv och uteslut den ur agenternas normala indata. |
| `prompts/README.md`, de två startfilerna och `render_country_prompt.R` | De sex landspromptarna fungerar. Gör renderingen till ett sparat körpaket med versioner och filtrerade indata; undvik att varje agent ska läsa hela projektet. |
| `prompts/audit_template.md` och `discover_template.md` | Behåll uppdelningen. Flytta återkommande definitioner till en gemensam källa. Lägg till täckningslogg, källcitat, datumprecision, avstående vid osäkerhet och skydd mot instruktioner i källmaterial. |
| `prompts/country_overlays/` | Språkstödet är användbart. Generiska ord som finska `kapasiteetti` och svenska `kapacitet` får inte automatiskt betyda total anläggningseffekt. Kräv MW-enhet och sammanhang. Lägg till aktuella register, nätprocesser och sökmatriser. |
| `projects_master.csv` | Bevara stabila ID:n och ett fysiskt sitebegrepp. Lägg till alias, organisationsroller och relation till campus/kundprojekt. Ett odifferentierat max-MW bör inte användas i jämförelser mellan olika kapacitetsmått. |
| `capacity_master.csv` | Behöver uttryckliga etapper, överlapp, basnivåer, mått, enheter och tidsprecision. Separera observerat påstående från modellens granskade tolkning. |
| `sources_master.csv` | Rätta FI-kopplingar. Lägg till exakt källpassage, språk, dokumentversion och relation till det specifika fältet. Arkivera tillåtet underlag eller lagra dokumenthash och locator så att föränderliga webbsidor går att granska i efterhand. |
| `assumptions.csv` | Bra att antagandena är externa. Komplettera med full referens och locator, definition, tillämplig population, intervall och versionshistorik. Lägg till uppmätta eller designbaserade sitevärden utan att blanda dem. |
| `country_config.csv`, `geography_config.csv`, `admin_units.csv` | Bra normaliseringsstöd. Synkronisera de två active-fälten. Använd kommunkoder som nycklar och namn som visning/sökstöd. Dokumentera namnbyten och giltighetsperioder. |
| `municipality_locations.csv` | Lämplig för ungefärlig visning. Lägg till källa och noggrannhet. En kommunpunkt ska inte avgöra faktisk nätanslutning eller exakt elområde nära en gräns. |
| `data/audit/` och `archive/` | Skilj körningar och granskningsstatus. Stäng redan genomförda förslag och markera ersatta importer. Konflikter behöver ID, status och ansvarig upplösning. Tom `dead_links.csv` är inte bevis på att alla länkar fungerar. |
| `build_admin_units.R` | Källvalen är bra. Versionsår och norskt korrespondenstabell-ID är hårdkodade; Sverige hämtas med känslig HTML-tolkning. Kontrollera scheman, fullständighet, antal och differens före ersättning av huvuddata. Spara hämtad referensversion. |
| `build_datacenter_data.R` | Dela läsning, validering, härledning, scenarioavräkning och export i testbara funktioner. Flytta metodval till versionshanterad konfiguration. |
| `promote_review_rows.R` | Kräver ändringarna i punkt 2. Kandidater som behöver nya kartpunkter måste få dem granskade före publicering. |
| `data/zones/` | 442 filer och cirka 26 MB, medan nuvarande konfiguration använder en liten del. Samla tredjepartsgeometrier med ursprung, version, licens och reproducerbart urval. Ingen anledning att ge alla världens polygoner till en landsagent. |
| `data/zones_no_backup/` | Fem parallella norska kartfiler utan dokumenterad återställningsprocess. Märk dem som en daterad tidigare version och förklara skillnaden, eller ersätt dupliceringen med versionshistorik. |
| `assets/data/bidding_zones.geojson` | Är en faktisk indatafil för Sverige trots att `assets` också rymmer utdata. Flytta på sikt till tydlig referensdata och rätta den Sverige-begränsade reservlogiken. |
| `assets/data/datacenters/` | Behåll genererade leveranser. Komplettera med körmetadata, källhänvisningar eller separat evidensexport och förklaring av räknade poster. Nu saknar publika kapacitetsposter direkta källänkar. |
| `assets/projects_scenarios.csv` | Äldre 42-radersfil som inte genereras av nuvarande skript. Nio scenario/kapacitetspar finns där men inte i nuvarande beräkning. Arkivera eller regenerera uttryckligen så att den inte ser aktuell ut. |
| Roten och versionshanteringen | Repo-specifik `AGENTS.md`, beroendelåsning, teststruktur, CI och `.gitignore` saknas. Viktiga nuvarande filer är ännu ospårade. Säkra en dokumenterad basversion före förändring; filtrera bort `.DS_Store`. Ange villkor och källor för återanvändning av data och geometri. |

## Vad som behöver ändras per land

**Sverige.** Prioritera identiteten och kapacitetsrelationen mellan Mistral och EcoDataCenter Borlänge, den äldre Östersundsplanen, Brookfields fullbyggnadsår, EdgeModes tids- och genomförandeuppgifter samt Conaptos IT- och nätkapaciteter. Skilj preparerande markarbete från byggnation av datacenteretappen. Utöka sökningen med nätägarnas och kommunernas underlag. Svenska kraftnät beskriver att aktiv köhantering och hänvisning till rätt nätnivå minskar dubbelbokningar; ansökningar ska därför inte läggas ovanpå projektannonser utan identitetskontroll. [Svenska kraftnät den 2 februari 2026](https://www.svk.se/press-och-nyheter/nyheter/allmanna-nyheter/2026/nara-5000-mw-nya-anslutningar-beviljades-2025/).

**Norge.** Återställ möjligheten att följa utbyggnader vid Hamar och Lefdal. Uppdatera Bulk DCM102:s passerade 2025-tidplan och belägget för 600 MW. Komplettera företags- och kommunmaterial med Statnetts offentliga projektlista över reserverad kapacitet och kö, samt relevanta regionala nätägare. Statnett skiljer teknisk försvarbarhet från faktisk reservation och hänvisar till uppdaterade mognadskriterier. Landstillägget behöver göra dessa steg begripliga utan att likställa dem med investeringsbeslut. [Statnetts projektstatistik](https://www.statnett.no/nettkapasitet-til-produksjon-og-forbruk/foresporsler-og-reservasjon-i-nettet/) och [anslutningsprocess](https://www.statnett.no/nettkapasitet-til-produksjon-og-forbruk/hvordan-fa-okt-nettkapasitet/).

**Finland.** Rätta först källkopplingarna. Granska därefter Nebius första leverans kontra fullcampus, FIN04:s kapacitet och infasning, DayOnes första etapp kontra skalbar total samt Microsofts tillståndsbaserade fullsitevärden kontra beslutade etapper. Behåll finska, svenska och engelska sökningar och komplettera med miljöbedömningsmaterial, kommunala beslut och nätägare. Fingrid publicerade en ny scenarioöversikt den 30 september 2026; den är relevant som jämförelse efter att omfattning och definitioner har harmoniserats, inte som ett facit att tvinga projektlistan att summera till. [Fingrid september 2026](https://www.fingrid.fi/ajankohtaista/tiedotteet/2026/sahkon-tuotannon-ja-kulutuksen-kehitysnakymat-paivitetty--sahkonkulutuksen-kasvu-konkretisoituu).

Som konkret exempel på behovet av ny discovery saknas atNorth FIN05 i Salo i huvuddata. Företaget annonserade projektet den 5 oktober 2026 och skiljer 75 MW för första etappens säkrade elförsörjning från en väg till upp till 230 MW för den större utvecklingen. Det är en kandidat för nästa körning, inte en post som lagts till i denna granskning. [atNorth FIN05](https://www.atnorth.com/news/atnorth-to-develop-new-data-center-in-salo-finland/).

## Föreslagen ordning och villkor för att gå vidare

1. **Säkra nuläget och rätta integritet.** Dokumentera basversionen; rätta FI-relationerna, stäng genomförda granskningsförslag och inför samma validering i provkörning som vid införande.
2. **Fastställ metod.** Bestäm basdatum, portfölj kontra driftsatt kapacitet kontra årsenergi, tidsregler, hur operativa basnivåer hanteras, överlapp och evidenskrav.
3. **Uppdatera modell och beräkning tillsammans.** Migrera data utan att byta stabila identiteter, rätta typklassningen och gör införande och export samordnade och återkörbara.
4. **Uppdatera gemensamma instruktioner och landspaket.** Lägg till körlogg, söktäckning, originalcitat och aktuella register. Låt samma definitioner styra dokumentation, validator och promptar.
5. **Gör en avgränsad pilot.** Ta fall från alla tre länderna som täcker verkliga fel: finska ID-länkar, Mistral/campus, operativt campus med expansion, MWth, oklar MW-basis och första kapacitet kontra full utbyggnad. Mät resultat mot ett granskat facit.
6. **Kör därefter audit och discovery för varje land.** Börja audit mot rättad basversion, sammanför godkända ändringar, gör discovery mot den uppdaterade identiteten och avsluta med avdubbling mellan hela materialets site- och kapacitetsrelationer.

Innan en full körning bör alla kända integritetsfel vara lösta och pilotens kritiska fält ha korrekt källstöd. Innan publicering ska hela byggkedjan inklusive karta fungera i den dokumenterade miljön, varje scenariotal kunna följas till räknade poster och kvarstående osäkerheter visas som sådana. Förändringar jämfört med föregående leverans ska kunna hänföras till nya belägg, metodändring, rättad dubblett eller ändrad tids-/energitolkning.

Följande kan vänta tills detta fungerar: ett mer avancerat agentupplägg, full probabilistisk simulering utan empiriskt kalibreringsunderlag och större plattformsbyte. För elområdesvisa effekt- och energijämförelser räcker en tydlig, prövbar modell långt. Analys av kortvariga AI-lastvariationer, flexibilitet, vatten eller klimatpåverkan kräver egna indata och bör läggas till som separata analysdelar när de efterfrågas.

## Nuvarande resultat som jämförelsebas

Dessa värden återges för att senare kunna förklara förändringar. De är resultat från den granskade modellen, inte validerade prognoser. MW avser dess härledda nätkapacitet; TWh är dess årsberäkning utan ny etappvis infasning.

| Land | Låg 2030 MW | Angiven 2030 MW | Angiven 2035 MW | Hög 2035 MW | Hög 2035 TWh |
| --- | ---: | ---: | ---: | ---: | ---: |
| Sverige | 343,85 | 973,85 | 1 723,85 | 3 229,25 | 21,440 |
| Norge | 282,00 | 282,00 | 282,00 | 840,00 | 4,573 |
| Finland | 457,00 | 1 085,00 | 1 085,00 | 1 655,00 | 10,085 |

Det finns både mekanismer som kan överskatta resultatet och sådana som kan underskatta det. Därför är det inte försvarbart att korrigera totalsumman med en generell procentsats. Nästa version bör förklara varje större ändring från en stabil och spårbar bas.
