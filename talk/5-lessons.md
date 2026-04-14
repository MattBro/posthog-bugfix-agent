# Lessons learned

### 1. Idempotency
Same error fires 100x. Need one agent session. CAS on the issue description field - write a nonce, read it back, loser backs off.

### 2. Secrets
Don't put tokens in the prompt. Use Vaults + GitHub MCP. Agent never sees the credential.

### 3. Token efficiency
Compress the system prompt (sent every turn). 500 -> 250 tokens. Don't repeat instructions in the user message.

### 4. Prompt optimization from logs
Review agent session logs, find repeated failures, update the prompt. Could be a scheduled meta-agent.

### 5. Scaling
Current setup is per-session clone. For large repos: `init_script` to pre-clone, or MCP-only to read just what's needed.
