# EV simulation proposal review

Reviewed 2026-09-22 against the supplied proposal, the current working tree, and primary documentation. This is an assessment, not an implementation or empirical validation of prediction accuracy.

## Recommendation

Adopt the simulation-based research scope and extend the existing planner incrementally. A physical EV is not required for a simulation study. Claims must remain about model estimates and benchmark agreement until independent measured data supports real-world accuracy. Do not replace the existing application or promise that a more complicated model is automatically more accurate.

## Existing implementation

- `client/app/feature/planner/planId/_components/garage/ev-calculator.ts`: distance-times-consumption baseline, SOC projections, connector checks, charging targets, and constant-power charging calculations. Default reserve is 12%.
- `server/mobility-and-ev-service/src/main/java/com/navio/mobilityandevservice/service/optimization/SocConstrainedRouteOptimizer.java`: SOC-constrained search over candidate chargers, partial charging, time and reliability costs, 5% charge buckets, a 1.12 energy margin, and a generic charging taper above 80%.
- `server/mobility-and-ev-service/src/main/java/com/navio/mobilityandevservice/provider/google/GoogleRoutesAdapter.java`: traffic-aware route/leg distance, duration and polylines. No elevation or detailed speed trace; alternative routes are disabled.
- `client/app/feature/planner/planId/_components/garage/vehicle-api.ts`: catalogue test standard, source URL, check date, and manufacturer-declared battery capacity. Usable capacity is not established by that field.
- `client/app/feature/planner/planId/_components/garage/vehicle-mappers.ts`: estimated consumption uses range factors NEDC/CLTC 0.70, WLTP 0.85, EPA 0.90. These are application assumptions, not established conversions between test procedures.

The immediate engineering issue is divergent frontend/backend energy and charging calculations. Keep nominal energy, planning margin, and minimum reserve distinct. The present backend also approximates detour distance/time; the optimization service returns the search result without a final routed re-evaluation through the selected chargers.

## Corrections needed in the proposal

1. **Energy boundary:** distinguish gross, usable and manufacturer-declared capacity, and battery-side versus wall-side consumption. EPA MPGe includes charging losses. Do not subtract wall-side energy directly from battery SOC. Use usable capacity for SOC; mark an assumed capacity explicitly when unavailable. Battery/range is a derived reference estimate, not measured consumption.
2. **Route inputs:** Google traffic intervals classify NORMAL/SLOW/TRAFFIC_JAM; they do not provide a second-by-second numerical speed/acceleration trace. Obtain elevation separately and document sampling/smoothing and terrain limitations. Distance/duration gives an average speed only. Any finer speed profile must be labeled synthetic. Acceleration can be studied on known drive cycles without pretending it is measured for a Google route.
3. **Physics completeness:** force equations alone are not a battery-energy model. Integrate wheel power over time and apply drivetrain efficiency, bounded regeneration, and battery-side auxiliary load. Use consistent SI units and divide joules by 3,600,000 for kWh. Rolling resistance can include cos(slope); the flat-road approximation in the proposal is acceptable when documented. Regeneration must respect power and battery headroom; downhill energy is not recovered at 100%. Do not add a full physics estimate to rated consumption and count the same losses twice.
4. **Charging:** use the lesser of compatible charger power and the vehicle's SOC-dependent acceptance, with clearly defined efficiency and connection overhead. The proposed curve is illustrative, not a universal EV curve. Store provenance or an explicit generic fallback. Do not apply DC taper blindly to AC charging.
5. **Feasibility and optimization:** enforce reserve along the route, including an uphill minimum before a downhill recovery. Use actual routed charger access rather than geometric proximity alone; re-evaluate the selected itinerary. Do not double-count detour time if already included in routed driving time. Report an optimum only within the candidate routes, chargers and SOC discretization searched. Unknown availability is not confirmed availability.
6. **Validation:** replay compatible drive cycles/conditions and align energy boundaries and label adjustments before comparing EPA/WLTP values. A generic road route versus a certification label is not a controlled accuracy test. Do not derive consumption from a published range and then use reproduction of that same range as validation. Separate fitting and evaluation data. FASTSim agreement is cross-model benchmarking, not physical validation of Navio; use matched inputs and record the software version.
7. **Interpretation:** a reserve violation means the plan fails the configured model policy; it does not establish physical danger. Conversely, predicted compliance does not establish real-world safety. Synthetic stress scenarios establish sensitivity, not measured prediction accuracy.
8. **References and vehicle selection:** replace placeholder bibliography entries with exact pages/datasets, versions, publication dates where available, and access dates. Select 3-5 exact year/trim/market combinations for which defensible parameters and reference data exist. Do not assume a US EPA trim equals a Thai-market vehicle. UNECE defines the test procedure; it is not itself a complete vehicle-specification catalogue.

## Corrected section 24 example

For usable capacity 60 kWh, start 80%, consumption 16 kWh/100 km, no detour or extra margin:

- First 190 km uses 30.4 kWh; charger arrival is 29.33%, not 27%.
- Charging to 65% adds 21.4 kWh.
- Remaining 110 km uses 17.6 kWh; destination SOC is 35.67%, not 34%.
- Charging duration cannot be derived without power/curve assumptions. At constant 100 kW delivered into the battery, the ideal time is 12.84 minutes before overhead.
- For a 10% destination reserve on this simplified route, the minimum departure SOC is 39.33%; charging to 65% is not demonstrated to minimize time. Actual planning must also account for detours, uncertainty and other constraints.

The other displayed arithmetic examples (32 kWh over 200 km, 14.29 kWh/100 km from 60/420, 30% arrival after 30 kWh usage, 18 ideal minutes for 30 kWh at 100 kW, and 2.67% range error) are arithmetically consistent with their assumptions.

## Suggested implementation order

1. Establish a versioned energy/charging contract in mobility-and-ev-service, consumed by optimization and displayed projections. Keep a clearly labeled baseline available, including for insufficient vehicle data. Align frontend/backend results and expose assumptions/margins. Extend existing vehicle provenance to capacity/consumption basis and model parameters; follow the repository's additive database-change workflow when implementation is authorized.
2. Create reproducible baseline experiments and independent reference cases before tuning. Choose a small, well-documented vehicle set. Keep FASTSim in an offline evaluation harness; a new deployed Python service is unnecessary.
3. Add a selectable segment model for grade, speed assumptions, drivetrain losses, bounded regeneration and auxiliary load. Introduce acceleration only with defined time-series inputs. Verify units, conservation, saturation, and SOC minimum along the route. Report scenario ranges until uncertainty is empirically calibrated.
4. Reuse and improve the existing optimizer with charging curves and routed detours. Compare fastest candidate route plus feasible charging, nearest reachable compatible charger, always-to-100%, and optimized targets under identical inputs and constraints. Report infeasible baselines explicitly rather than treating an unfinishable shortest route as a fair time comparison.
5. Evaluate held-out energy error (kWh and kWh/100 km), SOC error in percentage points when independent SOC data exists, reserve violations, total driving/charging/overhead time, and stop counts. Use brute-force small graph cases to verify optimization. Define success thresholds before evaluation; do not advertise a numerical accuracy target as achieved without results.

The research contribution should be an evaluated comparison of a simple baseline, a bounded route-aware model, and charging strategies. Merely reproducing plausible trip screens is not evidence of prediction accuracy.

## Primary sources checked

- [EPA: Fuel Economy and EV Range Testing](https://www.epa.gov/greenvehicles/fuel-economy-and-ev-range-testing): wall-side charging losses, laboratory cycles, label adjustments and weighting. Page reports updated July 1, 2026.
- [Google: Route traffic polylines](https://developers.google.com/maps/documentation/routes/traffic_on_polylines): traffic categories and route/leg intervals.
- [Google: Elevation API overview](https://developers.google.com/maps/documentation/elevation/overview) and [path sampling](https://developers.google.com/maps/documentation/elevation/requests-elevation).
- [NLR: FASTSim](https://www.nlr.gov/transportation/fastsim) and [Python distribution](https://www.nlr.gov/transportation/fastsim-download-confirmed).
- [FASTSim Validation Report, 2021](https://research-hub.nlr.gov/en/publications/future-automotive-systems-technology-simulator-fastsim-validation/).
- [UNECE: UN Regulation No. 154 Rev. 1](https://unece.org/transport/documents/2021/08/standards/un-regulation-no-154-rev1): official search listing confirmed; full page fetch failed during review, so no detailed annex requirements were verified.

No application changes, model experiments, live API calls, or test runs were performed for this review.
