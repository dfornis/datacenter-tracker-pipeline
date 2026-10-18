# Slutredovisning: tidskomplettering SE, NO och FI, 2026-10-18

Alla tre landskörningar och den avslutande norska operatörsavstämningen är införda. 10 nya projekt, en återaktiverad kandidat (P110), 39 nya kapacitetsrader och 48 nya källor. 37 äldre projekt, 163 äldre kapacitetsrader och 169 äldre källor har faktarättelser, förklaringar eller verifierad åtkomst; detta är inte 163 oberoende MW-förändringar. Godkännanden och aktörsregistret är oförändrade. 17 kandidater väntar på uttryckligt ID-godkännande.

Underlagen finns i `2026-10-18-se-timing-complement.md`, `2026-10-18-no-timing-complement.md`, `2026-10-18-no-bitzero-addendum.md` och `2026-10-18-fi-timing-complement.md`. Den daterade `2026-10-18-complement-comparison.json` redovisar 81 ändrade projekt/scenario-rader, 12 landsrader, 52 elområdesrader och årsserier per land. Den tidigare `2026-10-18-timing-method-comparison.json` isolerar själva metodändringen före källkompletteringen. Inget av granskningsunderlagen används som register eller av beräkningsmodellen.

## Modellrättning och tester

Faktisk leverans efter det fasta basåret 2025 försvinner inte längre när en äldre driftbas är registrerad. Nebius Mäntsälä: 75 MW faktiskt färdig omfattning minus 25 MW belagd äldre bas ger 50 MW även efter statusbytet till Operational. Exakt ytterligare leverans under 2025 är inte känd. Fixen ger +50 MW / +0,3504 TWh i varje scenario med de nya finska fakta; övriga kompletteringsskillnader kommer från källor, avgränsning och händelsetyp.

De tidigare 81 testgrupperna täckte hela modellen och arbetsflödet, inte 81 ledtidsantaganden. Sex överlappande grupper har slagits ihop, upprepade hela registerberäkningar ersatts med syntetiska testfall och den saknade kombinationen faktisk leverans + äldre driftbas fått en parametriserad regression. 75 grupper passerar, liksom nio separata årsgrafkontroller. Sparad check verifierar alla kanoniska utdata och den lokala sajten. 0 obehandlade tidsuppföljningar, 197 kapacitetsrader med dokumenterad kvarstående osäkerhet.

## Godkänt resultat

Varje scenariocell är infasad MW / årsenergi TWh. Annonserad ram anges separat. * betyder ytterligare okvantifierade projekt eller etapper; även en kvantifierad nolla kan därför ha ett okänt tillägg. Årsenergi är en årsekvivalent vid kapacitetsnivån, inte uppmätt förbrukning. SE4 och NO3 saknar registrerade aktiva godkända projekt. NO-unassigned innehåller en väntande kandidat men inga godkända projekt.

| Elområde | Annonserad ram MW | Low 2030 | Stated 2030 | Stated 2035 | High 2035 |
|---|---:|---:|---:|---:|---:|
| SE1* | 1000 | 0 / 0.000 | 0 / 0.000 | 0 / 0.000 | 800–1000 / 5.256–6.570 |
| SE2* | 2300 | 0 / 0.000 | 830 / 5.532 | 850 / 5.672 | 1000–2200 / 6.658–14.542 |
| SE3* | 2176–2232 | 114–116 / 0.690–0.701 | 169–278 / 1.061–1.769 | 296–524 / 1.900–3.392 | 1786–2232 / 11.635–14.534 |
| SE4 | 0 | 0 / 0.000 | 0 / 0.000 | 0 / 0.000 | 0 / 0.000 |
| SE-unassigned* | 1–5 | 0 / 0.000 | 0 / 0.000 | 0 / 0.000 | 1–5 / 0.004–0.025 |
| NO1 | 626–674 | 0 / 0.000 | 66–102 / 0.331–0.510 | 119–156 / 0.594–0.780 | 124–674 / 0.619–4.126 |
| NO2 | 2916–3978 | 350–413 / 2.152–2.467 | 438–1039 / 2.594–6.249 | 786–1284 / 4.506–7.468 | 1392–3978 / 7.614–22.506 |
| NO3 | 0 | 0 / 0.000 | 0 / 0.000 | 0 / 0.000 | 0 / 0.000 |
| NO4 | 1560 | 138–184 / 0.907–1.209 | 138–300 / 0.907–1.971 | 230–520 / 1.511–3.416 | 230–1560 / 1.511–10.249 |
| NO5 | 80–280 | 0 / 0.000 | 0 / 0.000 | 0 / 0.000 | 64–280 / 0.320–1.398 |
| NO-unassigned | 0 | 0 / 0.000 | 0 / 0.000 | 0 / 0.000 | 0 / 0.000 |
| FI* | 7735–9464 | 344–612 / 2.328–4.021 | 1116–1886 / 7.534–12.502 | 2442–3789 / 16.245–24.972 | 5854–9464 / 38.375–61.960 |

Godkända projekt utan användbart MW: SE 7, NO 0, FI 11. Okända etapper finns dessutom i två svenska och sex finska projekt. 145 aktiva godkända kapacitetsrader har MW; 70 saknar både byggstart och drift-/nätår, och 23 har fullkapacitetsår utan byggstart. Före kompletteringen var talen 132/74/14. Den nya nämnaren innehåller återfunna etapper och nya datumsatta omfattningar; detta är inte antal unika projekt.

## Förändringar och begränsningar

Metodändringen isolerat sänkte High 2026:s kvantifierade övre summa från 16 626,9 till 237,7 MW. Efter källkompletteringen är den 376,7 MW. Torsboda ger fortfarande 0 MW 2026 och 650 MW 2030; 1/2 GW-ramarna har egna senare osäkra förlopp. Fullmålet 2030 skjuts inte upp av schablonen.

Sverige: faktisk Stockholm 4-leverans, rätt avgränsad Stockholm 5-leverans och Sollefteås 200 MW-nätavtal. Norge: Skien, Narvik, Molandsmoen och ny avgränsad kapacitet i Kalberg/Suldal; äldre Hamar-kapacitet hör till basen. Finland: Microsofts återfunna egna fullmål 2031 och etapp-MW ger 621,56 MW i Stated 2035; Blackhawk/Nova får användbar effekt, och nät-/driftmål hålls isär hos Bitzero.

De gemensamma återstående ledtiderna, 2–3 års byggtid och femårig fysisk utbyggnad är fortsatt preliminära känslighetsantaganden där bättre fakta saknas. De har inte kalibrerats till observerade nordiska fördelningar. Inga modellberäknade år har skrivits in som källankare. Flera nätavtal, etapp-MW, faktiska öppningar och jämförbara äldre baser är fortsatt okända. Källbegränsningar och sökutfall är dokumenterade land för land.

## Kandidatgrupper

Kandidatrader med källa, ort, omfattning, datum och beslut finns i landsrapporterna och redovisas även i chatten. Nedan är en gemensam prövning av grupperna med samma modell; det är inte genomfört godkännande. Inom projekten är överlapp redan hanterade. Okända belopp tillkommer utöver de visade delarna.

| Grupp | Low 2030 MW/TWh | Stated 2030 MW/TWh | Stated 2035 MW/TWh | High 2035 MW/TWh |
|---|---:|---:|---:|---:|
| Föreslås: 11 kandidater, varav två utan MW | 28.00–42.00 / 0.184–0.276 | 47.28–127.20 / 0.302–0.824 | 76.60–300.00 / 0.493–1.957 | 607.00–824.00 / 3.848–5.147 |
| Osäker identitet/netto: sex kandidater, varav tre utan MW | 0.00 / 0.000 | 0.00–30.40 / 0.000–0.171 | 24.00–53.00 / 0.158–0.312 | 24.00–400.00 / 0.158–2.045 |

Ingen ny kandidat har satts till out_of_scope under kompletteringen. Marknadsföringsspår utan namngiven datacenteraktör, redan befintlig drift och energiproduktion utan belagd ny datacenterlast ligger endast i sökloggarna. Föreslagen exkludering kräver separat beslut: P075/P076/P077 saknar identifierad plats, P056 HIVE Big Boden saknar belagd ny elektrisk kapacitet. De är fortfarande godkända i resultaten.

Arbetet ligger på Git-grenen `codex/tidsmodell-och-kallinsamling`. Metodrättningen och de tidigare landsresultaten är committade för rena prepare-baser; sista norska tillägget och denna slutredovisning lämnas för granskning. Folios tidigare lokala ändringar är bevarade. Inget har pushats, publicerats eller slagits samman. Förslag till sista commit-meddelande: `Complete Nordic timing supplementation and final audit`.
