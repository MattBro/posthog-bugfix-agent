# Files

| File | What it does | Key lines |
|---|---|---|
| [`agent.json`](../agent.json) | Agent definition - model config, toolset | |
| [`system-prompt.md`](../system-prompt.md) | Agent system prompt (~250 tokens, injected at deploy) | The entire "brain" |
| [`environment.json`](../environment.json) | Cloud sandbox with unrestricted networking | |
| [`hog-function.hog`](../hog-function.hog) | The glue - dedup, session creation, error details | Lines 46-68: CAS lock |
| [`setup.sh`](../setup.sh) | Deploys agent + hog function to Anthropic + PostHog APIs | |
| [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml) | Auto-deploys on push to main | |
