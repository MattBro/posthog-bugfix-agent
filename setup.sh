#!/usr/bin/env bash
set -euo pipefail

# Setup script for posthog-bugfix-agent
# Creates/updates the Managed Agent, environment, and PostHog Hog function.
#
# Required env vars:
#   ANTHROPIC_API_KEY - Anthropic API key for managing agents
#   POSTHOG_API_KEY   - PostHog personal API key for updating Hog functions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ANTHROPIC_API="https://api.anthropic.com/v1"
ANTHROPIC_VERSION="2023-06-01"
ANTHROPIC_BETA="managed-agents-2026-04-01"

POSTHOG_API="https://us.posthog.com/api"
POSTHOG_PROJECT_ID="380973"
POSTHOG_FUNCTION_ID="019d892a-c5a7-0000-bf22-3732d5778c64"

# --- Validation ---

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
    echo "Error: ANTHROPIC_API_KEY is not set" >&2
    exit 1
fi

if [[ -z "${POSTHOG_API_KEY:-}" ]]; then
    echo "Error: POSTHOG_API_KEY is not set" >&2
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

AGENT_JSON=$(cat "${SCRIPT_DIR}/agent.json")
AGENT_ID=$(echo "$AGENT_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

RESPONSE=$(anthropic_request GET "/agents/${AGENT_ID}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" == "200" ]]; then
    CURRENT_VERSION=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['version'])")
    echo "    Agent ${AGENT_ID} exists (version ${CURRENT_VERSION}), updating..."
    UPDATE_BODY=$(echo "$AGENT_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
data.pop('id', None)
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
    echo "    Agent ${AGENT_ID} not found, creating..."
    RESPONSE=$(anthropic_request POST "/agents" "$AGENT_JSON")
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    if [[ "$HTTP_CODE" != "200" && "$HTTP_CODE" != "201" ]]; then
        echo "    Error creating agent (HTTP ${HTTP_CODE}):" >&2
        echo "$RESPONSE" | sed '$d' >&2
        exit 1
    fi
    echo "    Agent created."
fi

# --- 2. Environment ---

echo "==> Configuring environment..."

ENV_JSON=$(cat "${SCRIPT_DIR}/environment.json")
ENV_ID=$(echo "$ENV_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

RESPONSE=$(anthropic_request GET "/environments/${ENV_ID}")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)

if [[ "$HTTP_CODE" == "200" ]]; then
    echo "    Environment ${ENV_ID} already exists, skipping (type/networking are immutable)."
else
    echo "    Environment ${ENV_ID} not found, creating..."
    RESPONSE=$(anthropic_request POST "/environments" "$ENV_JSON")
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    if [[ "$HTTP_CODE" != "200" && "$HTTP_CODE" != "201" ]]; then
        echo "    Error creating environment (HTTP ${HTTP_CODE}):" >&2
        echo "$RESPONSE" | sed '$d' >&2
        exit 1
    fi
    echo "    Environment created."
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
        {'type': 'string', 'key': 'githubToken', 'label': 'GitHub Token', 'required': True, 'secret': True},
        {'type': 'string', 'key': 'posthogApiKey', 'label': 'PostHog Personal API Key', 'required': True, 'secret': True, 'description': 'For updating error tracking issues'},
        {'type': 'string', 'key': 'githubRepo', 'label': 'GitHub Repo', 'required': True},
        {'type': 'string', 'key': 'defaultBranch', 'label': 'Default Branch', 'required': True},
        {'type': 'string', 'key': 'agentId', 'label': 'Claude Agent ID', 'required': True},
        {'type': 'string', 'key': 'environmentId', 'label': 'Claude Environment ID', 'required': True},
        {'type': 'string', 'key': 'posthogProjectId', 'label': 'PostHog Project ID', 'required': True},
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
echo "    Environment: ${ENV_ID}"
echo "    Hog Function: ${POSTHOG_FUNCTION_ID} (project ${POSTHOG_PROJECT_ID})"
