#!/usr/bin/env bash

set -euo pipefail

ENVIRONMENT="${1:?Environment is required}"
IMAGE="${2:?Image is required}"
PROJECT_NAME="${3:?Project name is required}"
ENV_FILE="${4:?Env file is required}"
COMPOSE_OVERRIDE="${5:?Compose override is required}"

cd /opt/finance

PREV_IMAGE=$(grep '^FINANCE_IMAGE=' "$ENV_FILE" | cut -d= -f2-)

echo "Deploying $IMAGE to $ENVIRONMENT"
echo "Previous image: ${PREV_IMAGE:-none}"

echo "FINANCE_IMAGE=$IMAGE" > "$ENV_FILE"

compose() {
    docker compose \
        --project-name "$PROJECT_NAME" \
        --env-file "$ENV_FILE" \
        -f compose.yml \
        -f "$COMPOSE_OVERRIDE" \
        "$@"
}

compose pull

if compose up -d --wait --wait-timeout 60; then
    echo "$ENVIRONMENT deployment succeeded"
else
    echo "$ENVIRONMENT deployment failed, rolling back"

    compose logs finance || true

    if [ -n "${PREV_IMAGE:-}" ]; then
        echo "FINANCE_IMAGE=$PREV_IMAGE" > "$ENV_FILE"

        compose pull
        compose up -d --wait --wait-timeout 60
    else
        echo "Previous image not found, rollback skipped"
    fi

    exit 1
fi