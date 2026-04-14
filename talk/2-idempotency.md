# Lesson 1: Idempotency

Same exception fires 100x in seconds. Need exactly one agent session per error.

Status checks have TOCTOU races. Solution: **compare-and-swap** on the issue description.

```mermaid
flowchart LR
    A{"Status?"} -- "already handled" --> B["Skip"]
    A -- "active" --> C["Write nonce"] --> D{"Read back"}
    D -- "nonce matches" --> E["Won lock"]
    D -- "different nonce" --> B

    style B fill:#e94560,stroke:#e94560,color:#fff
    style E fill:#16c784,stroke:#16c784,color:#fff
```

Write a unique nonce, read it back. PostHog is last-write-wins, so only one writer's nonce survives. Loser backs off.
