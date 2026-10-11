# Genomförd översyn och ombyggnad

**Arbetet finns på `codex/validated-country-pipeline`. Pipelinens metod, granskningsflöde, instruktioner och leveransstruktur är ombyggda och prövade med verkliga källor.** Den lokala leveransen är reproducerbar och visar osäkerheter. Underlaget är fortfarande en delvis verifierad projektinventering, inte en färdig nationell prognos.

Utgångsläget säkrades i `e3b85cc`. Den ursprungliga [utvärderingen](utvardering.md), [acceptansmatrisen](implementation.md) och [uppföljningen av samtliga mappar/filer](folder-acceptance.md) visar vad som ändrats och varför.

## Det som är genomfört

- **Källor och identiteter:** 13 felaktiga finska källbindningar pensionerades och ersattes med dokumenterad mappning. Projekt, site, etapp, kapacitetsuppgift och källa har stabila identiteter. 26 redan införda gamla förslag stängdes utan att ändra fakta igen.
- **Kontrollerat införande:** frysta indata, svar och granskningsbeslut; explicit val av förslag; kontroll av tidigare värde och dataversion; samma validering i provkörning och införande; låsning och atomiskt byte till en komplett, oföränderlig version. Gamla data och leveranser är bevarade.
- **Datacentermetod:** IT-last, anläggningseffekt, nätkapacitet och termisk reservkraft hålls isär. Första kapacitet daterar inte full utbyggnad. Campus och kund räknas inte dubbelt. Operativa campus kan ha framtida etapper, men bara jämförbar installerad basnivå får subtraheras.
- **Scenarier och energi:** låg/angiven kapacitet till målår skiljs från odaterad potential. Årsenergi kräver rätt effektnämnare, PUE och användningsantagande; målårsenergi kräver dessutom infasning under året. Okända MW, nätanslutningar och oförenliga topp-/märkeffekter får ingen automatisk energiomräkning. Känslighetsintervallen är illustrativa och saknar kalibrerat centralvärde.
- **LLM-arbetssätt:** separata audit/discovery-körningar, fem projekt per paket, dokumenterade sökningar på respektive lands språk, korta originalpassager, locator, datumprecision och fältutfall. Modellen får föreslå men inte själv ange godkänd granskningsstatus i svaret. Samma agents andra kontroll redovisas som just detta.
- **Struktur och drift:** gemensamt maskinläsbart schema, genererad schemareferens, repo-instruktioner, låsta R-beroenden och CI-konfiguration. Officiella kommunreferenser för 2026 är hämtade och jämförda. Äldre instruktioner, skript och fristående utdata ligger i märkt arkiv; geometrier ligger i referensdata.

Metoden är avstämd mot bland annat LBNL, EPRI, IEA, NIST, ALCE, Lost in the Middle och PRISMA-S samt nordiska nätprocesser. Hänvisningar och tillämpningsgränser finns i den ursprungliga utvärderingen och [energidokumentationen](../../energy-assumptions.md). Elhubs norska septemberrapport har lagts till som lokal kontrollreferens. Dess jämförelse mot individuella historiska mätartoppar används inte som generell belastningsfaktor mot planerad märkeffekt.

## Genomförda landskörningar

Nio frysta körningar har genomförts: tre piloter, tre granskningar av befintlig inventering och tre avgränsade sökningar efter nya projekt.

| Omfattning | Sverige | Norge | Finland | Totalt |
| --- | ---: | ---: | ---: | ---: |
| Befintliga projekt med riktad sökning | 15 | 9 | 14 | 38 |
| Kapacitetsuppgifter med täckningsredovisning | 22 | 11 | 13 | 46 |
| Införda pilotförslag | 20 | 19 | 13 | 52 |
| Införda granskningsförslag | 50 | 36 | 31 | 117 |
| Nya projektkandidater i granskningskö | 3 | 4 | 8 | 15 |

169 fältgranskningar har källstöd och 45 nya källposter har verifierade utdrag. De 70 ärvda källposterna finns kvar med sin tidigare granskningsstatus. Alla 38 projekt har sökts igenom, men det betyder **inte** att alla deras fakta har verifierats. Täckningsmatrisen redovisar 1 308 obligatoriska fältkontroller som fortfarande okända i denna begränsade genomgång. Ingen av de 15 nya kandidaterna har räknats in i huvuddata eller scenariototalerna.

Viktiga faktarättningar:

- Östersundsprojektet markeras avbrutet utifrån EcoDataCenters årsredovisning, i stället för att blandas ihop med Borlänge. [Årsredovisning 2025, avsnittet om väsentliga händelser](https://ecodatacenter.tech/hubfs/Annual%20Report%202025_EcoDC%20Holding%20AB_ENG.pdf).
- Conapto Stockholm 5 har 28 MW IT-last och kontrakterad leverans av hela kapaciteten i juli 2027. Den separata 40 MW-inmatningen blir inte ytterligare IT-kapacitet. [Conapto Q2 2026](https://news.cision.com/se/conapto-holding-ab/r/delarsrapport-q2-2026,c4388598).
- Hamar använder IT-basis för 90/150 MW; den möjliga ökningen är 60 MW när den jämförbara basnivån används. Lefdals tillgängliga nätkapacitet blir däremot inte installerad basnivå. [Pilotsvar och acceptansresultat](pilot/README.md).
- Rjukan, Rennesøy och Enebakk skiljer nu möjliga/maximala campusnivåer från verifierat driftsatt kapacitet. Brookfields byggperiod och XTX:s första kapacitet blir inte datum för hela utbyggnaden.
- **C042 spärras från samtliga scenarier.** Miljöprövningens 100 MW IT/130 MW elektrisk effekt beskriver en planerad grannanläggning väster om det Blackhawk-projekt som YIT bygger. Uppgiften finns kvar för spårbarhet, med uttrycklig identitetskonflikt. [Miljömyndighetens sitebeskrivning](https://www.ymparisto.fi/fi/osallistu-ja-vaikuta/ymparistovaikutusten-arviointi/kouvolan-datakeskus-hyperco-data-systems-oy-kouvola), [YIT:s Blackhawk-projekt](https://www.yit.fi/en/projects/data-center-kouvola).

De nya kandidaterna omfattar bland annat Smedjebacken, Norrsundet, Torsboda, Undheim, Fyresdal, Frier Vest, Narvik, Salo, GigaVaasa, Googles tre nya finska orter och Nebius Lappeenranta. Varje kandidat har en källpassage och en konkret anledning till fortsatt granskning i [kandidatlistan](discovery-leads.json).

## Resultatkontroll och jämförelse

**40 regressionstester och 15 av 15 verklighetsbaserade acceptansfall passerar.** Pilotfacit är granskat av samma agent som genomförde arbetet. Det är inte en oberoende eller blind mätning av generell modellprecision eller nationell återkallning.

Den lokala exporten omfattar 38 projekt, 46 kapacitetsuppgifter, 184 avräkningsrader och alla tio konfigurerade elområden. Den exporterar också källor, fältgranskningar, öppna källkonflikter, kvalitetsuppgifter och versionsmanifest. Den tidigare leveransen med 27 projekt/34 kapacitetsuppgifter är bevarad som äldre version. Saknade kommunpunkter påverkar markörer, inte att elområdesgeometrierna levereras.

[Jämförelsen](results/summary.json) innehåller 313 ändrade celler mellan den första v2-migreringen och slutläget, inklusive härledd granskningsmetadata. 46 avräkningsrader har ändrat utfall. Det är inte 313 nya faktauppgifter eller 46 nya projekt.

- [Före/efter per fält med källa och körning](results/field-changes.csv)
- [Ändrad avräkning per kapacitetsuppgift och scenario](results/ledger-changes.csv)
- [Landsjämförelse med separata mått](results/country-comparison.csv)
- [Kontrollresultat och leveransversion](results/verification.json)

De äldre v1-siffrorna kan inte jämföras procentuellt med v2 som om de mätte samma sak. V1 blandade bland annat antagen IT-effekt, anslutningar och odaterad potential. Inte heller v2:s separata IT-, anläggnings- och nätkolumner får adderas till en gemensam MW-total. Noll kvalificerade poster i det strikta scenariot betyder otillräckligt verifierat underlag, inte noll framtida byggande; fullständighetsflaggorna visar detta.

## Kvarvarande underlagsbehov

Den tekniska kedjan är redo för fortsatt kontrollerad uppdatering. Dessa avgränsningar ska följa med användningen av data:

1. **Anläggningsidentiteter:** lös C042/Hyperco-grannprojektet och dela upp Kalberg/Undheim innan nya kapaciteter knyts till permanenta projekt-ID. Under tiden fungerar spärrar och kandidatkö som avsett.
2. **Fakta med störst påverkan:** prioritera Mistral/Borlänge-överlapp, installerade basnivåer, generiska MW-tal, etappdatum och explicit nätstatus. [Fältvis arbetslista för samtliga 84 befintliga entiteter](results/verification-backlog.csv).
3. **Täckning:** sökningarna är dokumenterade men inte en uttömmande genomgång av alla kommunala ärenden eller alla nationella register. Kandidatlistan är ett granskningsunderlag, inte ett påstående om att alla nytillkomna anläggningar hittats.
4. **Granskning:** de betydelsefulla tolkningarna saknar ännu oberoende sakgranskning. Publicerade totalsiffror måste behålla sina täcknings- och osäkerhetsuppgifter.
5. **Geografi och driftmiljö:** fem ungefärliga norska visningspunkter saknas. Ärvda polygoners ursprung och återanvändningsrätt är inte fastställda. Lokala kontroller passerar; fjärr-CI är konfigurerad men inte körd.

Fortsatt arbete bör använda de nya frysta körpaketen och granskningskön. Ingen ändring har publicerats externt, pushats eller slagits samman med den ursprungliga branchen.
