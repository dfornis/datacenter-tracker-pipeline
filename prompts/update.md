# Uppdatera ett lands datacenterplaner

Läs landspaketet, README:s metod och config/pipeline.json. Använd befintliga projects, capacity och sources; skapa inte nya tabelltyper. Landets språk och elområden finns i konfigurationen. Spara faktisk modellidentitet i arbetsanteckningen om den är tillgänglig; hitta inte på den.

1. Gå igenom alla landets projekt: kandidater, operativa anläggningar, projekt utan MW och avbrutna projekt. Sök ändrade planer och framtida etapper vid befintliga anläggningar. Sök nya projekt genom operatörer, kommuner/tillstånd, nätägare och branschrapportering på landets språk.
2. Kontrollera fysisk identitet och tidigare namn. En kundinstallation kan ingå i ett campus. Sök hela projektindexet inklusive kandidater före nytt ID. Kalberg/Undheim och Blackhawk/Hypercos grannprojekt kräver särskild kontroll. Nebius Lappeenranta är P035; XTX Kajaani är P037.
3. Spara korta originalutdrag i sources med URL, faktiskt angivet datum och sida/avsnitt. Markera quote eller summary. En översättning/tolkning får inte bli originalcitat. Samma source_id kan stödja flera uppgifter.
4. Rätta fakta i capacity och projects. Bevara rapporterat MW och basis. Skilj IT, anläggning, nät, reservkraft och generation. Skilj första kapacitet, full kapacitet, nätår och byggstart. Lägg inte beräknade datum i källfält. MW kan vara tomt.
5. Sätt status/beslut för rätt etapp. Project-status är en översikt. Tillstånd, kundintresse eller markarbete betyder inte automatiskt att hela campuset är beslutat eller under byggnation. Företag, myndighet och nätägare stöder olika slags uppgifter.
6. Använd parent_id/relation för kapacitet inom en större ram. Baseline_id gäller jämförbar installerad drift; okänd bas är existing_unknown. Beskriv osäkert överlapp kort; modellen ska hantera det utan att båda projekten försvinner.
7. Lägg ofullständiga nya projekt som record_type=candidate i samma tabell. Spara källan även utan MW. Okänt elområde är tomt. Lös related_project_id innan kandidaten räknas som separat campus. Använd högre, oanvända ID:n; byt inte ID på befintliga projekt.
8. Kontrollera ändrade kopplingar, stora MW-bidrag, avbrutna projekt och konflikter i en andra genomläsning. Ange om samma agent gör den; kalla den inte oberoende granskning. Bevara osäkerhet utan att radera projektet.
9. Kör metodtest och kontroll på hela den förberedda tabelluppsättningen. Varje projekt ska finnas i en meningsfull indikator, och användbara kapacitetsuppgifter i potential eller tidsatt scenario. Kontrollera oväntat tomma elområden och stora bortfall. Rätta orsaken utan att hitta på MW eller göra antagna datum till fakta.
10. Leverera de tre tabellerna som en sammanhängande Git-ändring. Redovisa i chatten: ändringar, nya projekt, MW/TWh per elområde och scenario, antaganden och de viktigaste kvarstående frågorna. Ange använda sökvägar och vad som inte kunnat granskas i en kort arbetsanteckning; skapa inte en fältchecklista för varje tänkbart tomt fält.

Modellen föreslår och belägger fakta; kod räknar och kontrollerar struktur. Saknad ny granskningsmetadata är aldrig ensam grund för att utesluta en befintlig bedömning. Rådata och scenarioantaganden hålls isär.
