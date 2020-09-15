#!/usr/bin/env bash

set -o nounset
set -o noclobber
set -o errexit
set -o pipefail

BASENAME=$(basename "${0}")

function log {
  local MESSAGE=${1}
  echo "${BASENAME}: ${MESSAGE}"
  logger --id "${BASENAME}: ${MESSAGE}"
}

log 'Started ...'

export APP_URL=https://tomcat.apache.org/tomcat-7.0-doc/appdev/sample/sample.war
export AWS_PROFILE=terraform-infra

log 'Variables configured ...'

rm -rf sample.war sample.md5
curl --silent --location -o sample.war ${APP_URL}
ls -la sample.war
md5sum sample.war >sample.md5

log 'Application artifact downloaded ...'

aws sts get-caller-identity

export APP_BUCKET=$(aws ssm get-parameter --name /dev/code-deploy-s3-name | jq -r '.Parameter.Value')
log "Bucket: ${APP_BUCKET}"

export APP_NAME=$(aws ssm get-parameter --name /dev/code-deploy-app-name | jq -r '.Parameter.Value')
log "Application Name: ${APP_NAME}"

export REVISION_TAG=$(date +"%Y%m%dT%H%M%S")
log "New revision tag: ${REVISION_TAG}"

aws deploy push \
  --application-name ${APP_NAME} \
  --s3-location s3://${APP_BUCKET}/${APP_NAME}-${REVISION_TAG}.zip \
  --ignore-hidden-files \
  --source . \
  --description ${APP_NAME}

aws deploy create-deployment \
  --ignore-application-stop-failures \
  --application-name ${APP_NAME} \
  --s3-location bucket=${APP_BUCKET},key=${APP_NAME}-${REVISION_TAG}.zip,bundleType=zip \
  --deployment-group-name ${APP_NAME} \
  --deployment-config-name ${APP_NAME} \
  --description "Deployment: ${APP_NAME}-${REVISION_TAG}."

log 'Finished ...'
