# EV real-world range: evidence and Navio planning policy

Reviewed 2026-11-16. Scope: all battery-electric vehicles represented by Navio's Garage, including catalogue/custom vehicles, every supported range standard, pack size and chemistry. This is a road-trip planning policy, not a battery laboratory model or a guarantee of actual range.

## Decision and limits

Preserve manufacturer/reference range, test standard, source and battery capacity. Apply a **20% range planning allowance** to rated-range models and explicitly manufacturer/regulatory consumption models. Use the resulting estimate throughout the planner and server-side charging calculation. Show the unmodified figures alongside the allowance.

Twenty percent is a **Navio product assumption**, informed by observed range variability. No paper establishes it as a universal correction for every model, standard, chemistry, temperature or journey. It is not a confidence interval, an inferred loss of physical battery capacity or a fitted weather model. Under adverse conditions the actual shortfall can exceed the allowance; some vehicles can also exceed their label range.

NEDC, WLTP, EPA and CLTC are test standards, not battery chemistries. The policy has no make/chemistry allowlist: an LFP, NMC or other battery is handled through the vehicle's own range/consumption and capacity data. It does not pretend that all chemistries have the same cold-weather or aging behavior. Navio does not currently store sufficient route-specific weather, speed, mass, HVAC, state-of-health or elevation evidence for a calibrated physical model.

User-observed consumption already represents real use and is used without a second automatic deduction. Unconfirmed consumption also stays unadjusted and labelled unconfirmed, rather than falsely acquiring factory or measured provenance. A custom vehicle with only a reference range uses the same 20% rated-range allowance as a catalogue vehicle. A custom vehicle with an observed average uses that average directly. These are input-basis distinctions, not battery-type exceptions.

EPA's published label already incorporates adjustments. Navio does **not** apply EPA's laboratory-to-label factor again. Its 20% allowance is additional, explicitly stated trip-planning headroom even when the selected label is EPA; it must not be described as an EPA-required correction.

## Downloaded evidence

All four PDFs were downloaded from publisher/organization hosts and checked for PDF content and readable pages. See [papers-manifest.json](papers-manifest.json) for byte sizes, page counts and SHA-256 hashes. Keep original authorship and notices. Two papers are open-access research articles; the other two are primary research/test reports.

| Source | Local PDF | Relevant finding and limitation |
| --- | --- | --- |
| Weiss, Winbush, Newman & Helmers (2024), *Energy Consumption of Electric Vehicles in Europe*, Sustainability 16, 7529. [DOI](https://doi.org/10.3390/su16177529) | [Paper](papers/weiss-2024-energy-consumption-europe.pdf) | Examines a European model dataset with certified and real-world consumption/range estimates. Vehicle characteristics and operating assumptions matter. The real-world dataset is not an independent road test of every vehicle; it does not justify calling a blanket allowance a measured result. |
| Cheng et al. (2025), *Analysis of the Effects of Different Driving Cycles on the Driving Range and Energy Consumption of BEVs*, World Electric Vehicle Journal 16, 124. [DOI](https://doi.org/10.3390/wevj16030124) | [Paper](papers/cheng-2025-driving-cycles-bev.pdf) | Compares NEDC, WLTC and CLTC-P through simulation and comparisons with vehicle data. Driving cycles, acceleration, speed and auxiliaries affect range. It supports preserving test-standard provenance and disclosing assumptions, not a universal 20% chemistry conversion. |
| Jin, Wang & He (ICCT, April 2023), *Real-world performance of battery electric passenger cars in China: Energy consumption, range, and charging patterns*. [Publisher](https://theicct.org/publication/pv-china-real-world-performance-apr23/) | [Report](papers/icct-2023-real-world-passenger-bevs.pdf) | Analyzes over 140,000 private-use vehicles across ten high-selling models and five Chinese cities. Temperature and speed materially change real-world consumption and range. High-speed consumption increases in the reported analysis are 20-35%; cold conditions can be worse. Those are condition-specific results, not a universal 20% range loss or a Thailand calibration. |
| Australian Automobile Association (2025), 2023 BYD Atto 3 Extended Range real-world testing. [Original PDF](https://realworld.org.au/wp-protected/7ea00f8c93ec/uploads/2025/08/AUG25_BYD-Atto-3_WEB.pdf) | [Report](papers/aaa-2025-byd-atto-3-road-test.pdf) | Reports 480 km lab range versus 369 km road-test range, a 23% shortfall, under its Australian test conditions. This is evidence for that vehicle/test; 384 km is the distinct result of applying Navio's chosen 20% allowance to 480 km. |

Additional primary references: [EPA range testing](https://www.epa.gov/greenvehicles/fuel-economy-and-ev-range-testing) explains its laboratory-to-label adjustment and charging-loss boundary; [U.S. DOE AFDC](https://afdc.energy.gov/vehicles/electric-basics-ev) explains driving-condition effects. Wall-side consumption includes charging losses and must not silently become battery-side driving consumption. Navio's existing catalogue-default evidence rules still apply.

## Calculation contract

`navio-energy-v2` preserves the existing nominal fields and adds explicit planning fields:

```text
Factory-based range retention = 1 - 20 / 100 = 0.8
Observed/unconfirmed consumption retention = 1

Rated-range model:
  planning range = original rated range x retention
  nominal battery use (percentage points) = distance / original rated range x 100
  planning battery use = nominal battery use / retention

Consumption model:
  nominal driving kWh = distance x selected kWh/100 km / 100
  planning driving kWh = nominal driving kWh / retention
  planning battery use (percentage points) = planning driving kWh / calculation capacity x 100

Predicted arrival % = departure % - planning battery use
```

A 20% shorter range means **25% more consumption per kilometre**, because `1 / 0.8 = 1.25`. Multiplying consumption by 1.2 would produce a different policy.

Worked rated-range example: 480 km remains the factory figure; planning range is 384 km. A 96 km leg uses 25 percentage points rather than the nominal 20. A start at 80% predicts a 55% arrival. A 60 kWh calculation capacity remains 60 kWh.

Worked factory-consumption example: 18 kWh/100 km becomes 22.5 kWh/100 km for planning. Over 100 km with 60 kWh calculation capacity, the planned depletion is 37.5 percentage points; an 80% start predicts 42.5%. A user-observed 18 kWh/100 km remains 18, producing 50% arrival for the same distance/capacity/start.

Only driving expenditure receives the allowance. Charging adds actual modeled kWh into the unchanged calculation capacity; applying the factor again to charging would double count. Connector/vehicle power limits, saved charge targets, observations and chronological carry-forward retain their existing rules. Observed SoC updates the future state; it does not rewrite predicted history. Missing inputs stay unavailable, and a negative predicted arrival stays infeasible even if the display gauge is bounded.

## API and rollout

- Vehicle profile storage remains version 1. Original specifications are not overwritten; no entity or migration changes are needed.
- Canonical calculation policy is `navio-energy-v2`. Results add `planningEnergyKwh`, `planningSocUsePct`, and `rangeReductionPct`; existing `nominalEnergyKwh`/`nominalSocUsePct` retain their original meanings.
- The internal optimization energy model adds optional, validated `consumptionSource`. Trip Planning derives it from the owned, persisted snapshot, not client-supplied vehicle specifications.
- Mobility optimization responses add `energyPolicyVersion`. Trip Planning refuses a factory-based preview/apply from an older/mismatched Mobility response.
- Planner snapshots advertise `real-world-energy-v2`. The frontend refuses an adjusted charging preview on an older Trip Planning backend, keeping the interface from presenting an unadjusted server calculation as matching the new model.
- The release must ship the client, Trip Planning and Mobility changes together. No production release is implied by this implementation task.

## UI design decision

Use the established Navio palette, not new brand colors: Paper `#FAFBFE`, Navy `#060A21`, Primary `#008CFF`, Muted `#555B66`, Border `#D1D4DB`, White `#FFFFFF` (sRGB approximations of current light tokens). Dark mode continues to use existing semantic tokens. Plus Jakarta Sans and tabular numbers match the planner.

The comparison belongs inside the existing vehicle card. A two-column definition list aligns the original range at left and the planning range at right, with one short comparison bar and an explicit allowance badge. Declared capacity remains visible. A shadcn Accordion explains the model, input exceptions, EPA boundary and research source with keyboard support. This uses the trip's content to communicate the calculation rather than introducing a separate dashboard or decorative card grid. Factory consumption and observed-average views explain their own basis instead of implying every planning range is derived directly from the factory range.

## Verification

Shared TypeScript/Java golden fixtures cover nominal versus planning expenditure, source-specific treatment, exact range exhaustion, infeasible legs, charging, and observations. Frontend checks cover all supported range standards and multiple pack sizes, factory-data immutability, corrected remaining range, accessible comparison rendering and old-server rejection. Service tests cover provenance forwarding and mixed-version preview/apply rejection. The scene-7 video narration must use the implemented formula and describe 20% as Navio's allowance rather than a scientific constant.

Results for this implementation:

- Frontend energy/garage regression suite: 122 tests, all passed. After final display wording/bar refinements, the focused render/route suite passed 17/17 again.
- Mobility: 270 tests, zero failures/errors, seven existing environment-dependent skips; shared Java/TypeScript fixtures are identical.
- Trip Planning unit/WebMvc scope: 1,212 tests, zero failures/errors, 47 database-dependent skips. `VerificationTests` and `TripPlanningServiceApplicationTests` were excluded because they require external startup infrastructure; real PostgreSQL startup/schema checks were not run. No schema or entity changed.
- TypeScript and scoped ESLint pass. OpenAPI YAML parses, script spans ten contiguous scenes through 4:50 with 559 narration words, and all four PDF checksums match.
- Headless Chrome checked the real vehicle-card/comparison components at 1440 and 390 px in light and dark modes, including keyboard-operated disclosure, factory/observed/factory-consumption cases, and no horizontal overflow or page errors. Evidence is in local `output/real-world-energy/`; temporary preview route was removed and the preview server stopped. No real account/provider writes were used.

Trip test command (run from its service directory):

```powershell
./mvnw.cmd -o test `
  "-Dspring.cloud.config.enabled=false" `
  "-Dspring.cloud.config.import-check.enabled=false" `
  "-Dspring.config.location=optional:classpath:/navio-no-external-config.yml" `
  "-Dspring.test.context.cache.maxSize=4" `
  "-DargLine=-Xmx512m -XX:MaxMetaspaceSize=256m" `
  "-Dtest=!VerificationTests,!TripPlanningServiceApplicationTests"
```

The test-only config location avoids the required localhost Config Server import without editing application configuration. The bounded heap/context cache avoids the workstation's observed native-memory exhaustion when running many contexts. These flags do not constitute a production startup check.

## Dev integration on 2026-11-16

Merged and pushed through the service-first repository flow. Newer dev work was retained, including explicit provider search and the Auto Add itinerary-day numbering fix. Integrated checks passed: 134 frontend energy/garage/provider-search tests plus TypeScript; Mobility 289 tests, zero failures/errors and seven skips. The Trip Planning feature remains exactly the previously verified unit/WebMvc implementation (1,212 total, 47 skips); external startup/PostgreSQL checks remain unrun. No main merge or production deployment was performed.

- Client: feature commit `333f94f`, dev merge `116e5dc`.
- Trip Planning: feature commit `4e6840b`, dev merge `f6b054a`.
- Mobility & EV: feature commit `bcc0ac8`, dev merge `fba96c4`.
- Server: feature commit `c3d03ff`, dev merge `a193130`.
- Root pins: feature commit `0b3db09`, dev merge `b9d4de2`.
