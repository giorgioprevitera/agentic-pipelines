#!/usr/bin/env bash
#
# ask-gemini.sh — call Gemini with a system prompt + input file, get back
# validated JSON on stdout. Never fails the caller on an API/model problem:
# on any agent-side failure it prints a fallback JSON object and exits 0.
# Only a usage/config mistake (missing args, missing files, missing key)
# exits non-zero, since that's a workflow bug you want to see immediately.
#
# Usage:
#   GEMINI_API_KEY=... ./ask-gemini.sh <system-prompt-file> <input-file>
#
# Env:
#   GEMINI_API_KEY   required
#   GEMINI_MODEL     optional, default gemini-flash-latest
#                     (check the current free-tier model name in AI Studio —
#                      it changes periodically)

set -uo pipefail
# Deliberately no -e: every failure path is handled explicitly below so we
# can always emit valid JSON instead of dying mid-script.

MODEL="${GEMINI_MODEL:-gemini-flash-latest}"
API_URL="https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent"
MAX_RETRIES=1
RETRY_DELAY=5

usage() {
    echo "Usage: $0 <system-prompt-file> <input-file>" >&2
    echo "Env:   GEMINI_API_KEY (required), GEMINI_MODEL (optional)" >&2
}

# Print a safe fallback JSON object and exit 0. Callers key off "agent_error"
# to know this isn't a real model response, but every field a real prompt
# might return (severity, rollback, etc.) is still present with a safe
# default so a caller that only checks e.g. .rollback doesn't crash.
fallback() {
    local reason="$1"
    jq -n --arg reason "$reason" '{
    agent_error: true,
    reason: $reason,
    severity: "LOW",
    rollback: true,
    root_cause: "AI agent call failed; see reason field",
    issues: [],
    summary: "AI agent unavailable",
    suggested_fix: "",
    diff: "",
    recommendation: "Agent call failed — treating as unresolved, human review needed"
  }'
    exit 0
}

# ---------------------------------------------------------------------------
# Argument / config validation — these exit non-zero on purpose
# ---------------------------------------------------------------------------
SYSTEM_PROMPT_FILE="${1:-}"
INPUT_FILE="${2:-}"

if [[ -z "$SYSTEM_PROMPT_FILE" || -z "$INPUT_FILE" ]]; then
    usage
    exit 1
fi

if [[ ! -r "$SYSTEM_PROMPT_FILE" ]]; then
    echo "error: cannot read system prompt file: $SYSTEM_PROMPT_FILE" >&2
    exit 1
fi

if [[ ! -r "$INPUT_FILE" ]]; then
    echo "error: cannot read input file: $INPUT_FILE" >&2
    exit 1
fi

if [[ -z "${GEMINI_API_KEY:-}" ]]; then
    echo "error: GEMINI_API_KEY is not set" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Build the request body safely (jq escapes the file contents for us —
# never hand-interpolate arbitrary text into a JSON string)
# ---------------------------------------------------------------------------
REQUEST_BODY=$(jq -n \
    --rawfile sys "$SYSTEM_PROMPT_FILE" \
    --rawfile usr "$INPUT_FILE" \
    '{
    systemInstruction: { parts: [{ text: $sys }] },
    contents: [{ parts: [{ text: $usr }] }],
    generationConfig: { responseMimeType: "application/json" }
  }')

# ---------------------------------------------------------------------------
# Call the API — from here on, everything falls back instead of failing
# ---------------------------------------------------------------------------
BODY_FILE=$(mktemp)
trap 'rm -f "$BODY_FILE"' EXIT

attempt=0
HTTP_STATUS=""
while :; do
    HTTP_STATUS=$(curl -sS -o "$BODY_FILE" -w '%{http_code}' \
        "$API_URL" \
        -H 'Content-Type: application/json' \
        -H "X-goog-api-key: ${GEMINI_API_KEY}" \
        -X POST \
        -d "$REQUEST_BODY" \
        --max-time 30)
    CURL_EXIT=$?

    if [[ $CURL_EXIT -ne 0 ]]; then
        fallback "curl failed with exit code $CURL_EXIT (network error or timeout)"
    fi

    # 429 = rate limited, 503 = model overloaded ("high demand", common on the
    # free tier). Both are transient — worth one retry before giving up.
    if [[ ("$HTTP_STATUS" == "429" || "$HTTP_STATUS" == "503") && $attempt -lt $MAX_RETRIES ]]; then
        attempt=$((attempt + 1))
        sleep "$RETRY_DELAY"
        continue
    fi

    break
done

BODY=$(cat "$BODY_FILE")

if [[ "$HTTP_STATUS" != "200" ]]; then
    fallback "Gemini API returned HTTP $HTTP_STATUS: $(echo "$BODY" | head -c 300)"
fi

# Pull the model's text out of the response envelope
INNER_TEXT=$(echo "$BODY" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null)

if [[ -z "$INNER_TEXT" ]]; then
    fallback "could not extract text from Gemini response"
fi

# responseMimeType should guarantee JSON, but never trust a model
# unconditionally — validate before handing it to the caller
if ! echo "$INNER_TEXT" | jq -e . >/dev/null 2>&1; then
    fallback "model response was not valid JSON: $(echo "$INNER_TEXT" | head -c 300)"
fi

echo "$INNER_TEXT"
exit 0
