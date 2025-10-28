# Project Name

A Roblox game built with modern, type-safe libraries for scalable multiplayer experiences.

## Overview

This project leverages industry-standard frameworks to deliver robust client-server architecture with reactive UI and reliable data persistence.

## Core Libraries

### [Red](https://red.redblox.dev/guide/events/declaring.html)
Lightweight, type‑safe signal/event framework for Roblox that keeps server–client communication organized.

### [ReplicaService](https://madstudioroblox.github.io/ReplicaService/api/)
Structured, schema‑driven data replication with fine‑grained permissions. Perfect for real‑time, authoritative gameplay state.

### [Fusion](https://elttob.uk/Fusion/0.2/api-reference/)
A declarative, reactive UI engine—build components once; let Fusion handle updates when data changes.

### [ProfileService](https://madstudioroblox.github.io/ProfileService/)
Battle‑tested profile persistence with session locking, write cooldowns, and automatic versioning.

## Getting Started

1. Clone the repository
2. Open in Roblox Studio
3. Install dependencies via Wally (if applicable)
4. Run the project

## Branching Strategy

We follow a **Git Flow–lite** model with main, dev, and personal feature branches.

| Branch | Purpose | Rules |
|--------|---------|-------|
| **main** | Production‑ready releases | • Protected<br>• Only merged via PR from `dev` |
| **dev** | Ongoing integration | • Default branch for development<br>• CI must pass before merge |
| **personal/×××** | Individual features | • Branch off `dev`<br>• Merge back into `dev` via PR |

## Contributing

1. Create a personal branch from `dev`
2. Make your changes
3. Submit a PR to `dev`
4. Ensure CI passes before merge