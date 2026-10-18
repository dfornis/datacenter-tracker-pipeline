# Tidsmodell och förberedd komplettering, 2026-10-18

Metodutveckling på `codex/tidsmodell-och-kallinsamling`. Ingen landsinventering har startats. Inga projektfakta, källvärden, aktörer eller godkännanden har ändrats. Alla tidigare fältvärden i de fyra tabellerna har jämförts mot utgångscommiten `84c94ad`. Åtta nya kapacitetsfält är tomma tills belägg tillkommer.

Jämförelsen använder den sparade godkända exporten före ändringen och den nya gemensamma modellen. Alla MW-förändringar nedan beror därför på ändrade metodantaganden/urval/basdatum, inte nya fakta. Det fullständiga daterade underlaget finns i [jämförelsefilen](2026-10-18-timing-method-comparison.json): per projekt, land, elområde och år samt arbetslistor med befintliga källutdrag, URL:er, granskningsnycklar och sökfrågor. Det är ett granskningsunderlag och läses inte av modellen.

## Beslut och antaganden

- Källbelagd första drift och fullbyggnad gäller för sin egen omfattning. Generella ledtider fyller luckor och får inte ensamma flytta ett fullbyggnadsmål. Utbyggnaden komprimeras vid behov före det belagda slutåret.
- Utan användbart driftår används byggstart + 2–3 år, annars preliminära återstående ledtider från genomförandeläget: koncept/oklart +4–8 år, planerat +3–6, tillståndsgivet +2–4, pågående bygge utan startår +0–2. Noll betyder möjlig leverans senare under bedömningsåret.
- Fem år kvarstår som preliminär utbyggnadsschablon för okänd/stegvis leverans. Kända etappdatum, fullbyggnadsår och enskilda leveranser ersätter schablonen. Det är en fysisk kapacitetsmodell; användningsfaktorn för årsenergi tillämpas separat, utan en andra ramp.
- De nya ledtiderna är egna känslighetsantaganden, inte observerade nordiska normalvärden eller tidigare beslut. IEA och National Grid/Regen stöder mekanismerna men inte samtliga exakta tal. Kalibrering återstår.
- Årsgrafen slutar 2035. Odaterade campusramar kvarstår som relevant potential i High. High är villkorat på genomförande; dess nedre gräns är ingen garanti eller sannolikhetsgräns.
- Basåret är fast 2025. Faktiskt daterade tillskott efter basåret överlever statusbytet till Operational. En gammal måluppgift är inte en inträffad händelse. Historik kan inte rekonstrueras säkert där händelsetyp och datum saknas.
- En uttryckligt kopplad nätobservation begränsar rätt omfattning och kan inte bli en extra additiv last. MW begränsas efter PUE-omräkning. Flera nätsteg kräver avgränsade etapper.
- Både prepare och check följer tidsluckorna. Varje punkt avslutas med komplettering eller en källanknuten kvarstående osäkerhet i kapacitetsradens notes. Ändrat underlag öppnar punkten igen.

## Torsboda: 650, 1 000 och 2 000 MW

Källan S189, Torsboda Industrial Parks FAQ uppdaterad 17 juni 2026, sidan 6, anger färdig fas ett den 31 december 2030 med 650 MW och ett mål om 1 000 MW. Datumet för fas ett gäller C072; det flyttas inte fram av femårsschablonen. C055 är en odaterad ram på 1 000 MW och C073 en odaterad framtida totalram på 2 000 MW. Ramarna är inneslutna, inte additiva. Den befintliga källtolkningen har kontrollerats mot originalet utan ändring av registervärden.

Nuvarande beräkning: 0 MW 2026, uppskattat 0–325 MW 2029, 650 MW 2030. Stated 2035 är 650 MW; High 2035 är 800–2 000 MW under antagandet att expansionen genomförs. Skillnaden före 2030 behöver kompletteras med första etappens driftår och MW. För de större ramarna behövs mark-/tillståndsläge, etappplan och daterad nätkapacitet.

## Godkända landsresultat

MW, avrundat. Asterisk betyder att siffran är en kvantifierad delsumma med ytterligare okända projekt/etapper. Den betyder inte att den visade övre gränsen täcker de okända delarna.

| Land | Scenario | Tidigare | Nu |
| --- | --- | ---: | ---: |
| SE | low_2030 | 105–107* | 105–107* |
| SE | stated_2030 | 991–1 499* | 991–1 099* |
| SE | stated_2035 | 1 237–1 973* | 1 237–1 473* |
| SE | high_2035 | 1 237–5 529* | 3 655–5 529* |
| NO | low_2030 | 246–503* | 228–503* |
| NO | stated_2030 | 398–1 116* | 342–913* |
| NO | stated_2035 | 398–1 418* | 390–1 418* |
| NO | high_2035 | 398–6 082* | 1 141–6 082* |
| FI | low_2030 | 178–396* | 150–396* |
| FI | stated_2030 | 804–2 862* | 622–1 282* |
| FI | stated_2035 | 1 847–4 775* | 1 437–3 014* |
| FI | high_2035 | 1 847–9 310* | 5 509–9 310* |

## Varför de stora förändringarna uppstår

Highs övre summa 2026 för godkända projekt minskar från 16 626,9 till 237,7 MW. Tidigare kunde odaterade ramar tas in fullt direkt. Nu behöver de ett genomförandeförlopp. Stora tidiga förändringar finns bland annat i Torsboda, Skellefteå, Kokemäki, Bulk N01, Pyhäjoki, Strängnäs och Korgen. Ramarna försvinner inte ur fullbuildout eller High 2035.

High 2035 får samtidigt högre nedre värden när odaterade ramar får explicita sena förlopp i stället för ett obegränsat 0–100-procentsintervall. Det är ändrad scenariobetydelse under genomförandeantagandet, inte starkare källbelägg.

En uttrycklig urvalsändring tar bort regeln som lät en etapp utan MW datera och kvantifiera hela campusramen i Low/Stated. Följande sju godkända campus berörs. Deras okvantifierade etapper markeras som okända; 0 nedan är endast den kvantifierade delen. High behåller campusramarnas egna förlopp.

| Projekt | Campusuppgift | Stated 2035 tidigare | Stated 2035 nu |
| --- | --- | ---: | ---: |
| P015 Google Horndal; Avesta | C052 | 0–500 | 0* (etapp-MW okänt) |
| P026 Microsoft Finland cloud region - Espoo campus | C045 | 0–211 | 0* (etapp-MW okänt) |
| P027 Microsoft Finland cloud region - Kirkkonummi campus | C046 | 0–176 | 0* (etapp-MW okänt) |
| P028 Microsoft Finland cloud region - Vihti campus | C047 | 0–234 | 0* (etapp-MW okänt) |
| P033 atNorth FIN04 Myllykoski mega campus | C038 | 0–430 | 0* (etapp-MW okänt) |
| P035 Nebius Lappeenranta AI factory | C040 | 0–310 | 0* (etapp-MW okänt) |
| P095 Hyperco Lohja Virkkala | C110 | 0–400 | 0* (etapp-MW okänt) |

Övriga skillnader i daterade projekt kommer bland annat från passerade mål som inte får behandlas som verifierad drift, byggstartens händelsetyp och det fasta basåret. Projektens ledger redovisar första/full kapacitet, källankare, antagande och konfliktflagga.

## Elområden

| Elområde | Scenario | Tidigare MW | Nu MW |
| --- | --- | ---: | ---: |
| FI | low_2030 | 178–396* | 150–396* |
| FI | stated_2030 | 804–2 862* | 622–1 282* |
| FI | stated_2035 | 1 847–4 775* | 1 437–3 014* |
| FI | high_2035 | 1 847–9 310* | 5 509–9 310* |
| NO1 | low_2030 | 0 | 0 |
| NO1 | stated_2030 | 66 | 66 |
| NO1 | stated_2035 | 66 | 66 |
| NO1 | high_2035 | 66–674 | 123–674 |
| NO2 | low_2030 | 146–403* | 128–403* |
| NO2 | stated_2030 | 232–768* | 176–630* |
| NO2 | stated_2035 | 232–962* | 224–962* |
| NO2 | high_2035 | 232–3 568* | 724–3 568* |
| NO4 | low_2030 | 100 | 100 |
| NO4 | stated_2030 | 100–282 | 100–216 |
| NO4 | stated_2035 | 100–390 | 100–390 |
| NO4 | high_2035 | 100–1 560 | 230–1 560 |
| NO5 | low_2030 | 0 | 0 |
| NO5 | stated_2030 | 0 | 0 |
| NO5 | stated_2035 | 0 | 0 |
| NO5 | high_2035 | 0–280 | 64–280 |
| SE-unassigned | low_2030 | 0* | 0* |
| SE-unassigned | stated_2030 | 0* | 0* |
| SE-unassigned | stated_2035 | 0* | 0* |
| SE-unassigned | high_2035 | 0–5* | 1–5* |
| SE1 | low_2030 | 0 | 0 |
| SE1 | stated_2030 | 0 | 0* |
| SE1 | stated_2035 | 0 | 0* |
| SE1 | high_2035 | 0–1 000 | 800–1 000* |
| SE2 | low_2030 | 0* | 0* |
| SE2 | stated_2030 | 830* | 830* |
| SE2 | stated_2035 | 950* | 950* |
| SE2 | high_2035 | 950–2 300* | 1 100–2 300* |
| SE3 | low_2030 | 105–107* | 105–107* |
| SE3 | stated_2030 | 161–669* | 161–269* |
| SE3 | stated_2035 | 287–1 023* | 287–523* |
| SE3 | high_2035 | 287–2 224* | 1 754–2 224* |

## Riktad komplettering att genomföra senare

Diagnostik: 132 aktiva godkända kapacitetsrader med MW; 74 saknar både byggstart och drift-/nätår; 14 har fullkapacitetsår utan byggstart. Med kandidater är motsvarande tal 138, 80 och 14. Det är kapacitetsrader, inte unika projekt.

Arbetslistan har 161 tidsuppföljningar, 11 etapper under genomförande utan MW och 1 möjlig överföring av etappdatum till campus. Nya tomma fält gör många formella luckor synliga; befintliga utdrag/notes kan ofta besvara dem innan ny sökning behövs. Ingen punkt har markerats som källgranskad i detta metodarbete.

Prioritera följande omfattningar. Prioritetsvärdet är skillnaden mellan antaget tidigt/sent bidrag i det mest känsliga året fram till 2030, inte ett extra MW-bidrag. Överlappande rader får inte summeras. Etapperna utan MW är en särskild prioritet även när ett numeriskt prioritetsvärde inte kan räknas.

| Land | Projekt/uppgift | Käll-MW | Möjligt tidsskifte, MW/år | Sökfråga |
| --- | --- | ---: | --- | --- |
| SE | P041/C073 Google Torsboda | 2000 | 400 / 2030 | Är 2 GW fortfarande totalramen? Markexpansion, tillstånd, nätförstärkningar och etapper utöver fas ett. |
| SE | P001/C001 EdgeConneX Skellefteå gigawatt campus | 1000 | 400 / 2030 | Första drift, namngivna etapper med MW, aktuellt tillstånds-/byggläge och daterad nättillgång. |
| NO | P022/C033 Bulk N01 Campus | 1000 | 400 / 2030 | Första drift, namngivna etapper med MW, aktuellt tillstånds-/byggläge och daterad nättillgång. |
| SE | P041/C055 Google Torsboda | 1000 | 400 / 2030 | Första drift, namngivna etapper med MW, aktuellt tillstånds-/byggläge och daterad nättillgång. |
| FI | P151/C161 Bitzero Kokemäki | 1000 | 400 / 2030 | Första drift, namngivna etapper med MW, aktuellt tillstånds-/byggläge och daterad nättillgång. |
| FI | P152/C166 Hyperco Pyhäjoki Keskikylä | 369 | 354 / 2030 | Första drift, namngivna etapper med MW, aktuellt tillstånds-/byggläge och daterad nättillgång. |
| FI | P152/C167 Hyperco Pyhäjoki Keskikylä | 284 | 354 / 2030 | Första drift, namngivna etapper med MW, aktuellt tillstånds-/byggläge och daterad nättillgång. |
| SE | P041/C072 Google Torsboda | 650 | 325 / 2029 | Första drift och första leveransens MW före färdig fas ett 2030; genomförda avtalsmilstolpar. |
| SE | P002/C003 Brookfield AI-center Strängnäs | 750 | 300 / 2030 | Första drift, namngivna etapper med MW, aktuellt tillstånds-/byggläge och daterad nättillgång. |
| NO | P182/C210 Nscale Korgen / Helgeland | 750 | 300 / 2030 | Första drift, namngivna etapper med MW, aktuellt tillstånds-/byggläge och daterad nättillgång. |
| SE | P003/C004 EcoDataCenter Borlänge; Kvarnsveden | 600 | 240 / 2030 | Första drift, namngivna etapper med MW, aktuellt tillstånds-/byggläge och daterad nättillgång. |
| FI | P093/C106 Sesterce Kaipola Jämsä | 600 | 240 / 2030 | Första drift, namngivna etapper med MW, aktuellt tillstånds-/byggläge och daterad nättillgång. |
| NO | P016/C024 Google Skien data center | 240 | 240 / 2030 | Har den passerade milstolpen inträffat eller reviderats? Verifiera aktuell bygg-/driftstatus och kvarvarande etapper. |
| NO | P173/C197 Nscale Bolvik / Grenland Data Center | 576 | 230 / 2030 | Första drift, namngivna etapper med MW, aktuellt tillstånds-/byggläge och daterad nättillgång. |
| FI | P090/C103 DayOne Nurmijärvi Sudentulli | 560 | 224 / 2030 | Första drift, namngivna etapper med MW, aktuellt tillstånds-/byggläge och daterad nättillgång. |
| FI | P151/C162 Bitzero Kokemäki | 520 | 208 / 2030 | Första drift, namngivna etapper med MW, aktuellt tillstånds-/byggläge och daterad nättillgång. |
| SE | P015/C052 Google Horndal; Avesta | 500 | 200 / 2030 | Första drift, namngivna etapper med MW, aktuellt tillstånds-/byggläge och daterad nättillgång. |
| FI | P121/C132 Arcem Joroinen Huutokoski | 500 | 200 / 2030 | Första drift, namngivna etapper med MW, aktuellt tillstånds-/byggläge och daterad nättillgång. |

Arbetsordning: börja med registrets länkade utdrag och fulltexter. Sök därefter operatörens projektsida/pressmeddelanden, kommunens detaljplan och bygglov, miljöprövning/MKB/YVA samt namngiven nätägares anslutning eller förstärkning. Använd projekt-/ortnamn och lokala ord för byggstart, driftsättning, etapp, effekt och nätanslutning.

För de sju campus som tappat det felaktigt lånade datumet: sök framför allt MW för den etapp som faktiskt byggs, inte ett nytt totalmått för campus. Återför belägget till dess befintliga claim_id och källor; skapa bara en ny etapprad när det verkligen är en annan omfattning.

Kalibreringsunderlag: välj jämförbara färdiga etapper i varje genomförandeklass och samla daterat tillstånd, investeringsbeslut, faktisk byggstart, faktisk första drift och slutlig kapacitet. Behåll försenade/oavslutade projekt i underlaget så att bara snabba framgångar inte bestämmer ledtiderna. Källhänvisa varje händelse och skilj anslutningsklar kapacitet från utrustningens användning.

Ingen prepare har körts mot det aktiva registret. När metodändringen är granskad och committad används standardflödet för ett land åt gången: prepare → oföränderlig daterad lägesbild → bred upptäckt → riktad granskning → avstämning → apply/redovisning. Nya kandidatgodkännanden och publicering är separata beslut.

## Integration och kontroll

Årsexporten skapas nu av scripts/model.R i samma transaktion som övriga resultat. apply, approve, build och tracker uppdaterar både pipeline och lokal folio-sajt. Folios tidigare årsexportör är en kompatibilitetsingång till detta flöde. Grafen har High, fast skala per mått, mjuka övergångar samt separata mått för kumulativa tillskott, årets tillskott och kvarvarande ram. Webbläsaren summerar endast färdigräknade värden.

Tidigare lokala trackerändringar sparades i 84c94ad före den nya grenen. Folios sju tidigare ändrade filer bevarades dessutom under /tmp/datacenter-time-baseline/folio-working-copy före integrationen. Metodändringarna är inte committade eller publicerade.

Kontroller:

- 81 metod- och arbetsflödestester passerar, inklusive faktiska/passerade tidsankare, fullbyggnadsmål, statusbaserade antaganden, sena nätbesked, nätets MW-tak, etapper utan MW och bibehållen historik vid Operational.
- 11 JavaScript-testposter passerar för tracker/graf (inklusive den samlade kontraktskontrollen); folios 9 befintliga graftester passerar.
- 309 godkända projekt/scenariofamilj-serier har kontrollerats för giltiga intervall och monotona kumulativa förlopp.
- Den lokala Jekyll-sajten byggdes med Docker. Grafens reglage, intervall, okända etapper och layout kontrollerades i smal och bred vy. Två fel från sajtens befintliga temakod (`determineComputedTheme`) observerades i konsolen; de berör inte den testade trackerberäkningen och har inte ändrats här.
- Alla tidigare registerfält har jämförts och är oförändrade. Äldre modellanteckningar bevaras och märks i presentationen som tidigare granskningar; dagens beräknade kolumner och projektsumma gäller.

Årsupplösningen kan inte avgöra om ett mål med bara årtal redan har passerats inom det pågående kalenderåret. Sådana fall behöver källgranskning. Exakta händelser och aktuell status ska beläggas i kompletteringen, inte härledas från att ett gammalt målår finns i tabellen.

Slutlig `Rscript scripts/pipeline.R check` passerade: valid=true, saved_outputs_current=true. Både pipeline-exporterna och den lokala sajten är aktuella. 161 tidsuppföljningar är öppna; 0 har markerats som dokumenterad kvarstående osäkerhet. Det är väntad status före den beställda framtida kompletteringen.
