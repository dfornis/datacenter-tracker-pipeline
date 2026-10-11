# Country Overlay: SE

Country: `SE`

Country name: Sweden

Bidding zones: `SE1`, `SE2`, `SE3`, `SE4`

## Source language and search posture

Search in Swedish and English. Use Swedish terms for public records, grid material, and local news, and English terms for international company announcements and trade press.

Useful search terms include `datacenter`, `data center`, `datorhall`, `serverhall`, `AI-center`, `beräkningscenter`, `molnregion`, `campus`, `bygglov`, `detaljplan`, `miljöprövning`, `samråd`, `tillstånd`, `elnätsanslutning`, and `anslutning`.

## Capacity-basis wording

- IT load: `IT-effekt`, `IT-kapacitet`, `kritisk IT-last`, `kritisk last`, `compute capacity`, `MW IT`
- Facility total: `total effekt`, `anläggningseffekt`, `effektbehov`, `elförbrukning`, `kapacitet`
- Grid connection: `anslutningseffekt`, `anslutningskapacitet`, `abonnerad effekt`, `tilldelad effekt`, `nätanslutning`, `effektuttag`, `uttagsabonnemang`
- Backup generation: `reservkraft`, `dieselgenerator`, `nödgenerator`, `backupkraft`

## Priority sources

Prioritize company releases and project pages, then Swedish public records and grid/energy sources:

- Svenska kraftnät for transmission-grid context and large-connection material: https://www.svk.se/
- Energimarknadsinspektionen for energy-market and network-regulation material: https://ei.se/
- Mark- och miljödomstolar, municipal planning records, building permits, environmental permits, and consultation documents
- Municipal and regional records using `kommun`, `kommunstyrelse`, `byggnadsnämnd`, `detaljplan`, and `samråd`

Use Data Center Dynamics as shared trade press. Local Swedish business, municipal, and regional media can support a candidate when primary evidence is missing, but do not let a local article override a stronger primary source without a conflict row.

## Administrative naming

Use `municipality` for Swedish `kommun`. Use `county` for `län`. Canonical names come from `data/master/admin_units.csv` using Swedish source names from SCB.
