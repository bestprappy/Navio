#!/usr/bin/env node
// Seeds Explore with real, fully working plans.
//
// Every plan goes through the same API a user's browser does: the trip is
// created, its stops are real Google places resolved by the mobility service
// (so they carry a place id, coordinates, photo and rating), the itinerary is
// saved through the planner autosave route, and the plan is published with
// listInExplore. The publication snapshot is therefore written by
// PlanPublicationSanitizer like any organic plan: it opens, maps and copies.
//
// It talks to trip-planning and mobility directly with X-User-Id, the header the
// gateway injects after validating a JWT. Run it only where those ports are
// private: locally, or on the VM inside the navio-backend network (see README).
//
// Idempotent: a plan whose title already exists among the seed user's trips is
// skipped, so a partial run can simply be re-run.

import { plans } from "./plans.mjs";

const env = process.env;
const TRIP_URL = (env.TRIP_URL ?? "http://localhost:8082").replace(/\/$/, "");
const GEO_URL = (env.GEO_URL ?? "http://localhost:8083").replace(/\/$/, "");
const USER_ID = env.SEED_USER_ID ?? "";
const AUTHOR = env.AUTHOR_NAME ?? "Navio Team";
const START_DATE = env.START_DATE ?? "2026-12-01";
const DRY_RUN = env.DRY_RUN === "1";
const ONLY = (env.ONLY ?? "").split(",").map((s) => s.trim()).filter(Boolean);
const PAUSE_MS = Number(env.PAUSE_MS ?? 150);

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
if (!UUID_RE.test(USER_ID)) {
  console.error("SEED_USER_ID must be the seed account's Keycloak user id (a UUID).");
  process.exit(1);
}

const DAY_COLORS = ["teal", "cyan", "blue", "emerald", "amber", "pine", "navy", "slate"];
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function call(base, method, path, body) {
  const response = await fetch(`${base}${path}`, {
    method,
    headers: {
      "X-User-Id": USER_ID,
      Accept: "application/json",
      ...(body ? { "Content-Type": "application/json" } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  if (!response.ok) {
    const error = new Error(`${method} ${path} -> ${response.status} ${text.slice(0, 300)}`);
    error.status = response.status;
    throw error;
  }
  return text ? JSON.parse(text) : null;
}

const trip = (method, path, body) => call(TRIP_URL, method, path, body);
const geo = (path) => call(GEO_URL, "GET", path);

function distanceKm(a, b) {
  const rad = (d) => (d * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.sqrt(h));
}

function addDays(iso, days) {
  const date = new Date(`${iso}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

let idCounter = 0;
const clientId = (prefix) => `${prefix}-${Date.now().toString(36)}-${(idCounter++).toString(36)}`;

async function searchPlace(query, near) {
  const params = new URLSearchParams({ query });
  if (near) {
    params.set("lat", String(near.lat));
    params.set("lng", String(near.lng));
  }
  const result = await geo(`/v1/geo/places/search?${params}`);
  await sleep(PAUSE_MS);
  return result?.items?.[0] ?? null;
}

function toPlaceItem(place, stop) {
  return {
    id: clientId("place"),
    type: "place",
    placeId: place.providerPlaceId,
    name: place.name,
    description: place.description ?? place.category ?? undefined,
    address: place.address ?? place.location?.address ?? "",
    lat: place.location.lat,
    lng: place.location.lng,
    rating: place.rating ?? undefined,
    reviewCount: place.reviewCount ?? undefined,
    imageUrl: place.photoUrl ?? undefined,
    notes: stop.note,
    isVisited: false,
    time: stop.time,
    timeEnd: stop.timeEnd,
  };
}

function estimatedChargeMinutes(maxKw) {
  if (maxKw >= 100) return 35;
  if (maxKw >= 50) return 50;
  if (maxKw >= 22) return 90;
  return 150;
}

async function resolveCharger(stop, destination) {
  const anchor = await searchPlace(stop.chargerNear, destination);
  if (!anchor) return null;
  const { lat, lng } = anchor.location;
  const params = new URLSearchParams({ lat: String(lat), lng: String(lng), radiusKm: "20" });
  const result = await geo(`/v1/ev/chargers/near?${params}`);
  await sleep(PAUSE_MS);
  const charger = [...(result?.items ?? [])]
    .filter((c) => c.status !== "OFFLINE" && c.location)
    .sort((a, b) => b.maxKw - a.maxKw)[0];
  if (!charger) return null;
  return {
    id: clientId("place"),
    type: "place",
    placeId: `ev-charger:${charger.id}`,
    name: charger.name,
    description: `EV charging station - ${charger.connectorTypes.join(", ")} - up to ${charger.maxKw} kW`,
    address: charger.address ?? "",
    lat: charger.location.lat,
    lng: charger.location.lng,
    notes: stop.note,
    isVisited: false,
    time: stop.time,
    timeEnd: stop.timeEnd,
    evCharger: {
      connectorTypes: charger.connectorTypes,
      maxKw: charger.maxKw,
      totalConnectors: charger.totalConnectors,
      availableConnectors: null,
      priceText: charger.priceText ?? null,
      openingHoursSummary: charger.openingHours?.summary ?? null,
      estimatedChargeMinutes: estimatedChargeMinutes(charger.maxKw),
      operatorName: charger.operatorName ?? null,
      selectionSource: "MANUAL",
      locked: false,
    },
  };
}

async function buildBlocks(plan, destination, startDate) {
  const maxKm = plan.radiusKm ?? 80;
  const blocks = [];
  let placeCount = 0;

  for (const [dayIndex, day] of plan.days.entries()) {
    const date = addDays(startDate, dayIndex);
    const items = [];
    for (const stop of day) {
      if (stop.chargerNear) {
        try {
          const charger = await resolveCharger(stop, destination);
          if (charger) items.push(charger);
          else console.warn(`   ~ no charger near "${stop.chargerNear}", skipped`);
        } catch (error) {
          console.warn(`   ~ charger lookup failed near "${stop.chargerNear}": ${error.message}`);
        }
        continue;
      }
      const place = await searchPlace(stop.q, destination);
      if (!place?.location) {
        console.warn(`   ~ no result for "${stop.q}", skipped`);
        continue;
      }
      const km = distanceKm(destination, place.location);
      if (km > maxKm) {
        console.warn(`   ~ "${stop.q}" resolved to ${place.name} ${Math.round(km)} km away, skipped`);
        continue;
      }
      items.push(toPlaceItem(place, stop));
      placeCount++;
    }
    blocks.push({
      id: `day-${date}`,
      kind: "itinerary",
      title: date,
      date,
      colorId: DAY_COLORS[dayIndex % DAY_COLORS.length],
      items,
    });
  }
  return { blocks, placeCount };
}

async function existingTitles() {
  const titles = new Set();
  for (let page = 0; page < 50; page++) {
    const result = await trip("GET", `/v1/trips?page=${page}&size=100`);
    for (const t of result?.content ?? []) if (t.displayName) titles.add(t.displayName);
    // Spring serialises Page either flat ({ last, totalPages }) or as a PagedModel ({ page: { totalPages } }).
    const totalPages = result?.totalPages ?? result?.page?.totalPages ?? 1;
    if (page + 1 >= totalPages) break;
  }
  return titles;
}

async function seedPlan(plan, index, skipTitles) {
  const label = `[${index + 1}/${plans.length}] ${plan.title}`;
  if (skipTitles.has(plan.title)) {
    console.log(`${label}: already seeded, skipped`);
    return "skipped";
  }
  console.log(`${label}`);

  const destinationPlace = await searchPlace(plan.destination);
  if (!destinationPlace?.location) throw new Error(`destination "${plan.destination}" not found`);
  const destination = destinationPlace.location;

  const startDate = addDays(START_DATE, index * 3);
  const { blocks, placeCount } = await buildBlocks(plan, destination, startDate);
  const minPlaces = Math.max(3, plan.days.length * 2);
  if (placeCount < minPlaces) {
    throw new Error(`only ${placeCount} places resolved (need ${minPlaces}); not publishing a thin plan`);
  }

  if (DRY_RUN) {
    for (const block of blocks) console.log(`   ${block.date}: ${block.items.map((i) => i.name).join(" -> ")}`);
    return "dry-run";
  }

  const created = await trip("POST", "/v1/trips", {
    displayName: plan.title,
    startDate,
    endDate: addDays(startDate, plan.days.length - 1),
    destinationId: destinationPlace.providerPlaceId,
  });

  const planner = await trip("GET", `/v1/trips/${created.id}/planner`);
  const saved = await trip("PUT", `/v1/trips/${created.id}/planner`, {
    version: planner.version,
    blocks,
    budget: planner.budget ?? undefined,
  });

  const publish = (expectedTripVersion) =>
    trip("PUT", `/v1/trips/${created.id}/publication`, {
      expectedTripVersion,
      expectedRevision: null,
      options: { includeDates: false, includeNotes: true, includeBudget: false },
      listInExplore: true,
      authorDisplayName: AUTHOR,
      title: plan.title,
    });

  let publication;
  try {
    publication = await publish(saved.version);
  } catch (error) {
    if (error.status !== 409) throw error;
    const fresh = await trip("GET", `/v1/trips/${created.id}/planner`);
    publication = await publish(fresh.version);
  }

  console.log(`   published: ${placeCount} places, token ${publication.token?.slice(0, 6)}...`);
  return "published";
}

async function main() {
  const selected = ONLY.length ? plans.filter((p) => ONLY.includes(p.slug)) : plans;
  console.log(`Seeding ${selected.length} plans as ${USER_ID} ("${AUTHOR}")${DRY_RUN ? " [dry run]" : ""}`);
  console.log(`trip=${TRIP_URL} geo=${GEO_URL}\n`);

  const skipTitles = DRY_RUN ? new Set() : await existingTitles();
  const tally = { published: 0, skipped: 0, "dry-run": 0, failed: 0 };

  for (const plan of selected) {
    try {
      tally[await seedPlan(plan, plans.indexOf(plan), skipTitles)]++;
    } catch (error) {
      tally.failed++;
      console.error(`   ! failed: ${error.message}`);
    }
  }

  console.log(`\nDone: ${JSON.stringify(tally)}`);
  process.exit(tally.failed ? 1 : 0);
}

main();
