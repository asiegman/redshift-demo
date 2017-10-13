#!/bin/bash -e
set -e

CFFILE=file://cf-redshift.yaml
STACK=testredshift

function validate {
    aws cloudformation validate-template --template-body ${1}
}

function create {
    aws cloudformation create-stack --stack-name ${STACK} \
        --template-body ${CFFILE} \
        --timeout-in-minutes 30 \
        --on-failure DO_NOTHING \
        --parameters ParameterKey=ChargeCode,ParameterValue=dev \
                     ParameterKey=ClusterName,ParameterValue=fox \
                     ParameterKey=MasterUserPassword,ParameterValue=TotallyS3cur3Password \
        --capabilities CAPABILITY_NAMED_IAM
}

function destroy {
    aws s3 rm s3://fox-cluster-bucket/ --recursive
    aws cloudformation delete-stack --stack-name ${STACK}
}

function list {
    aws cloudformation list-stacks
}

case $1 in
validate)
    validate ${CFFILE}
    ;;
create)
    create
    ;;
destroy)
    destroy
    ;;
list)
    list
    ;;
*)
    echo "Usage: $(basename $0) [validate|create|destroy|list]"
    exit 1
    ;;
esac
