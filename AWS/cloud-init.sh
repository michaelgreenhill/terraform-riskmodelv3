#!/bin/bash
export PATH=$PATH:/usr/local/bin
export DEBIAN_FRONTEND=noninteractive
hostnamectl set-hostname mim-riskmodel-v3-alpha-builder.makeitmine.local && invoke-rc.d hostname.sh start && invoke-rc.d networking force-reload && systemctl restart syslog
ln -fs /usr/share/zoneinfo/Australia/Melbourne /etc/localtime && dpkg-reconfigure -f noninteractive tzdata

apt-get install -qy prometheus-node-exporter

mkdir /var/log/riskmodel
touch /var/log/riskmodel/build.log
touch /var/log/riskmodel/batch_load_data_from_db.log
touch /var/log/riskmodel/batch_create_0_json_files.log
touch /var/log/riskmodel/batch_create_1_payment_histories.log
touch /var/log/riskmodel/batch_concatenate_payments.log
touch /var/log/riskmodel/bash_batch_create_features.log
touch /var/log/riskmodel/bash_batch_create_features_errors.log
touch /var/log/riskmodel/batch_create_3_models.log
touch /var/log/riskmodel/bash_batch_3_create_models_errors.log
touch /var/log/riskmodel/batch_check_model.log
touch /var/log/riskmodel/batch_check_model_errors.log
chown -R admin:admin /var/log/riskmodel
chmod 0777 /var/log/riskmodel

curl https://s3.amazonaws.com//aws-cloudwatch/downloads/latest/awslogs-agent-setup.py -O
chmod +x ./awslogs-agent-setup.py
./awslogs-agent-setup.py -n -r ap-southeast-2 -c s3://my-test-bucket/v3/etc/awslogs.conf

apt-get install -y rsyslog
aws s3 cp s3://my-test-bucket/v3/etc/99-graylog.conf /etc/rsyslog.d/99-graylog.conf
aws s3 cp s3://my-test-bucket/v3/etc/01-module-lineinfile.conf /etc/rsyslog.d/01-module-lineinfile.conf
aws s3 cp s3://my-test-bucket/v3/etc/20-riskmodel.conf /etc/rsyslog.d/20-riskmodel.conf
systemctl restart rsyslog

apt-get update && apt-get -qy -o 'Dpkg::Options::=--force-confdef' -o 'Dpkg::Options::=--force-confold' upgrade
apt-get install -qy htop nano sudo apt-transport-https ca-certificates curl gnupg2 software-properties-common git python3-pip unixodbc-dev libsnappy-dev libyaml-dev iotop
apt-get -qy autoclean
curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
apt-get update && apt-get -qy -o 'Dpkg::Options::=--force-confdef' -o 'Dpkg::Options::=--force-confold' install docker-ce
pip3 install --upgrade awscli dotenv python-dotenv numpy setuptools pandas pyodbc sqlalchemy parquet pyodbc pyarrow
usermod -G docker -a admin

su admin -c "echo 'this is my super secret private key' > /home/admin/.ssh/riskmodelv3-builder.pem; chmod 0600 /home/admin/.ssh/riskmodelv3-builder.pem"
su admin -c "echo 'Host riskmodel-v3-repo
    Hostname bitbucket.org
    IdentityFile /home/admin/.ssh/riskmodelv3-builder.pem
    IdentitiesOnly yes' > /home/admin/.ssh/config"

mkdir /model_data && chown admin:admin /model_data
su admin -c "ssh-keyscan bitbucket.org >> /home/admin/.ssh/known_hosts; git clone git@riskmodel-v3-repo:makeitmine/mim-risk-model.git /model_data"
aws s3 cp s3://my-test-bucket/v3/etc/alpha.env /model_data/.env && source /model_data/.env
chmod 0755 /model_data/prepare_model_env_aws.sh; chmod 0755 /model_data/build_model.sh
su admin -c "/model_data/prepare_model_env_aws.sh > /var/log/riskmodel/build.log 2>&1"

cat model_stats.json | nc -u -q1 10.0.0.66 5144

shutdown now