#!/bin/bash

VPC_ID="vpc-0ebcdb39f7a526ef9"

delete_nacl(){
    local nacl_id="$1"
    aws_response=$(aws ec2 delete-network-acl --network-acl-id "$nacl_id")
    echo "$aws_response" > nacl_delete_response.json
}
create_nacl(){
    local nacl_name="$1"
    aws_response=$(aws ec2 create-network-acl \
        --vpc-id $VPC_ID \
        --tag-specifications 'ResourceType=network-acl,Tags=[{Key=Name,Value=$nacl_name}]' \ )

    echo "$aws_response" > nacl.json
}

create_nacl "$1"