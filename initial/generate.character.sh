#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------------
# Default Configurations
# -------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
BASE_OUTPUT_DIR="${SCRIPT_DIR}/characters"

CHARACTER_PROMPT="fantasy rpg pixel hero character"
CUSTOM_NAME=""

# -------------------------------------------------------------------------
# Parse Command-Line Arguments
# -------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -prompt)
      CHARACTER_PROMPT="$2"
      shift 2
      ;;
    -name)
      CUSTOM_NAME="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [-prompt \"description\"] [-name \"character_name\"]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# -------------------------------------------------------------------------
# Load Environment Variables
# -------------------------------------------------------------------------
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Error: .env file not found at $(realpath "${ENV_FILE}" 2>/dev/null || echo "${ENV_FILE}")"
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

if [[ -z "${GEMINI_API_KEY:-}" ]]; then
  echo "Error: GEMINI_API_KEY is not defined in ${ENV_FILE}"
  exit 1
fi

# -------------------------------------------------------------------------
# Setup Output Directory & Temp Files
# -------------------------------------------------------------------------
if [[ -n "${CUSTOM_NAME}" ]]; then
  FOLDER_NAME="${CUSTOM_NAME}"
else
  FOLDER_NAME="char_$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)"
fi

OUTPUT_DIR="${BASE_OUTPUT_DIR}/${FOLDER_NAME}"
mkdir -p "${OUTPUT_DIR}"

REQ_FILE="${OUTPUT_DIR}/.temp_request.json"
RES_FILE="${OUTPUT_DIR}/.temp_response.json"
FRONT_B64_FILE="${OUTPUT_DIR}/.front.b64"
SIDE_B64_FILE="${OUTPUT_DIR}/.side.b64"

cleanup() {
  rm -f "${REQ_FILE}" "${RES_FILE}" "${FRONT_B64_FILE}" "${SIDE_B64_FILE}"
}
trap cleanup EXIT

echo "=========================================="
echo "Output Directory : ${OUTPUT_DIR}"
echo "Prompt           : ${CHARACTER_PROMPT}"
echo "=========================================="

# -------------------------------------------------------------------------
# API Helper Function
# -------------------------------------------------------------------------
send_request_and_save() {
  local view_name="$1"
  local output_file="$2"

  curl -s -X POST \
    -H "Content-Type: application/json" \
    --data-binary @"${REQ_FILE}" \
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image:generateContent?key=${GEMINI_API_KEY}" \
    > "${RES_FILE}"

  local has_image
  has_image=$(jq -r '
    .candidates[0].content.parts[]? 
    | select(.inlineData != null) 
    | .inlineData.data // empty
  ' "${RES_FILE}" | head -n 1)

  if [[ -z "${has_image}" ]]; then
    echo "Error generating ${view_name} view. API response:"
    jq . "${RES_FILE}" 2>/dev/null || cat "${RES_FILE}"
    exit 1
  fi

  jq -r '
    .candidates[0].content.parts[]? 
    | select(.inlineData != null) 
    | .inlineData.data
  ' "${RES_FILE}" | head -n 1 | base64 -d > "${output_file}"

  echo "Saved -> ${output_file}"
}

# -------------------------------------------------------------------------
# 1. Generate Front View (Base)
# -------------------------------------------------------------------------
view_name="front"
output_file="${OUTPUT_DIR}/${view_name}.png"
full_prompt="orthographic front view sprite sheet asset, 16-bit retro pixel art game sprite of ${CHARACTER_PROMPT}. FRONT ANGLE ONLY facing the viewer directly. Symmetrical idle standing pose, arms at sides, head facing straight forward. Single isolated character on uniform solid green screen (#00FF00). No shadows, no ground, no gradient, crisp pixel edges, 1:1 square aspect ratio. There should only be a single character in the image. There should be nothing in the background."

echo "Generating ${view_name} view (Base Reference)..."

jq -n \
  --arg prompt "${full_prompt}" \
  '{
    contents: [{ parts: [{ text: $prompt }] }],
    generationConfig: { responseModalities: ["IMAGE"] }
  }' > "${REQ_FILE}"

send_request_and_save "${view_name}" "${output_file}"
base64 -w 0 "${output_file}" > "${FRONT_B64_FILE}"

# -------------------------------------------------------------------------
# 2. Generate Side View (using Front as Reference)
# -------------------------------------------------------------------------
view_name="side"
output_file="${OUTPUT_DIR}/${view_name}.png"
context_prompt="PROFILE VIEW ONLY (90 DEGREES ROTATED TO THE RIGHT / FACING EAST). 
Render the character from the reference image in a strict pure side-profile perspective.
CRITICAL INSTRUCTIONS:
- Pose: Strict 90-degree lateral side view. Only one profile side of the face/body should be visible.
- Identity: Same clothing, colors, weapons, armor, and 16-bit pixel art style as reference.
- Exclusions: Absolutely NOT a front view, 3/4 angle, or diagonal view. Do not show both shoulders symmetrically.
- Background: Solid pure uniform green screen (#00FF00) only."

echo "Generating ${view_name} view (Side Profile)..."

jq -n \
  --arg prompt "${context_prompt}" \
  --rawfile img_data "${FRONT_B64_FILE}" \
  '{
    contents: [{
      parts: [
        { text: $prompt },
        { inlineData: { mimeType: "image/png", data: $img_data } }
      ]
    }],
    generationConfig: { responseModalities: ["IMAGE"] }
  }' > "${REQ_FILE}"

send_request_and_save "${view_name}" "${output_file}"
base64 -w 0 "${output_file}" > "${SIDE_B64_FILE}"

# -------------------------------------------------------------------------
# 3. Generate Back View (using Front + Side References)
# -------------------------------------------------------------------------
view_name="back"
output_file="${OUTPUT_DIR}/${view_name}.png"
context_prompt="REAR / BACK VIEW ONLY (180 DEGREES FACING AWAY FROM THE CAMERA). 
Render the character from the reference images seen directly from behind.
CRITICAL INSTRUCTIONS:
- Pose: Character has their back fully turned toward the camera.
- Visible features: Back of the head, back of the hair/helmet, back of torso, spine, cape, rear armor, back of shoes.
- Exclusions: NO EYES, NO FACE, NO MOUTH, NO NOSE, NO CHEST DETAILS. The character must NOT look back over their shoulder.
- Identity: Maintain all color palette and 16-bit pixel art styling from reference images.
- Background: Solid pure uniform green screen (#00FF00) only."

echo "Generating ${view_name} view (Rear / Back)..."

jq -n \
  --arg prompt "${context_prompt}" \
  --rawfile front_img "${FRONT_B64_FILE}" \
  --rawfile side_img "${SIDE_B64_FILE}" \
  '{
    contents: [{
      parts: [
        { text: $prompt },
        { inlineData: { mimeType: "image/png", data: $front_img } },
        { inlineData: { mimeType: "image/png", data: $side_img } }
      ]
    }],
    generationConfig: { responseModalities: ["IMAGE"] }
  }' > "${REQ_FILE}"

send_request_and_save "${view_name}" "${output_file}"

echo "=========================================="
echo "Contextual sprite generation complete!"
echo "Files created in ${OUTPUT_DIR}:"
ls -lh "${OUTPUT_DIR}"