#!/bin/bash
set -eu

cd $(dirname $0)
. ./stack_sets_functions.sh

CFN_TEMPLATE="./sns_for_notification.yaml"

PROFILE=""

while getopts p: OPT; do
    case $OPT in
        p)
            PROFILE="$OPTARG"
            ;;
    esac
done

if [ -z ${PROFILE} ]; then
    echo "required PROFILE"
    exit 1
fi

CFN_STACK_SET_NAME="SNSForStacksets"
OPERATION_REGION="us-east-1"

CFN_NotificationEmailAddress1="test1@testsampleaddress.com"
CFN_NotificationEmailAddress2="test2@testsampleaddress.com"

CFN_PARAMETERS="\
ParameterKey=NotificationEmailAddress1,ParameterValue=${CFN_NotificationEmailAddress1} \
ParameterKey=NotificationEmailAddress2,ParameterValue=${CFN_NotificationEmailAddress2} \
"

deploy_stack_sets "${CFN_TEMPLATE}" "${CFN_STACK_SET_NAME}" "${OPERATION_REGION}" "${CFN_PARAMETERS}" "${PROFILE}" 