#!/bin/bash
set -x

aws deploy delete-deployment-group --application-name demo_app --deployment-group-name demo_dg

aws deploy delete-deployment-config --deployment-config-name all_can_fail

aws deploy delete-application --application-name demo_app

aws s3 rm s3://doc-codedeploy/stuff.tgz

aws s3api delete-bucket --bucket doc-codedeploy

aws ec2 describe-instances | jq -r '.Reservations | .[] | .Instances | map(select(.State.Code == 16)) | map(select(.KeyName == "codedeploy")) |.[] | .InstanceId' |
while read instance_id; do
    aws ec2 terminate-instances --instance-ids $instance_id
done

while aws ec2 delete-security-group --group-name ssh 2>&1 | grep -q DependencyViolation; do
    sleep 5;
done

aws ec2 delete-key-pair --key-name codedeploy

aws iam remove-role-from-instance-profile --instance-profile-name code_deploy_instance_profile --role-name code_deploy_instance_role
aws iam delete-instance-profile --instance-profile-name code_deploy_instance_profile
aws iam delete-role-policy --role-name code_deploy_instance_role --policy-name code_deploy_instance_role-EC2-permissions
aws iam delete-role --role-name code_deploy_instance_role

aws iam detach-role-policy --role-name code_deploy_service --policy-arn arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole
aws iam delete-role --role-name code_deploy_service

rm -f key.pem


