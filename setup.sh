#!/bin/bash
set -eux

# Create service IAM role - to be used for performing the deployment
aws iam create-role \
    --role-name code_deploy_service \
    --assume-role-policy-document file://role-policies/codedeploy-trust.json > service_role.json

SERVICE_ROLE_ARN=$(cat service_role.json | jq -r '.Role.Arn')

# Enable codedeploy for this role
aws iam attach-role-policy --role-name code_deploy_service --policy-arn arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole

# Create instance IAM role - to be used by the instances
aws iam create-role --role-name code_deploy_instance_role \
    --assume-role-policy-document file://role-policies/ec2-trust.json
aws iam put-role-policy --role-name code_deploy_instance_role \
    --policy-name code_deploy_instance_role-EC2-permissions \
    --policy-document file://role-policies/ec2-permissions.json

aws iam create-instance-profile \
    --instance-profile-name code_deploy_instance_profile
aws iam add-role-to-instance-profile \
    --instance-profile-name code_deploy_instance_profile \
    --role-name code_deploy_instance_role

# Create keypair
aws ec2 create-key-pair --key-name codedeploy --output text > key-pair-output
cat key-pair-output | sed -e 's,^[^-]*\(-.*\)$,\1,g' | sed -e 's,^\(-*[^-]*-*\).*$,\1,g' > key.pem
chmod 0400 key.pem

# Create security group
aws ec2 create-security-group --group-name ssh --description "SSH Access"
aws ec2 authorize-security-group-ingress --group-name ssh --protocol tcp --port 22 --cidr 0.0.0.0/0

# Wait a bit so that IAM is all synced
sleep 10

# Launch an instance PublicIpAddress
aws ec2 run-instances \
    --image-id ami-47a23a30 \
    --key-name codedeploy \
    --user-data file://instance/setup.sh \
    --count 1 \
    --instance-type t2.micro \
    --iam-instance-profile Name=code_deploy_instance_profile \
    --security-groups ssh > instance.json

INSTANCE=$(cat instance.json | jq -r ' .Instances | .[] | .InstanceId')

# Create a tag
aws ec2 create-tags --tags Key=CodeDeployTag,Value=Demo --resources $INSTANCE

# Create a bucket
aws s3api create-bucket \
    --bucket doc-codedeploy \
    --create-bucket-configuration LocationConstraint=eu-west-1

# Create application
aws deploy create-application --application-name demo_app

# Push the application
aws deploy push \
    --application-name demo_app \
    --ignore-hidden-files \
    --s3-location s3://doc-codedeploy/stuff.tgz \
    --source revision

# Create a deployment group
aws deploy create-deployment-group \
    --application-name demo_app \
    --deployment-config-name CodeDeployDefault.OneAtATime \
    --deployment-group-name demo_dg \
    --ec2-tag-filters Key=CodeDeployTag,Value=Demo,Type=KEY_AND_VALUE \
    --service-role-arn $SERVICE_ROLE_ARN

# Create deployment config
aws deploy create-deployment-config \
    --deployment-config-name all_can_fail \
    --minimum-healthy-hosts type=HOST_COUNT,value=0

# Wait for an IP address
while true; do
    IPADDR=$(aws ec2 describe-instances --instance-ids $INSTANCE | jq -r '.Reservations | .[] | .Instances | .[] | .PublicIpAddress')
    if [ "null" == "$IPADDR" ]; then
        sleep 5
    else
        break
    fi
done

# Do the deployment
aws deploy create-deployment \
    --application-name demo_app \
    --s3-location bucket=doc-codedeploy,key=stuff.tgz,bundleType=zip \
    --deployment-group-name demo_dg \
    --deployment-config-name all_can_fail \
    --description "Demo deployment" > deployment.json

DEPLOYMENT_ID=$(cat deployment.json | jq -r '.deploymentId')

set +x
cat << EOF

--- ALL DONE! ---

To get info on deployment:

    aws deploy get-deployment --deployment-id $DEPLOYMENT_ID

To access your instance:

    ssh -i key.pem ubuntu@$IPADDR
EOF
