<p align="center">
  <img src="https://img.shields.io/badge/status-in%20development-blue?style=for-the-badge" alt="Status" />
  <img src="https://img.shields.io/badge/architecture-microservices-informational?style=for-the-badge" alt="Architecture" />
  <img src="https://img.shields.io/badge/backend-Spring%20Boot-6DB33F?style=for-the-badge&logo=springboot&logoColor=white" alt="Spring Boot" />
  <img src="https://img.shields.io/badge/messaging-Apache%20Kafka-231F20?style=for-the-badge&logo=apachekafka&logoColor=white" alt="Kafka" />
</p>

# Navio

> **A distributed, event-driven microservices platform for intelligent trip planning — with built-in EV charging intelligence, a Reddit-like community layer for posting and discussing travel plans, and a forking model to remix itineraries with attribution.**

Navio is designed to showcase how a real-world trip-planning product — itinerary creation, EV route optimization, community discussions, and itinerary forking — can be decomposed into independently deployable services that communicate through an event backbone. The project emphasises production-calibre patterns: strict service boundaries, asynchronous messaging, and a single API Gateway as the only public-facing entry point.

---

## Table of Contents

1. [Business Purpose](#business-purpose)
2. [System Architecture](#system-architecture)
3. [Tech Stack](#tech-stack)
4. [Service Decoupling Strategy](#service-decoupling-strategy)
5. [Repository Structure](#repository-structure)
6. [Getting Started](#getting-started)
7. [Running the Stack](#running-the-stack)
8. [Roadmap](#roadmap)
9. [License](#license)

---

## Business Purpose

Modern trip planning is more than plotting waypoints on a map. EV drivers need real-time charging-station availability woven into their routes. Travelers want to share itineraries like social posts, fork and remix them, and discuss logistics in context. **Navio** tackles this complexity with a distributed architecture that mirrors how companies like Airbnb, Uber, and Google Maps engineer their platforms:

| Concern                       | How Navio Addresses It                                                                                                               |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| **High throughput**           | Apache Kafka decouples producers from consumers, enabling non-blocking event processing (e.g., route recalculations, notifications). |
| **Independent deployability** | Each microservice owns its data, schema, and release cycle.                                                                          |
| **Single entry point**        | An API Gateway routes, authenticates, and rate-limits all inbound traffic.                                                           |
| **Observability**             | Structured logging and health endpoints are built into every service.                                                                |

---

## System Architecture

```
                        ┌──────────────┐
                        │    Client    │
                        │  (React App) │
                        └──────┬───────┘
                               │  HTTP
                               ▼
                      ┌─────────────────┐
                      │   API Gateway   │ ◄── Single public entry point
                      │  (Spring Boot)  │
                      └──┬─────┬────┬───┘
                         │     │    │
              ┌──────────┘     │    └──────────┐
              ▼                ▼               ▼
     ┌────────────┐   ┌──────────────┐  ┌────────────┐
     │  Service A  │   │  Service B   │  │  Service C │
     │  (planned)  │   │  (planned)   │  │ (planned)  │
     └─────┬──────┘   └──────┬───────┘  └─────┬──────┘
           │                 │                 │
           └────────┬────────┴─────────────────┘
                    ▼
           ┌─────────────────┐
           │  Apache Kafka   │  ◄── Async event backbone
           │    (Broker)     │
           └─────────────────┘
```

- **Client → API Gateway:** All frontend requests are routed exclusively through the API Gateway. No service is directly exposed to the internet.
- **API Gateway → Services:** The gateway forwards requests to downstream microservices. Routing, authentication, and rate limiting live here.
- **Services ↔ Kafka:** Domain events (e.g., `ItineraryCreated`, `RouteOptimized`, `ItineraryForked`) are published to Kafka topics. Interested services subscribe and react asynchronously.

---

## Tech Stack

### Backend

| Layer                | Technology               | Purpose                                                                                   |
| -------------------- | ------------------------ | ----------------------------------------------------------------------------------------- |
| **Runtime**          | Java 21+ / Spring Boot 3 | Service framework, dependency injection, auto-configuration                               |
| **API Gateway**      | Spring Cloud Gateway     | Request routing, filtering, load balancing                                                |
| **Messaging**        | Apache Kafka             | Asynchronous, durable event streaming between services                                    |
| **Communication**    | gRPC, HttpClient         | Synchronous cross-service calls (see [Decoupling Strategy](#service-decoupling-strategy)) |
| **Containerisation** | Docker / Docker Compose  | Reproducible local development & CI environments                                          |

### Frontend

| Layer                | Technology |
| -------------------- | ---------- |
| **UI Framework**     | React      |
| **Styling**          | TBD        |
| **State Management** | TBD        |

---

## Service Decoupling Strategy

Navio enforces **strict service boundaries** — no shared DTOs, no shared libraries, no shared databases.

### Why?

Shared data-transfer objects create hidden coupling. Changing a field in a shared DTO forces a coordinated release across every service that depends on it, negating the key benefit of microservices: independent deployability.

### How Navio handles cross-service communication:

| Pattern                            | Mechanism                     | When to Use                                                                                                                     |
| ---------------------------------- | ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| **Asynchronous events**            | Apache Kafka topics           | Default. Domain events flow through Kafka; each consumer deserialises into its own internal model.                              |
| **Synchronous request / response** | **gRPC** (protobuf contracts) | Low-latency, strongly-typed calls between internal services. Each service generates its own stubs from the `.proto` definition. |
| **External / legacy integration**  | **Java HttpClient**           | REST-based calls to third-party APIs or services that don't support gRPC.                                                       |

> **Rule:** Every service defines its own internal domain models. Data received from another service is mapped at the boundary — never passed through as a shared class.

---

## Repository Structure

This is an **umbrella repository** that uses **Git Submodules** to compose independently versioned services into a single, cloneable workspace.

```
Navio/                          ← You are here (umbrella repo)
├── client/                     ← Git submodule  – Frontend application
├── server/
│   └── api-gateway/            ← Git submodule  – Spring Boot API Gateway
├── docker-compose.yml          ← Orchestrates all services locally
└── README.md
```

> As the system grows, additional microservices will be added under `server/` as new submodules (e.g., `server/itinerary-service`, `server/community-service`).

---

## Getting Started

### Prerequisites

| Tool                             | Version         |
| -------------------------------- | --------------- |
| Git                              | 2.13+           |
| Docker & Docker Compose          | 24+ / v2 plugin |
| Java (for local backend dev)     | 21+             |
| Node.js (for local frontend dev) | 18+ LTS         |

### Clone with Submodules

```bash
# Clone the umbrella repo AND all submodules in a single command
git clone --recurse-submodules https://github.com/bestprappy/Navio.git

# Navigate into the project
cd Navio
```

**Already cloned without `--recurse-submodules`?** Initialise them retroactively:

```bash
git submodule update --init --recursive
```

**Pull the latest changes across all submodules:**

```bash
git submodule update --remote --merge
```

---

## Running the Stack

```bash
# Build and start all services (Client, API Gateway, Kafka, Zookeeper)
docker compose up --build

# Tear down and remove volumes
docker compose down -v
```

| Service      | Local URL                                          |
| ------------ | -------------------------------------------------- |
| Client       | `http://localhost:3000`                            |
| API Gateway  | `http://localhost:8080`                            |
| Kafka Broker | `localhost:29092` (host) / `kafka:9092` (internal) |

---

## Roadmap

- [ ] Initialise client and API Gateway submodule repos
- [ ] Implement gateway routing & health checks
- [ ] Add Itinerary Service (`server/itinerary-service`)
- [ ] Add Community Service (`server/community-service`)
- [ ] Integrate EV charging station APIs
- [ ] Introduce gRPC contracts between services
- [ ] CI/CD pipeline (GitHub Actions)
- [ ] Kubernetes deployment manifests

---

## License

This project is licensed under the [MIT License](LICENSE).

---

<p align="center"><sub>Built by <a href="https://github.com/bestprappy">bestprappy</a> — Navio</sub></p>
