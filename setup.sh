#!/usr/bin/env bash
set -euo pipefail

# Setup script for posthog-bugfix-agent
# Creates/updates the Managed Agent, environment, and PostHog Hog function.
#
# Required env vars:
#   ANTHROPIC_API_KEY   - Anthropic API key for managing agents
#   POSTHOG_API_KEY     - PostHog personal API key for updating Hog functions
#   POSTHOG_PROJECT_ID  - PostHog project ID
#   POSTHOG_FUNCTION_ID - PostHog Hog function UUID
#
# Optional env vars (omit to create new resources):
#   AGENT_ID       - existing Claude agent ID to update
#   ENVIRONMENT_ID - existing Claude environment ID to skip recreation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ANTHROPIC_API="https://api.anthropic.com/v1"
ANTHROPIC_VERSION="2023-06-01"
ANTHROPIC_BETA="managed-agents-2026-04-01"

POSTHOG_API="https://us.posthog.com/api"

# --- Validation ---

MISSING=()
[[ -z "${ANTHROPIC_API_KEY:-}" ]] && MISSING+=("ANTHROPIC_API_KEY")
[[ -z "${POSTHOG_API_KEY:-}" ]] && MISSING+=("POSTHOG_API_KEY")
[[ -z "${POSTHOG_PROJECT_ID:-}" ]] && MISSING+=("POSTHOG_PROJECT_ID")
[[ -z "${POSTHOG_FUNCTION_ID:-}" ]] && MISSING+=("POSTHOG_FUNCTION_ID")

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "Error: missing required env vars: ${MISSING[*]}" >&2
    echo "See .env.example for the full list." >&2
    exit 1
fi

# --- Helper ---

anthropic_request() {
    local method="$1" path="$2" body="${3:-}"
    local args=(
        -s -w "\n%{http_code}"
        -X "$method"
        -H "x-api-key: ${ANTHROPIC_API_KEY}"
        -H "anthropic-version: ${ANTHROPIC_VERSION}"
        -H "anthropic-beta: ${ANTHROPIC_BETA}"
        -H "content-type: application/json"
        "${ANTHROPIC_API}${path}"
    )
    if [[ -n "$body" ]]; then
        args+=(-d "$body")
    fi
    curl "${args[@]}"
}

# --- 1. Agent ---

echo "==> Configuring agent..."

AGENT_JSON=$(python3 -c "
import json
with open('${SCRIPT_DIR}/agent.json') as f:
    agent = json.load(f)
with open('${SCRIPT_DIR}/system-prompt.md') as f:
    agent['system'] = f.read().strip()
print(json.dumps(agent))
")

if [[ -n "${AGENT_ID:-}" ]]; then
    RESPONSE=$(anthropic_request GET "/agents/${AGENT_ID}")
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    CURRENT_VERSION=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['version'])")
    echo "    Agent ${AGENT_ID} exists (version ${CURRENT_VERSION}), updating..."
    UPDATE_BODY=$(echo "$AGENT_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
data['version'] = ${CURRENT_VERSION}
print(json.dumps(data))
")
    RESPONSE=$(anthropic_request POST "/agents/${AGENT_ID}" "$UPDATE_BODY")
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    if [[ "$HTTP_CODE" != "200" ]]; then
        echo "    Error updating agent (HTTP ${HTTP_CODE}):" >&2
        echo "$RESPONSE" | sed '$d' >&2
        exit 1
    fi
    echo "    Agent updated."
else
    echo "    No AGENT_ID set, creating new agent..."
    RESPONSE=$(anthropic_request POST "/agents" "$AGENT_JSON")
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    if [[ "$HTTP_CODE" != "200" && "$HTTP_CODE" != "201" ]]; then
        echo "    Error creating agent (HTTP ${HTTP_CODE}):" >&2
        echo "$BODY" >&2
        exit 1
    fi
    AGENT_ID=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
    echo "    Agent created: ${AGENT_ID}"
    echo "    Save this ID as AGENT_ID in your env vars for future deploys."
fi

# --- 2. Environment ---

echo "==> Configuring environment..."

ENV_JSON=$(cat "${SCRIPT_DIR}/environment.json")

if [[ -n "${ENVIRONMENT_ID:-}" ]]; then
    echo "    Environment ${ENVIRONMENT_ID} already configured, skipping (type/networking are immutable)."
else
    echo "    No ENVIRONMENT_ID set, creating new environment..."
    RESPONSE=$(anthropic_request POST "/environments" "$ENV_JSON")
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    if [[ "$HTTP_CODE" != "200" && "$HTTP_CODE" != "201" ]]; then
        echo "    Error creating environment (HTTP ${HTTP_CODE}):" >&2
        echo "$BODY" >&2
        exit 1
    fi
    ENVIRONMENT_ID=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
    echo "    Environment created: ${ENVIRONMENT_ID}"
    echo "    Save this ID as ENVIRONMENT_ID in your env vars for future deploys."
fi

# --- 3. PostHog Hog Function ---

echo "==> Updating PostHog Hog function..."

PATCH_BODY=$(python3 -c "
import json
source = open('${SCRIPT_DIR}/hog-function.hog').read()
payload = {
    'hog': source,
    'inputs_schema': [
        {'type': 'string', 'key': 'anthropicApiKey', 'label': 'Anthropic API Key', 'required': True, 'secret': True},
        {'type': 'string', 'key': 'vaultId', 'label': 'Claude Vault ID', 'required': False, 'description': 'Vault containing GitHub credentials'},
        {'type': 'string', 'key': 'posthogApiKey', 'label': 'PostHog Personal API Key', 'required': True, 'secret': True, 'description': 'For updating error tracking issues'},
        {'type': 'string', 'key': 'githubRepo', 'label': 'GitHub Repo', 'required': True},
        {'type': 'string', 'key': 'defaultBranch', 'label': 'Default Branch', 'required': True},
        {'type': 'string', 'key': 'agentId', 'label': 'Claude Agent ID', 'required': True},
        {'type': 'string', 'key': 'environmentId', 'label': 'Claude Environment ID', 'required': True},
        {'type': 'string', 'key': 'posthogProjectId', 'label': 'PostHog Project ID', 'required': True},
        {'type': 'string', 'key': 'gitAuthorName', 'label': 'Git Author Name', 'required': False, 'default': 'posthog-bugfix-agent'},
        {'type': 'string', 'key': 'gitAuthorEmail', 'label': 'Git Author Email', 'required': False, 'default': 'noreply@users.noreply.github.com'},
    ]
}
print(json.dumps(payload))
")

RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X PATCH \
    -H "Authorization: Bearer ${POSTHOG_API_KEY}" \
    -H "content-type: application/json" \
    -d "$PATCH_BODY" \
    "${POSTHOG_API}/environments/${POSTHOG_PROJECT_ID}/hog_functions/${POSTHOG_FUNCTION_ID}/")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)

if [[ "$HTTP_CODE" != "200" ]]; then
    echo "    Error updating Hog function (HTTP ${HTTP_CODE}):" >&2
    echo "$RESPONSE" | sed '$d' >&2
    exit 1
fi

echo "    Hog function updated."

echo ""
echo "==> Setup complete!"
echo "    Agent:       ${AGENT_ID}"
echo "    Environment: ${ENVIRONMENT_ID}"
echo "    Hog Function: ${POSTHOG_FUNCTION_ID} (project ${POSTHOG_PROJECT_ID})"
