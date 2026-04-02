---
name: security-review
description: "Review Navio code for security risks across Next.js client and Java 25 Spring Boot services, including auth, endpoint exposure, secret handling, input validation, and event/API boundary protections."
---

# Security Review Skill

## Use When

Use this skill when the user asks for security review, vulnerability checks, auth checks, API hardening, or safe production-readiness validation.

## Review Objectives

1. Find exploitable issues and high-risk misconfigurations.
2. Verify Navio security conventions are enforced.
3. Provide minimal, concrete remediation guidance.
4. Reduce false positives by requiring evidence per finding.

## Navio Security Rules To Enforce

1. Internal APIs must use `/internal/v1/...` and enforce `X-Internal-Auth`.
2. Internal endpoints must never be proxy-exposed through NGINX.
3. Public APIs must use `/v1/...` and JWT Bearer auth (JWKS validation per service).
4. Moderator/admin endpoints must enforce explicit role checks.
5. No hardcoded secrets in code, tests, or config committed to git.
6. Correlation ID behavior must be consistent:
   - Read `X-Correlation-Id` when present.
   - Generate when missing.
   - Propagate through logs/downstream calls/Kafka headers.
7. Error responses must not leak internal implementation details and should follow:
   - `{ status, error, message, correlationId, timestamp }`
8. OpenAPI must reflect security requirements (auth, roles, error models, internal/public boundaries).
9. Cross-service data access must not use cross-schema joins or shared DTO leakage.
10. Event flows must use Transactional Outbox, not direct business-logic Kafka publishing.

## Review Workflow

1. Scope changed files and identify attack surfaces (HTTP, auth, file/media, DB, async events, external APIs).
2. Validate authentication and authorization paths.
3. Validate input handling, output encoding, and error behavior.
4. Check secret handling and unsafe logging.
5. Check API boundary hardening (`/v1` vs `/internal/v1`, internal header enforcement).
6. Check event/outbox integrity and idempotency assumptions.
7. Verify OpenAPI security contract parity with implementation.
8. Report only evidence-backed findings with actionable fixes.

## Security Checklist

1. AuthN/AuthZ:
   - Missing JWT checks, weak role checks, broken access control.
2. Input Validation:
   - Missing validation, deserialization abuse, unsafe defaults.
3. Data Exposure:
   - Sensitive fields in responses/logs/errors.
4. Secret Management:
   - Hardcoded credentials/tokens or leaked shared secrets.
5. Internal Endpoint Protection:
   - Missing `X-Internal-Auth` validation.
6. API Contract Security Drift:
   - OpenAPI vs implementation mismatch.
7. Injection/Traversal Risks:
   - SQL/JPQL/native query abuse, path traversal, insecure file upload handling.
8. Async/Event Risks:
   - Outbox bypass, malformed envelope, missing dedup assumptions.
9. Resilience-Security Crossovers:
   - Missing timeout/circuit breaker on external calls causing cascading failure risk.

## Required Output Format

1. Findings by severity: Critical, High, Medium, Low.
2. For each finding provide:
   - Title
   - Severity
   - File and line reference
   - Why it is vulnerable
   - Plausible exploit/failure scenario
   - Minimal fix recommendation
   - Suggested verification test
3. Residual risks and assumptions.
4. Security test gaps checklist.

## If No Findings

1. Explicitly state no significant security issues found.
2. Still report residual risk areas and missing tests.
