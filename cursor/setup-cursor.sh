#!/usr/bin/env bash
set -euo pipefail

# Setup script for the Cursor backend.
# Patches a PostHog Hog function with cursor/hog-function-cursor.hog and its
# inputs schema. The Cursor automation itself (webhook trigger, repo, prompt,
# tools, PostHog MCP) is configured in the Cursor dashboard - see README.md.
#
# Required env vars:
#   POSTHOG_API_KEY     - PostHog personal API key for updating Hog functions
#   POSTHOG_PROJECT_ID  - PostHog project ID
#   POSTHOG_FUNCTION_ID - PostHog Hog function UUID (the Cursor one, not the Claude one)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

POSTHOG_API="https://us.posthog.com/api"

MISSING=()
[[ -z "${POSTHOG_API_KEY:-}" ]] && MISSING+=("POSTHOG_API_KEY")
[[ -z "${POSTHOG_PROJECT_ID:-}" ]] && MISSING+=("POSTHOG_PROJECT_ID")
[[ -z "${POSTHOG_FUNCTION_ID:-}" ]] && MISSING+=("POSTHOG_FUNCTION_ID")

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "Error: missing required env vars: ${MISSING[*]}" >&2
    exit 1
fi

echo "==> Updating PostHog Hog function (Cursor backend)..."

PATCH_BODY=$(python3 -c "
import json
source = open('${SCRIPT_DIR}/hog-function-cursor.hog').read()
payload = {
    'hog': source,
    'inputs_schema': [
        {'type': 'string', 'key': 'cursorWebhookUrl', 'label': 'Cursor Webhook URL', 'required': True, 'description': 'Generated when you save the Cursor automation with a Webhook trigger'},
        {'type': 'string', 'key': 'cursorApiKey', 'label': 'Cursor Webhook API Key', 'required': True, 'secret': True},
        {'type': 'string', 'key': 'posthogApiKey', 'label': 'PostHog Personal API Key', 'required': True, 'secret': True, 'description': 'For the CAS dedup on error tracking issues'},
        {'type': 'string', 'key': 'posthogProjectId', 'label': 'PostHog Project ID', 'required': True},
        {'type': 'string', 'key': 'githubRepo', 'label': 'GitHub Repo', 'required': False, 'description': 'Passed through to the agent; the Cursor automation also has the repo configured'},
        {'type': 'string', 'key': 'defaultBranch', 'label': 'Default Branch', 'required': False, 'default': 'main'},
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
echo "==> Done. Hog Function: ${POSTHOG_FUNCTION_ID} (project ${POSTHOG_PROJECT_ID})"
