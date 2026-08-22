# Distributed Global Event & Monetization Backend

A highly scalable, production-ready backend system built for Roblox (Luau). This system handles cross-server synchronization for a timed global event, robust offline player data queueing, and a completely secure, server-validated monetization pipeline. 

Designed as the core backend architecture for *Wrenches & Souls*, this project demonstrates advanced handling of distributed systems constraints, memory management, and cache coherence within the Roblox engine.

## Core Features & Technical Implementation

### 1. Cross-Server Synchronization & Batching
*   Utilizes **MemoryStoreService** (`SortedMap`) to maintain a single, synchronized global leaderboard across all live servers.
*   Implements an asynchronous 10-second batching loop to aggregate player contribution points in memory before pushing to the cloud, strictly adhering to API rate limits while ensuring zero data loss.

### 2. Distributed Mutex Lock (Exactly-Once Delivery)
*   Solves the race condition of multiple live servers attempting to distribute event rewards simultaneously when the global timer expires.
*   Uses `DataStoreService:UpdateAsync()` as a transactional mutex lock. The first server to execute claims the lock and acts as the Lead Server, while all other servers gracefully yield, guaranteeing top players receive their reward exactly once.

### 3. Cache Coherence & Offline Queueing
*   Engineered a strict session management pipeline (OOP-based `PlayerSession` combined with a `SessionManager`) to handle cache coherence. 
*   If the Lead Server grants a reward to an offline player, the flag is directly injected into their persistent DataStore. The local server's AutoSave loop is explicitly programmed to read and preserve this database truth, completely preventing live server memory from overwriting and wiping offline database updates.

### 4. Zero-Trust Monetization Pipeline
*   Implements a fully decoupled, server-validated Developer Product system. 
*   Client-fired `RemoteEvents` are strictly limited to triggering UI prompts. The actual transaction and point allocation are handled exclusively through `MarketplaceService.ProcessReceipt`.
*   Includes robust validation checks for `PlayerId` and `ProductId`, and accurately handles `NotProcessedYet` returns to safeguard player purchases during unexpected server crashes or lag.

### 5. Decoupled Modular Architecture
*   Avoids monolithic anti-patterns by isolating domain logic into single-responsibility modules (`GlobalEventManager`, `SessionManager`, `BoostEventHandler`).
*   Utilizes **BindableEvents** to allow cross-module communication without creating cyclic dependency (`require`) crashes, ensuring a clean server boot sequence.