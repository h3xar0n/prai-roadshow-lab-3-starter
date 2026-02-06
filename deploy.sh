#!/bin/bash

set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "${SCRIPT_DIR}"

if [ -f ".env" ]; then
  source .env
fi

if [[ "${GOOGLE_CLOUD_PROJECT}" == "" ]]; then
  GOOGLE_CLOUD_PROJECT=$(gcloud config get-value project -q)
fi
if [[ "${GOOGLE_CLOUD_PROJECT}" == "" ]]; then
  echo "ERROR: Run 'gcloud config set project' command to set active project, or set GOOGLE_CLOUD_PROJECT environment variable."
  exit 1
fi

REGION="${GOOGLE_CLOUD_LOCATION}"
if [[ "${REGION}" == "global" ]]; then
  echo "GOOGLE_CLOUD_LOCATION is set to 'global'. Getting a default location for Cloud Run."
  REGION=""
fi

if [[ "${REGION}" == "" ]]; then
  REGION=$(gcloud config get-value compute/region -q)
  if [[ "${REGION}" == "" ]]; then
    REGION="us-central1"
    echo "WARNING: Cannot get a configured compute region. Defaulting to ${REGION}."
  fi
fi
echo "Using project ${GOOGLE_CLOUD_PROJECT}."
echo "Using compute region ${REGION}."

# Optional suffix for service names (e.g. set to "-beta" for parallel version)
# You can set this in your .env or as an environment variable.
if [[ "${SERVICE_SUFFIX}" == "" ]]; then
  SERVICE_SUFFIX=""
fi
echo "Using service suffix: '${SERVICE_SUFFIX}'"

echo "Deploying researcher..."
RESEARCHER_IMAGE="us-central1-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/cloud-run-source-deploy/researcher${SERVICE_SUFFIX}:latest"
gcloud builds submit --tag "${RESEARCHER_IMAGE}" --dockerfile agents/researcher/Dockerfile .
gcloud run deploy "researcher${SERVICE_SUFFIX}" \
  --image "${RESEARCHER_IMAGE}" \
  --project $GOOGLE_CLOUD_PROJECT \
  --region $REGION \
  --no-allow-unauthenticated \
  --set-env-vars GOOGLE_CLOUD_PROJECT="${GOOGLE_CLOUD_PROJECT}" \
  --set-env-vars GOOGLE_GENAI_USE_VERTEXAI="true"
RESEARCHER_URL=$(gcloud run services describe "researcher${SERVICE_SUFFIX}" --region $REGION --format='value(status.url)')

echo "Deploying content-builder..."
CONTENT_BUILDER_IMAGE="us-central1-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/cloud-run-source-deploy/content-builder${SERVICE_SUFFIX}:latest"
gcloud builds submit --tag "${CONTENT_BUILDER_IMAGE}" --dockerfile agents/content_builder/Dockerfile .
gcloud run deploy "content-builder${SERVICE_SUFFIX}" \
  --image "${CONTENT_BUILDER_IMAGE}" \
  --project $GOOGLE_CLOUD_PROJECT \
  --region $REGION \
  --no-allow-unauthenticated \
  --set-env-vars GOOGLE_CLOUD_PROJECT="${GOOGLE_CLOUD_PROJECT}" \
  --set-env-vars GOOGLE_GENAI_USE_VERTEXAI="true"
CONTENT_BUILDER_URL=$(gcloud run services describe "content-builder${SERVICE_SUFFIX}" --region $REGION --format='value(status.url)')

echo "Deploying judge..."
JUDGE_IMAGE="us-central1-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/cloud-run-source-deploy/judge${SERVICE_SUFFIX}:latest"
gcloud builds submit --tag "${JUDGE_IMAGE}" --dockerfile agents/judge/Dockerfile .
gcloud run deploy "judge${SERVICE_SUFFIX}" \
  --image "${JUDGE_IMAGE}" \
  --project $GOOGLE_CLOUD_PROJECT \
  --region $REGION \
  --no-allow-unauthenticated \
  --set-env-vars GOOGLE_CLOUD_PROJECT="${GOOGLE_CLOUD_PROJECT}" \
  --set-env-vars GOOGLE_GENAI_USE_VERTEXAI="true"
JUDGE_URL=$(gcloud run services describe "judge${SERVICE_SUFFIX}" --region $REGION --format='value(status.url)')

echo "Deploying orchestrator..."
ORCHESTRATOR_IMAGE="us-central1-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/cloud-run-source-deploy/orchestrator${SERVICE_SUFFIX}:latest"
gcloud builds submit --tag "${ORCHESTRATOR_IMAGE}" --dockerfile agents/orchestrator/Dockerfile .
gcloud run deploy "orchestrator${SERVICE_SUFFIX}" \
  --image "${ORCHESTRATOR_IMAGE}" \
  --project $GOOGLE_CLOUD_PROJECT \
  --region $REGION \
  --no-allow-unauthenticated \
  --set-env-vars RESEARCHER_AGENT_CARD_URL=$RESEARCHER_URL/a2a/agent/.well-known/agent-card.json \
  --set-env-vars JUDGE_AGENT_CARD_URL=$JUDGE_URL/a2a/agent/.well-known/agent-card.json \
  --set-env-vars CONTENT_BUILDER_AGENT_CARD_URL=$CONTENT_BUILDER_URL/a2a/agent/.well-known/agent-card.json \
  --set-env-vars GOOGLE_CLOUD_PROJECT="${GOOGLE_CLOUD_PROJECT}" \
  --set-env-vars GOOGLE_GENAI_USE_VERTEXAI="true"
ORCHESTRATOR_URL=$(gcloud run services describe "orchestrator${SERVICE_SUFFIX}" --region $REGION --format='value(status.url)')

echo "Deploying course-creator (frontend)..."
COURSE_CREATOR_IMAGE="us-central1-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/cloud-run-source-deploy/course-creator${SERVICE_SUFFIX}:latest"
gcloud builds submit --tag "${COURSE_CREATOR_IMAGE}" --dockerfile app/Dockerfile .
gcloud run deploy "course-creator${SERVICE_SUFFIX}" \
  --image "${COURSE_CREATOR_IMAGE}" \
  --project $GOOGLE_CLOUD_PROJECT \
  --region $REGION \
  --allow-unauthenticated \
  --set-env-vars AGENT_SERVER_URL=$ORCHESTRATOR_URL \
  --set-env-vars GOOGLE_CLOUD_PROJECT="${GOOGLE_CLOUD_PROJECT}"
