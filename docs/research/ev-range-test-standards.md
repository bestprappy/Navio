# EV range test standards and real-world range

Why Navio shows two ranges for a catalogue EV (the official test figure and a real-world estimate), where the conversion factors come from, and how far they can be trusted.

Code: `REAL_WORLD_RANGE_FACTOR` and `estimateRealWorldRange` in `client/app/feature/planner/planId/_components/garage/vehicle-mappers.ts`. The same factors derive the default kWh/100 km when a driver saves a catalogue car without entering their own consumption.

## Factors in use

| Standard | Factor | Example: 400 km official | Main basis |
| --- | --- | --- | --- |
| NEDC | 0.70 | ~280 km | EPA's 0.7 default for raw lab range [1]; real-world consumption ~38% above NEDC [5] |
| CLTC | 0.70 | ~280 km | CLTC range within ~2% of NEDC for the same car [2] |
| WLTP | 0.85 | ~340 km | Real-world consumption ~14% above WLTP [5]; ICCT corrects WLTP BEV values with ADAC Ecotest data [6] |
| EPA | 0.90 | ~360 km | EPA label already includes the 0.7 (or 5-cycle) adjustment [1]; the remaining margin covers heat, speed and load |

Custom vehicles have no known test standard, so no estimate is shown for them.

**Where the adjustment is applied.** The planner's range is `battery kWh ÷ consumption`. The real-world factor is applied once, to consumption, and battery capacity stays as declared. Reducing capacity as well would count the same loss twice. A driver can replace the estimate with their own full-charge range (or kWh/100 km) in the garage; the range is converted to consumption before it is saved.

Converting a consumption gap into a range factor: if real-world consumption is X% higher, range is multiplied by `1 / (1 + X/100)`. For example, +38% gives ×0.72 and +14% gives ×0.88.

## What the standards are

- **NEDC** (New European Driving Cycle): European lab cycle from the 1970s–80s, last revised in 1997. It averages about 34 km/h, peaks at 120 km/h only briefly, idles about 25% of the time, and runs with climate control off. The EU replaced it with WLTP in 2017–2018, but some Asian spec sheets still quote it.
- **CLTC** (China Light-duty Vehicle Test Cycle): China's replacement for NEDC since 2019. It has lower average speed and more idling than WLTP, so its range figures are about as optimistic as NEDC's.
- **WLTP** (Worldwide Harmonised Light Vehicles Test Procedure): current EU standard. It is faster and more dynamic than NEDC but still run in a lab at 23 °C with climate control off.
- **EPA** (US): runs city and highway lab cycles, then applies an adjustment to the published label (see below).

## Evidence

### [1] EPA's regulatory 0.7 factor (primary source)

US regulation requires EV range and consumption on the window sticker to be adjusted "to more accurately reflect the values that customers can expect to achieve in the real world". The default method multiplies raw city/highway range by **0.7**. A manufacturer may instead run extra hot, cold and high-speed cycles for a vehicle-specific factor. EPA's summary notes that "most EVs use… the 0.7 factor". Legal basis: 40 CFR 600.116-12(a)(6) and 600.210-12(d)(3).

- D. Good, *EPA Test Procedures for Electric Vehicles and Plug-in Hybrids* (draft summary), US EPA, 14 Nov 2017. <https://www.fueleconomy.gov/feg/pdfs/EPA%20test%20procedure%20for%20EVs-PHEVs-11-14-2017.pdf>
- US EPA, *Fuel Economy and EV Range Testing*. <https://www.epa.gov/greenvehicles/fuel-economy-and-ev-range-testing>

NEDC and CLTC, like EPA's unadjusted cycles, are gentle lab cycles with climate control off. Applying 0.7 to them matches the US regulator's own correction.

### [2] CLTC is about as optimistic as NEDC (peer-reviewed)

Liu, Z., Liu, S., & Zheng, T. (2022). The influence of NEDC and CATC type approval test procedure on the E-range of battery electric vehicles. *Energy Reports*, 8, 36–42. <https://www.sciencedirect.com/science/article/pii/S2352484721011483>. Moving from NEDC to the Chinese procedure (CATC, the basis of CLTC) raised measured range by only **2.20%** on average.

### [3] Speed raises consumption well above every lab cycle (peer-reviewed)

*A comparative investigation on the energy flow of pure battery electric vehicle under different driving conditions.* Applied Thermal Engineering (2025). <https://www.sciencedirect.com/science/article/abs/pii/S135943112500626X>. At a steady 120 km/h, consumption was **27.1%** above NEDC, **26.3%** above CLTC and **16.5%** above WLTC.

### [4] Counter-evidence: a smaller average gap (peer-reviewed)

Weiss, M., Cloos, K. C., & Helmers, E. (2020). Energy efficiency trade-offs in small to large electric vehicles. *Environmental Sciences Europe*, 32, 46. <https://doi.org/10.1186/s12302-020-00307-8>. Across 428 EVs, average certified consumption was 19 ± 4 kWh/100 km and real-world consumption 21 ± 4 kWh/100 km, a gap of only about **10%**. The certified values mix several standards, and the real-world data is mostly German Spritmonitor users in a mild climate.

This suggests the 0.70 factor is on the **cautious** side for mild mixed driving. For a trip planner, underestimating range is the safer mistake.

### [5] Consumer summaries of the per-standard gap (not peer-reviewed)

- J.D. Power, *Electric Vehicle Range Testing: Understanding NEDC vs. WLTP vs. EPA*. Real-world consumption about 38% above NEDC and 14% above WLTP. <https://www.jdpower.com/cars/shopping-guides/electric-vehicle-range-testing-understanding-nedc-vs-wltp-vs-epa>
- InsideEVs, *How To Convert Conflicting EV Range Test Cycles*. WLTP→EPA ×0.88, CLTC→WLTP ×0.81, CLTC→EPA ×0.72. <https://insideevs.com/features/343231/heres-how-to-calculate-conflicting-ev-range-test-cycles-epa-wltp-nedc/>

### [6] WLTP understates real consumption, especially in winter

- ICCT (2025), *Life-cycle greenhouse gas emissions from passenger cars*. It adjusts WLTP BEV consumption to real-world conditions using ADAC Ecotest deviations. <https://theicct.org/wp-content/uploads/2025/07/ID-392-%E2%80%93-Life-cycle-GHG_report_final.pdf>
- ADAC winter test, January 2026 (reported by taxi heute). On winter motorway driving, consumption averaged **57%** above WLTP, with a range of +40% to +69%. Examples: Tesla Model Y 600 → 406 km, VW ID.7 Tourer 593 → 360 km. <https://www.taxi-heute.de/en/news/winter-costs-driving-range-adac-tests-winter-suitability-electric-cars-31055.html>

Winter figures matter less for Thailand, but air-con in heat and traffic has a similar, smaller effect.

## Why one consumption rate cannot give an exact distance

`range = usable kWh ÷ kWh per km` assumes constant consumption, but consumption varies with:

1. **Speed**: aerodynamic drag grows with the square of speed [3].
2. **Elevation**: climbing costs energy, and regenerative braking recovers only part of it on the way down.
3. **Temperature and climate control**: air-con draws power continuously, which weighs most in slow traffic.
4. **Load, tyres and road surface**.
5. **Driving style**: hard acceleration and braking waste energy.
6. **Usable battery window**: trips are planned between about 10% and 80–90% State of Charge (SoC), not 0–100%.
7. **Battery ageing**: capacity falls as the battery degrades.

The factors are therefore **conservative planning estimates, not measured constants**. Drivers who know their average consumption from the trip computer should enter it; that value overrides the estimate.

## Verification status

- [1] was read in full from the primary PDF.
- [2], [3] and [4] numbers were taken from abstracts and search summaries, because the publishers blocked automated access. Open the papers and confirm the figures before citing them in the report. The [3] author list was not confirmed.
- [5] and [6] are secondary or press sources, useful as context but not as primary evidence.

Compiled 2026-09-22.
