# posthog-bugfix-agent

Automated bug-fixing pipeline: PostHog captures an exception, a Hog function triggers a Claude Managed Agent that clones the repo, fixes the bug, and opens a PR.

## Architecture

```
$exception event (PostHog)
        |
        v
  Hog Function (PostHog CDP)
  - Extracts $exception_types, $exception_values, $exception_list
  - Creates a Claude Managed Agent session (POST /v1/sessions)
  - Sends error details as a user message (POST /v1/sessions/{id}/events)
        |
        v
  Claude Managed Agent (Anthropic)
  - Clones the repo using GITHUB_TOKEN
  - Analyzes the stack trace and identifies root cause
  - Creates a minimal fix
  - Opens a PR with error context
  - Squash-merges via gh pr merge --squash --auto
```

## Components

| File | Description |
|---|---|
| `agent.json` | Claude Managed Agent definition (model, tools, system prompt) |
| `environment.json` | Agent execution environment (cloud, unrestricted networking) |
| `hog-function.hog` | PostHog Hog function that bridges exceptions to the agent |
| `setup.sh` | Deploys/updates all components via their respective APIs |

## Setup

### Prerequisites

- Anthropic API key with Managed Agents access
- PostHog personal API key with Hog function write access (project 380973)
- GitHub token with repo push + PR permissions for target repos

### Deploy

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
export POSTHOG_API_KEY="phx_..."

chmod +x setup.sh
./setup.sh
```

The script will create or update the agent, environment, and Hog function.

### Hog Function Inputs

Configure these in the PostHog UI for the Hog function:

| Input | Description |
|---|---|
| `repo_url` | GitHub repo (e.g. `PostHog/posthog`) |
| `github_token` | GitHub PAT or app token for cloning/pushing |
| `anthropic_api_key` | Anthropic API key for creating agent sessions |
| `agent_id` | Managed Agent ID (`agent_011Ca3dyMDiKQz3ZUZbvGmyi`) |
| `environment_id` | Environment ID (`env_014HoCKPrM2bteNkNkwHoicp`) |

## Known Issues

### Dedup masking not functional

The Hog function currently has **no dedup masking**. Without masking, the same exception firing repeatedly will create duplicate agent sessions.

The intended masking would hash `exception_type + exception_value` to deduplicate, but the PostHog masking bytecode compiler has a bug where it treats the hash expression as a string literal instead of evaluating it. This needs to be fixed on the PostHog side before masking can be re-enabled.

**TODO**: Re-enable masking once the bytecode compiler bug is resolved.

## IDs

| Resource | ID |
|---|---|
| Agent | `agent_011Ca3dyMDiKQz3ZUZbvGmyi` |
| Environment | `env_014HoCKPrM2bteNkNkwHoicp` |
| Hog Function | `019d892a-c5a7-0000-bf22-3732d5778c64` |
| PostHog Project | `380973` |
