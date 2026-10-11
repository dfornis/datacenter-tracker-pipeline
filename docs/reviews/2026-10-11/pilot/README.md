# Pilotens acceptanskontroll

Piloten omfattade sju projekt och tio kapacitetsuppgifter i tre länder. Svenska, norska, finska och engelska sökvägar användes. De tre körningarna ligger under `data/runs/2026-10-11-*-pilot/`, med frysta indata, svar, källpassager, fältutfall, granskningsbeslut och införandekvitton.

52 fältförslag infördes genom samma validerade granskningskedja som används för landskörningarna. Granskaren är uttryckligen `codex-second-pass`: samma agent gjorde en andra kontroll av källan och dess avgränsning. Detta är inte en oberoende mänsklig granskning eller ett blint jämförande modelltest. Modellidentifieraren var inte exponerad och registrerades som `not_exposed`.

Det granskade acceptansunderlaget finns i `scripts/evaluate_pilot.R`. Det prövar 15 avgränsade slutsatser mot den oföränderliga pilotversionen: rättade finska källidentiteter, Mistrals oklara MW-basis och överlapp, termisk reservkraft, Hamars IT-basis och möjliga utbyggnad, Lefdals nätkapacitet och okända installerade basnivå, FIN04:s design-PUE samt XTX:s första kapacitet kontra full utbyggnad. Resultatet finns i `acceptance-results.json`.

Resultat: **15 av 15 acceptansfall passerar**. Detta anger att de granskade fallen beter sig enligt det dokumenterade facit. Det mäter inte nationell täckning, generell extraktionsprecision, återkallning eller modellens sannolikhet att hitta alla fel. Facit och testfall är inte oberoende av genomförandet. Googles termiska uppgift testas som ett bevarat metodfall; dess gamla miljöunderlag kunde inte hämtas på nytt och markeras därför inte som färskverifierat.

Kör om kontrollen med `Rscript scripts/evaluate_pilot.R`. Den ska kompletteras med nya, separat granskade fall när användningsområdet eller modellen ändras.
