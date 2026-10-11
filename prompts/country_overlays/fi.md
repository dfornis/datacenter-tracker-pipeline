# Country Overlay: FI

Country: `FI`

Country name: Finland

Bidding zones: `FI`

## Source language and search posture

Search in Finnish, Swedish, and English. Finnish public material often uses `datakeskus` or `konesali`; English company material often uses `data center` or `data centre`.

Useful Finnish search terms include `datakeskus`, `konesali`, `tekoäly`, `pilvipalvelu`, `rakennuslupa`, `asemakaava`, `ympäristölupa`, `sähköliittymä`, `kantaverkko`, `liittyminen`, `liityntä`, `sähkönkulutus`, `rakenteilla`, `rakentaminen alkaa`, and `rakentaminen käynnissä`.

Useful Swedish search terms for bilingual Finnish material include `datacenter`, `datacentral`, `serverhall`, `bygglov`, `detaljplan`, `miljötillstånd`, `elanslutning`, `anslutningseffekt`, `stamnät`, `elnät`, `under byggnad`, and `byggstart`.

Also search English company terminology: `data center`, `data centre`, `cloud region`, `AI data center`, `campus`, `grid connection`, and `power capacity`.

## Capacity-basis search clues

These terms are leads, not classification rules. Generic words for capacity, consumption or power do not by themselves establish IT load, facility nameplate or connection maturity. Read the scoped numerical statement. Requested, queued, reserved, contracted, available and energised capacity are different states.

- IT load: `IT-kapasiteetti`, `IT-kuorma`, `kriittinen IT-kuorma`, `laskentakapasiteetti`, `MW IT`
- Facility total: `kokonaisteho`, `tehontarve`, `sähköteho`, `laitoksen teho`, `kapasiteetti`
- Grid connection: `liityntäteho`, `liittymisteho`, `liittymiskapasiteetti`, `sähköliittymä`, `kantaverkkoliityntä`, `siirtokapasiteetti`
- Backup generation: `varavoima`, `dieselgeneraattori`, `hätävoima`

For Swedish-language Finnish sources, also use the Swedish terms from the SE overlay for capacity-basis classification, especially `IT-kapacitet`, `anslutningseffekt`, `elanslutning`, `effektbehov`, and `reservkraft`.

## Priority sources

Select sources by the field being checked. Operator releases, public decisions and grid records have different authority:

- Fingrid for main-grid connection process, connection terms, and grid context: https://www.fingrid.fi/en/grid/
- Fingrid Finnish connection material for `liittyminen kantaverkkoon`: https://www.fingrid.fi/kantaverkko/liitynta-kantaverkkoon/
- Energiavirasto, the Finnish Energy Authority, for regulatory and licensing context: https://www.energiavirasto.fi/
- Municipal records using `kunta`, `kaupunki`, `kaavoitus`, `asemakaava`, `rakennuslupa`, `ympäristölupa`
- Environmental assessment project pages and underlying decisions: https://www.ymparisto.fi/fi/osallistu-ja-vaikuta/ymparistovaikutusten-arviointi . Check the legal project company and physical site, particularly adjacent developments by related companies. Consult current Lupa- ja valvontavirasto decisions for 2026 status.

Use Data Center Dynamics as shared trade press. Also search Finnish business and regional outlets when primary sources are not enough, but treat them as secondary unless they cite public documents or named officials.

## Administrative naming

Use `municipality` for Finnish `kunta` or `kaupunki`. Use `county` for `maakunta`. Canonical names come from `input/admin_units.csv` in Finnish, with Swedish and English variants available for search.
