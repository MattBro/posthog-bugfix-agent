# What are we building?

A bug fixes itself: error happens in production, a PR gets opened and merged, the error gets resolved. No human involved.

## The problem

Errors fire at 3am. Someone gets paged, opens the error, reads the stack trace, finds the bug, writes a fix, opens a PR, merges it. What if that whole loop was automated?

## The building blocks

- **PostHog Error Tracking** - captures `$exception` events from your app with stack traces
- **Hog Functions** - PostHog's serverless functions (like AWS Lambda but triggered by PostHog events). Write code that runs when specific events fire.
- **Claude Managed Agents** - Anthropic's hosted agent runtime. You define an agent (model + tools + system prompt), create a session, send it a message, and it works autonomously in a sandboxed cloud container.

## Architecture

```mermaid
flowchart LR
    A["Production App"] -- "$exception" --> B["PostHog"]
    B -- "triggers" --> C["Hog Function"]
    C -- "create session" --> D["Claude Agent"]
    D -- "clone, fix, PR, merge" --> E["GitHub"]
    D -- "resolve issue" --> B

    style A fill:#2d2d2d,stroke:#555,color:#eee
    style B fill:#1a1a2e,stroke:#e94560,color:#eee
    style C fill:#1a1a2e,stroke:#e94560,color:#eee
    style D fill:#1a1a2e,stroke:#0f3460,color:#eee
    style E fill:#2d2d2d,stroke:#555,color:#eee
```

### Agent session

```mermaid
flowchart LR
    A["Clone repo"] --> B["Analyze error"] --> C["Fix bug"] --> D["Push + PR"] --> E["Merge"] --> F["Resolve in PostHog"]
```
