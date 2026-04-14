# Lesson 2: Secrets

Don't put tokens in the prompt. Use [Vaults](https://docs.anthropic.com/en/docs/agents/managed-agents/vaults) + GitHub MCP.

```mermaid
flowchart LR
    A["Hog Function"] -- "vault_ids" --> B["Session"]
    B -- "MCP tool call" --> C["Vault Proxy"]
    C -- "injects auth" --> D["GitHub API"]

    style C fill:#16c784,stroke:#16c784,color:#fff
```

Vault stores the PAT. Agent declares MCP server (no token). Session gets `vault_ids`. Proxy injects auth. Agent never sees the token.
