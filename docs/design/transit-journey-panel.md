# Transit journey panel

The travel icon and chevron beside a leg's time open one inline panel. The panel replaces both the old mode dropdown and the separate Travel options disclosure.

Palette reference: Paper #FAFBFE, Navy #111827, Card #1C212B, Muted ink #9BABBF, Action blue #389AF5, Unverified amber #DFA648. Implementation uses existing Navio theme and day-colour tokens; operator colours come from transit data. Existing IBM Plex Sans Thai supplies body text, controls and times. Times use tabular numbers, without introducing a separate display font.

```
[current mode v]  39 min  8.5 km                  [map focus]
  +-----------------------------------------------------+
  | Drive       Transit        Bike        Walk         |
  | Origin to destination                               |
  | All transit       MRT & rail       Bus              |
  |-----------------------------------------------------|
  | MRT & rail                                41 min    |
  | Walk > [Oedo Line] > [Keio New Line] > Walk           |
  | fare when supplied   walking time   transfer count   |
  | Details v                                           |
  |   Boarding / line / transfer / arrival timeline      |
  |-----------------------------------------------------|
  | next genuine alternative                            |
  |-----------------------------------------------------|
  | Google Maps                          Use transit    |
  +-----------------------------------------------------+
```

Left-aligned route rows use dividers to compare journeys. The operator line sequence is the strongest visual element. A shadcn Button selects each mode and transit preference; shadcn RadioGroup selects a journey independently of the shadcn Accordion used for station directions. All transit combines genuine rail and bus alternatives, including journeys from airports and hotels. Selecting a mode or a journey previews its geometry and walking connections on the map. The panel has no departure-time input. Unknown fares and unsupported regions remain explicit. Only confirmed results receive a Use this route action. Saving keeps its line and station sequence across reloads; schedules are refreshed rather than stored. Results include balanced and fewer-transfer searches, plus earlier alighting options only when both the existing transit ride and the final street walk are confirmed. Recommendations balance journey time, walking and transfers without a city-specific station preference.

Review against the brief: discard the duplicate menu, disclosure heading and repeated summary; avoid a grid of interchangeable route cards. Keep the compact mode comparison at the top, then use transit-specific line chains, schedules and station sequences. Keyboard users toggle the same icon control and details buttons; mobile rows wrap without horizontal scrolling. The response contract is independent of Google so a GTFS-based engine can later supply the same journeys.
