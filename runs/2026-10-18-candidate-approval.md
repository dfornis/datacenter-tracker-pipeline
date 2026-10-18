# Manuellt kandidatgodkännande 2026-10-18

Användaren godkände uttryckligen P178, P179, P192, P194, P199, P200, P166, P167, P168, P197 och P198 i chatten. Beslutsunderlaget kontrollerades mot samtliga aktuella ingångshashar före införandet. Det etablerade approve-flödet ändrade dessa elva projekt från candidate till existing och byggde om alla resultat, årsgrafens export och den lokala sajten.

Det finns nu 114 godkända projekt jämfört med 103 före beslutet. Endast record_type ändrades i projektregistret; kapacitets-, käll- och aktörstabellerna är byteidentiska med läget omedelbart före godkännandet. Byggstatus, källuppgifter, tidsankare, beslut och generella antaganden är oförändrade. Skillnaderna nedan kommer därför enbart från användarens godkännande. Tidigare landsrapporter och slutredovisningen beskriver läget före detta beslut.

## Godkända projekt

| ID | Projekt | Land/elområde |
|---|---|---|
| P166 | FCDC Mikkeli Visulahti | FI / FI |
| P167 | Regant Mikkeli Visulahti | FI / FI |
| P168 | FCDC Valkeakoski Mahlianmaa | FI / FI |
| P178 | Polar DRA02 Drangedal expansion | NO / NO2 |
| P179 | Polar HER01 Herøya | NO / NO2 |
| P192 | ASP K11 expansion | NO / NO2 |
| P194 | ASP M12 expansion | NO / NO2 |
| P197 | Aurora Core Mikkeli Pellos | FI / FI |
| P198 | FCDC Akaa Point | FI / FI |
| P199 | Bitzero Namsskogan / Tunnsjødal | NO / NO4 |
| P200 | Bitzero Røyrvik / Storhaugen | NO / ej fastställt |

P110, P155, P191, P193, P195 och P196 ligger kvar som kandidater. Inga projekt har exkluderats.

P168 och P198 saknar användbara MW och tillkommer därför som okvantifierade projekt, inte som noll. Antalet godkända projekt utan MW ökar från 18 till 20. P200:s 20 MW ingår i Norges summa men ligger i NO-unassigned tills elområdet är belagt.

## Faktisk resultatförändring

Alla intervall är den kvantifierade delen. MW avser infasad anläggningskapacitet efter basåret 2025; TWh är årsenergi vid denna kapacitetsnivå, inte uppmätt förbrukning. Annonserad ram ökar med 821–824 MW till 19 214,91–22 317,01 MW.

| Scenario | Tillskott MW | Tillskott TWh/år | Ny summa MW | Ny summa TWh/år |
|---|---:|---:|---:|---:|
| Low 2030 | 28,00–42,00 | 0,184–0,276 | 974,23–1367,47 | 6,260–8,674 |
| Stated 2030 | 47,28–127,20 | 0,302–0,824 | 2805,73–4562,00 | 18,261–29,357 |
| Stated 2035 | 76,60–300,00 | 0,493–1,957 | 4800,11–7423,11 | 30,922–47,657 |
| High 2035 | 607,00–824,00 | 3,848–5,147 | 11857,15–22217,01 | 75,839–141,056 |

## Förändring per land och berört elområde

Sveriges resultat är oförändrat. Berörda elområden är NO2, NO4, NO-unassigned och FI; övriga elområden är oförändrade.

| Område | Scenario | Tillskott MW | Tillskott TWh/år |
|---|---|---:|---:|
| NO totalt | Low 2030 | 28,00–42,00 | 0,184–0,276 |
| NO totalt | Stated 2030 | 47,28–121,20 | 0,302–0,785 |
| NO totalt | Stated 2035 | 76,60–294,00 | 0,493–1,917 |
| NO totalt | High 2035 | 317,00–474,00 | 1,942–2,848 |
| FI totalt | Low 2030 | 0,00 | 0,000 |
| FI totalt | Stated 2030 | 0,00–6,00 | 0,000–0,039 |
| FI totalt | Stated 2035 | 0,00–6,00 | 0,000–0,039 |
| FI totalt | High 2035 | 290,00–350,00 | 1,905–2,299 |
| NO-unassigned | Low 2030 | 0,00 | 0,000 |
| NO-unassigned | Stated 2030 | 0,00 | 0,000 |
| NO-unassigned | Stated 2035 | 0,00 | 0,000 |
| NO-unassigned | High 2035 | 20,00 | 0,131 |
| NO2 | Low 2030 | 0,00 | 0,000 |
| NO2 | Stated 2030 | 5,28–7,20 | 0,026–0,036 |
| NO2 | Stated 2035 | 6,60–9,00 | 0,033–0,045 |
| NO2 | High 2035 | 89,00–169,00 | 0,444–0,844 |
| NO4 | Low 2030 | 28,00–42,00 | 0,184–0,276 |
| NO4 | Stated 2030 | 42,00–114,00 | 0,276–0,749 |
| NO4 | Stated 2035 | 70,00–285,00 | 0,460–1,872 |
| NO4 | High 2035 | 208,00–285,00 | 1,367–1,872 |

## Kontroll

Samtliga 75 beteendegrupper i metod- och arbetsflödestesterna passerade. Årsgrafens nio tester passerade. Den avslutande kontrollen verifierade sparade resultat och den lokala sajten (saved_outputs_current=true). Alla fem trackerfiler är identiska i pipeline och sajt. De 412 projekt/scenario-raderna för de 103 tidigare godkända projekten är oförändrade. Tidsuppföljningen har 0 öppna och 197 dokumenterade kvarstående osäkerheter. Ingen källosäkerhet har tagits bort genom godkännandet.

Inget har committats, pushats eller publicerats under godkännandet. Tidigare lokala ändringar är bevarade.
