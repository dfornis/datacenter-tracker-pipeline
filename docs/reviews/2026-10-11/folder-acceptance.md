# Uppföljning av fil- och mappgranskningen

Detta följer varje rad i den ursprungliga granskningens inventering. Historiska versioner har bevarats; det är de aktiva dokumenten och frysta körkontrakten som styr arbetet.

| Granskad del | Genomförd åtgärd och kontroll |
| --- | --- |
| README | Beskriver mått, brytdatum, länder, låst miljö, granskning, införande, export och återställning. |
| schema/status_rules | Maskinläsbart gemensamt kontrakt; schemadokumentation genereras och kontrolleras mot detta. Tid, beslut, kapacitet och energi har separata regler. |
| docs/old/schema | Flyttad till märkt v1-arkiv; ingår inte i landsagenternas aktiva instruktioner. |
| Promptöversikt/startfiler/rendering | Ersatta av sparade landspaket med indatahashar, kontrakt, identitetsindex och avgränsade projektpaket. |
| Audit/discovery-mallar | Separata arbetsflöden med gemensamma maskinregler, fälttäckning, källpassager, locator, datumprecision och skydd mot instruktioner i källmaterial. |
| Landsöverlägg | Behållna språk, uttryckliga varningar för generiska kapacitetsord, aktuella nät- och myndighetsvägar; sökningar dokumenterade för alla tre länder. |
| projects_master | Stabila projekt- och site-ID, alias, kommun-/regionkoder, verksamhet/arbetslast och evidensbaserade beslut. Max-MW används inte som jämförbart effektmått. |
| capacity_master | Etapp-ID, mått/unit/kvalificering, tid, relationer, jämförbara basnivåer och granskningsproveniens. Observerat och modellerat hålls isär. |
| sources_master | 13 felaktiga FI-bindningar pensionerade; exakta korta passager, originalspråk, locator, precision och fältstöd. Frysta svar bevarar granskat utdrag, men ersätter inte fullständigt webbarkiv. |
| assumptions | Gamla parametrar kvar som ej kalibrerade. Versionssatta illustrativa intervall med definierad nämnare, population, status och litteratur. Site-PUE har separat typ och källstöd. |
| country/geography/admin | Gemensam aktiv omfattning; officiella 2026-register hämtade och hashade: SE 290, NO 357, FI 308. 1 022 proveniensceller uppdaterade utan semantiska kod-/namnändringar. |
| municipality_locations | Ungefärlig visning och noggrannhet redovisas. Fem norska kommunpunkter saknas fortfarande; inga gissade sitekoordinater har lagts in. |
| audit/archive | Körnings-ID, status, granskarspår och oföränderliga arkiv. 26 redan införda gamla förslag stängda. Nya konflikter och 15 kandidater har separata köer. Tomma dead-links-listor betyder inte verifierade länkar. |
| build_admin_units | Konfigurerade år/källor, fullständighets- och differenskontroll, sparade råfiler samt validerad transaktion. |
| build_datacenter_data | Gemensamma moduler för läsning, validering, avräkning, geometri och sammanhållen export. |
| promote_review_rows | Fryst granskning, explicit val, förväntad föregående version, samma validering i dry-run/apply och atomiskt byte. Kandidater med ofullständiga fält hålls utanför master. |
| data/zones | 442 ärvda världsgeometrier isolerade under vendor-referensdata; aktivt urval täcker tio konfigurerade elområden. Ursprung/licens är fortfarande olöst och redovisas. |
| zones_no_backup | De fem tidigare norska kartfilerna ligger i märkt arkiv med kontrollsummor; de används inte som tyst reserv. |
| assets/data/bidding_zones | Aktiv kartindata flyttad till referensdata. Det gamla Sverige-underlaget bevarat i arkivet. Ingen Sverige-exklusiv reservväg i bygget. |
| assets/data/datacenters | V2 levererar alla 38 projekt, 46 kapacitetsuppgifter, källor, fältgranskningar, konflikter, avräkning och samtliga tio elområden. Den gamla leveransen bevaras vid övergången. |
| assets/projects_scenarios.csv | Arkiverad som äldre, fristående utdata; presenteras inte som aktuell. |
| Rot/versionshantering | Ny branch och basversionscommit; AGENTS, renv-lås, teststruktur, CI, ignore-regler och tredjepartsnotiser. Lokala Finder-filer bevarade men ospårade. |

Utförda filflyttar finns i `docs/archive/v1/relocation-manifest.json`. Tekniska kontroller och slutlig exportversion finns i `results/verification.json`. Ursprung/licens för ärvd geometri, oberoende faktagranskning och kvarvarande källluckor är öppet redovisade underlagsbegränsningar, inte godkända fakta.
