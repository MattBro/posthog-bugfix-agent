# Wrap up

### What's different from Sentry's approach
- Sentry's template is an **incident commander** - triages, opens tickets, posts to Slack
- Our agent actually **fixes the bug, merges the PR, and resolves the error**
- End to end, no human in the loop

### The repo
- [github.com/MattBro/posthog-bugfix-agent](https://github.com/MattBro/posthog-bugfix-agent)
- Fully forkable - all config via env vars
- GHA auto-deploys to both Anthropic + PostHog on push
