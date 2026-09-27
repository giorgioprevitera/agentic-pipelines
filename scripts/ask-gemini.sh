#!/usr/bin/env bash

SYSTEM_PROMPT_FILE=${1}
USER_INPUT=${2}

echo curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent" \
    -H 'Content-Type: application/json' \
    -H "X-goog-api-key: ${GEMINI_API_KEY}" \
    -X POST \
    -d "$(jq -n --rawfile sys "${SYSTEM_PROMPT_FILE}" --rawfile usr "${USER_INPUT}" '
{
    systemInstruction: { parts: [{ text: $sys }] },
    contents: [{ parts: [{ text: $usr }] }],
    generationConfig: { responseMimeType: "application/json" }
}
')"
