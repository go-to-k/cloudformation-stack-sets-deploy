#!/bin/bash
set -eu

function check_stack_set_operation {
    local stack_set_name="$1"
    local operation_id="$2"
    local operation_region="$3"
    local profile="$4"

    if [ -z ${stack_set_name} ] \
        || [ -z ${operation_id} ] \
        || [ -z ${operation_region} ] \
        || [ -z ${profile} ]; then
        echo "Invalid options for check_stack_set_operation function"
        return 1
    fi

    while true;
    do
        local operation_status=$(aws cloudformation describe-stack-set-operation \
            --stack-set-name ${stack_set_name} \
            --operation-id ${operation_id} \
            --region ${operation_region} \
            --profile ${profile} \
            | jq -r .StackSetOperation.Status)

        echo "=== STATUS: ${operation_status} ==="

        if [ "${operation_status}" == "RUNNING" ]; then
            echo "Waiting for SUCCEEDED..."
            echo
            sleep 10
        elif [ "${operation_status}" == "SUCCEEDED" ]; then
            echo "SUCCESS."
            break
        else
            echo "!!!!!!!!!!!!!!!!!!!!!!!"
            echo "!!! Error Occurred. !!!"
            echo "!!!!!!!!!!!!!!!!!!!!!!!"
            return 1
        fi
    done
}


function deploy_stack_sets {
    local template_path="$1"
    local stack_set_name="$2"
    local operation_region="$3"
    local parameters="$4"
    local profile="$5"

    if [ -z "${template_path}" ] \
        || [ -z "${stack_set_name}" ] \
        || [ -z "${operation_region}" ] \
        || [ -z "${parameters}" ] \
        || [ -z "${profile}" ]; then
        echo "Invalid options for deploy_stack_sets function"
        return 1
    fi

    check_stack_exists=$(aws cloudformation describe-stack-set \
        --stack-set-name ${stack_set_name} \
        --region ${operation_region} \
        --profile ${profile} 2>&1 >/dev/null || true)

    if [ -n "${check_stack_exists}" ]; then
        echo "create stack set..."
        echo

        aws cloudformation create-stack-set \
            --stack-set-name ${stack_set_name} \
            --template-body file://${template_path} \
            --parameters $(echo "${parameters}") \
            --region ${operation_region} \
            --profile ${profile}
    else
        echo "update stack set..."
        echo

        operation_id=$(aws cloudformation update-stack-set \
            --stack-set-name ${stack_set_name} \
            --template-body file://${template_path} \
            --parameters $(echo "${parameters}") \
            --region ${operation_region} \
            --query "OperationId" \
            --output text \
            --profile ${profile})

        check_stack_set_operation "${stack_set_name}" "${operation_id}" "${operation_region}" "${profile}"
    fi

    stack_instances_regions=$(aws cloudformation list-stack-instances \
        --stack-set-name ${stack_set_name} \
        --region ${operation_region} \
        --query "Summaries[].Region" \
        --output text \
        --profile ${profile} \
        2>/dev/null || true \
        )

    regions=$(aws ec2 describe-regions --query "Regions[].RegionName" --region ${operation_region} --output text --profile ${profile})
    add_instances_region=()

    for region in ${regions};
    do 
        if [ -z "$(echo ${stack_instances_regions} | grep ${region})" ];then
            add_instances_region+=( ${region} )
        fi
    done

    if [ ${#add_instances_region[@]} -ne 0 ];then
        account_id=$(aws sts get-caller-identity --query "Account" --output text --profile ${profile})

        echo "create stack instances..."
        echo

        operation_id=$(aws cloudformation create-stack-instances \
            --stack-set-name ${stack_set_name} \
            --accounts ${account_id} \
            --regions ${add_instances_region[@]} \
            --operation-preferences MaxConcurrentPercentage=100,FailureTolerancePercentage=100 \
            --region ${operation_region} \
            --query "OperationId" \
            --output text \
            --profile ${profile})
            
        check_stack_set_operation "${stack_set_name}" "${operation_id}" "${operation_region}" "${profile}"
    fi

    echo "Finished."
}