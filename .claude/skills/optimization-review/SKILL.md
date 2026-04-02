---
name: optimization-review
description: "Review Navio code for performance and efficiency issues across Next.js client and Java 25 Spring Boot services, then provide prioritized, low-risk optimization recommendations."
---

# Optimization Review Skill

## Use When

Use this skill when the user asks for performance review, optimization, bottleneck detection, scaling risk analysis, or render/query efficiency improvements.

## Review Objectives

1. Identify the biggest performance bottlenecks first.
2. Prioritize low-risk, high-impact improvements.
3. Preserve existing behavior unless explicitly asked to change it.
4. Keep recommendations measurable and testable.

## Navio Optimization Rules To Enforce

1. Respect architecture constraints (no cross-schema joins, no shared DTO coupling).
2. Keep Java 25 and Spring Boot compatibility intact for all optimization-related dependency decisions.
3. Client state and data flow expectations:
   - Jotai for UI state.
   - TanStack Query for API/server-state caching and invalidation.
4. Next.js App Router boundaries:
   - Keep server/client boundaries correct.
   - Avoid unnecessary client components.
5. Preserve API/security conventions while optimizing (`/v1`, `/internal/v1`, `X-Internal-Auth`, OpenAPI parity).

## Review Workflow

1. Map hotspots from changed code paths (UI rendering, API calls, DB access, event processing).
2. Estimate impact and frequency (hot path vs rare path).
3. Identify root causes (not just symptoms).
4. Propose minimal changes with expected impact, complexity, and risk.
5. Add verification guidance (benchmark, profile, regression checks).

## Client Optimization Checklist

1. Rendering:
   - Unnecessary re-renders from unstable props/callbacks.
   - Missing memoization for expensive derived values.
2. State:
   - Over-broad global state or duplicated state.
   - Misuse of client state for server state.
3. Data Fetching:
   - Missing TanStack Query caching/invalidation strategy.
   - Duplicate requests and unbounded refetching.
4. App Router:
   - Incorrect client/server split causing extra JS payload.
5. Bundle/UI:
   - Large client bundles, missing code-splitting/lazy loading.
   - Expensive list rendering without virtualization/pagination where needed.

## Server Optimization Checklist

1. Data Layer:
   - N+1 query risks, over-fetching, missing pagination.
   - Missing indexes for high-volume access patterns.
2. Service Layer:
   - Blocking operations on hot paths.
   - Repeated expensive transformations/serialization.
3. External Calls:
   - Missing timeouts/circuit breakers/retry strategy.
4. Events:
   - Inefficient outbox polling/dispatch loops.
   - Duplicate event handling risks and missing idempotency checks.
5. Caching:
   - Candidate read paths for Caffeine caching.
   - Incorrect TTL/invalidation assumptions.

## Required Output Format

1. Bottleneck summary (top issues first).
2. Findings by severity and impact: Critical, High, Medium, Low.
3. For each finding provide:
   - Title
   - File and line reference
   - Root cause
   - Performance impact (latency/throughput/resource cost)
   - Minimal optimization recommendation
   - Risk level and rollback note
   - Verification method (profile/benchmark/test)
4. Prioritized optimization plan (quick wins first).
5. Residual risks and measurement gaps.

## If No Findings

1. Explicitly state no significant optimization issues found.
2. Provide monitoring recommendations for future regressions.
