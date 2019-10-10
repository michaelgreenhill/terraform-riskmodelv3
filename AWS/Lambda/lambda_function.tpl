""" Lambda to launch ec2-instances """
import boto3

REGION = 'ap-southeast-2' # region to launch instance.
AMI = '${ami}'
INSTANCE_TYPE = '${ec2_type}' # instance type to launch.

EC2 = boto3.client('ec2', region_name=REGION)

def lambda_handler(event, context):
    init_script = """${cloud-init}"""

    instance = EC2.run_instances(
        BlockDeviceMappings=[
            {
                'DeviceName': '${root_device_name}',
                'Ebs': {
                    'DeleteOnTermination': True,
                    'VolumeSize': ${ebs_size},
                    'VolumeType': 'gp2'
                }
            },
        ],
        KeyName='${key_name}',
        ImageId=AMI,
        InstanceType=INSTANCE_TYPE,
        IamInstanceProfile={
            'Name': '${role}'
        },
        MinCount=1, # required by boto, even though it's kinda obvious.
        MaxCount=1,
        SecurityGroupIds=['${sg}'],
        SubnetId='${subnet}',
        PrivateIpAddress='${ec2_ip}',
        TagSpecifications=[
            {
                'ResourceType': 'instance',
                'Tags': [
                    {
                        'Key': 'Name',
                        'Value': 'mim-riskmodel-v3-alpha-builder'
                    },
                    {
                        'Key': 'billing',
                        'Value': 'riskmodel-v3'
                    },
                ]
            }
        ],
        InstanceInitiatedShutdownBehavior='terminate', # make shutdown in script terminate ec2
        UserData=init_script # file to run on instance init.
    )

    print("New instance created.")
    instance_id = instance['Instances'][0]['InstanceId']
    print(instance_id)

    return instance_id