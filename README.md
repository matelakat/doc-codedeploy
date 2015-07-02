0.) Sign up to amazon, create a user with administrative privileges, set your
region to `eu-west-1`.

1.) On the development computer, install aws cli

    pip install awscli

2.) Configure your aws

    aws configure

3.) Create service IAM role - to be used for performing the deployment

    aws iam create-role --role-name code_deploy_service --assume-role-policy-document file://role-policies/codedeploy-trust.json

Add a managed policy:

    aws iam attach-role-policy --role-name code_deploy_service --policy-arn arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole

Get the ARN:

    aws iam get-role --role-name code_deploy_service --query "Role.Arn" --output text

4.) Create instance IAM role - to be used by the instances

    aws iam create-role --role-name code_deploy_instance_role --assume-role-policy-document file://role-policies/ec2-trust.json
    aws iam put-role-policy --role-name code_deploy_instance_role --policy-name code_deploy_instance_role-EC2-permissions --policy-document file://role-policies/ec2-permissions.json

    aws iam create-instance-profile --instance-profile-name code_deploy_instance_profile
    aws iam add-role-to-instance-profile --instance-profile-name code_deploy_instance_profile --role-name code_deploy_instance_role

5.) Create keypair

    aws ec2 create-key-pair --key-name codedeploy > key-pair-output
    cat key-pair-output | sed -e 's,^[^-]*\(-.*\)$,\1,g' | sed -e 's,^\(-*[^-]*-*\).*$,\1,g' > key.pem
    chmod 0400 key.pem

6.) Create security group

    aws ec2 create-security-group --group-name ssh --description "SSH Access"
    aws ec2 authorize-security-group-ingress --group-name ssh --protocol tcp --port 22 --cidr 0.0.0.0/0

6.) Launch an instance

    aws ec2 run-instances \
        --image-id ami-47a23a30 \
        --key-name codedeploy \
        --user-data file://instance/setup.sh \
        --count 1 \
        --instance-type t2.micro \
        --iam-instance-profile Name=code_deploy_instance_profile \
        --security-groups ssh


