#!/bin/bash
set -x

aws ec2 delete-security-group --group-name ssh
aws ec2 delete-key-pair --key-name codedeploy

aws iam remove-role-from-instance-profile --instance-profile-name code_deploy_instance_profile --role-name code_deploy_instance_role
aws iam delete-instance-profile --instance-profile-name code_deploy_instance_profile
aws iam delete-role-policy --role-name code_deploy_instance_role --policy-name code_deploy_instance_role-EC2-permissions
aws iam delete-role --role-name code_deploy_instance_role

aws iam detach-role-policy --role-name code_deploy_service --policy-arn arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole
aws iam delete-role --role-name code_deploy_service


