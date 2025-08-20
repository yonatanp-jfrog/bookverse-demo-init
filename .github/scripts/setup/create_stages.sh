#!/bin/bash
set -e
echo "Creating AppTrust Stages..."
# Note: Using curl here as stage creation might have more complex JSON bodies
# This assumes the JFROG_URL and JFROG_ADMIN_TOKEN are available as env vars
curl -X POST "${JFROG_URL}/access/api/v2/stages/" -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" -H "Content-Type: application/json" -d \
'{"name":"DEV","category":"promote","scope":"project","project_key":"bookverse","repositories":["bookverse-docker-internal"]}'

curl -X POST "${JFROG_URL}/access/api/v2/stages/" -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" -H "Content-Type: application/json" -d \
'{"name":"QA","category":"promote","scope":"project","project_key":"bookverse","repositories":["bookverse-docker-internal"]}'

curl -X POST "${JFROG_URL}/access/api/v2/stages/" -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" -H "Content-Type: application/json" -d \
'{"name":"STAGE","category":"promote","scope":"project","project_key":"bookverse","repositories":["bookverse-docker-internal-prod"]}'

curl -X POST "${JFROG_URL}/access/api/v2/stages/" -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" -H "Content-Type: application/json" -d \
'{"name":"PROD","category":"promote","scope":"global","repositories":["bookverse-docker-external-prod"]}'
