# Country Overlay: NO

Country: `NO`

Country name: Norway

Bidding zones: `NO1`, `NO2`, `NO3`, `NO4`, `NO5`

## Source language and search posture

Search in Norwegian and English. Norwegian public material often uses `datasenter`; English company material may use `data center` or `data centre`.

Useful search terms include `datasenter`, `data center`, `data centre`, `kunstig intelligens`, `skyregion`, `reguleringsplan`, `byggesak`, `konsesjon`, `nettilknytning`, `tilknytning`, `krafttilgang`, and `strømnett`.

## Capacity-basis search clues

These terms are leads, not classification rules. Generic words for capacity, consumption or power do not by themselves establish IT load, facility nameplate or connection maturity. Read the scoped numerical statement. Requested, queued, reserved, contracted, available and energised capacity are different states.

- IT load: `IT-kapasitet`, `IT-last`, `kritisk IT-last`, `kritisk last`, `beregningskapasitet`, `MW IT`
- Facility total: `total effekt`, `effektbehov`, `strømforbruk`, `kraftbehov`, `anleggseffekt`, `kapasitet`
- Grid connection: `tilknytningseffekt`, `tilknytningskapasitet`, `nettilknytning`, `reservert kapasitet`, `tildelt kapasitet`, `uttak`, `uttakskunde`
- Backup generation: `reservekraft`, `dieselaggregat`, `nødstrøm`

## Priority sources

Select sources by the field being checked. Operator releases, public decisions and grid records have different authority:

- Statnett for transmission-grid connection process and national grid context: https://www.statnett.no/nettkapasitet-til-produksjon-og-forbruk/hvordan-fa-okt-nettkapasitet/
- Statnett connection statistics distinguish reservations, queues and connected capacity; do not sum categories blindly: https://www.statnett.no/nettkapasitet-til-produksjon-og-forbruk/foresporsler-og-reservasjon-i-nettet/
- Elhub consumption is a separate, industry-code-based observation with coverage limitations, not a project nameplate register: https://elhub.no/data-og-innsikt/stromforbruk-i-datasentre
- NVE/RME for grid-connection obligations, large customers, licensing, and regulatory material: https://www.nve.no/
- DSB for electrical safety and emergency-preparedness material where relevant: https://www.dsb.no/
- Municipal records using `kommune`, `reguleringsplan`, `byggesak`, `planutvalg`, `formannskap`, `kommunestyre`

Use Data Center Dynamics as shared trade press. Also search Norwegian business, energy, and regional outlets when primary sources are not enough, and assess their field-specific support and independence rather than assigning confidence from publisher type alone.

## Administrative naming

Use `municipality` for Norwegian `kommune`. Use `county` for `fylke`. Canonical names come from `input/admin_units.csv` in Bokmål, with Nynorsk and English variants available for search.
