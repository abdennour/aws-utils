#!/bin/sh
# Usage: $ ./ebs_snapshot_pre_region eu-west1
#
# Arguments:
# $1 region
# @auhtor Abdennour <in.abdennoor.com>
#
if [ "$1" == "help" ] ; then
  cat << EOF
# Usage:
    ./ebs_snapshot_pre_region [AWS_REGION]
# Overview:
   Create snapshot of all volumes attached to running EC2 instances in the specified region
# Requirements:
 IAM user or role should have the following permissions to be able to execute this script successfully
    Version: '2012-10-17'
    Statement:
    - Sid: VisualEditor0
      Effect: Allow
      Action: ec2:CreateTags
      Resource: arn:aws:ec2:*::snapshot/*
    - Sid: VisualEditor1
      Effect: Allow
      Action:
      - ec2:DescribeTags
      - ec2:CreateSnapshot
      - ec2:DescribeSnapshots
      Resource: "*"
# Examples:
  ./ebs_snapshot_pre_region eu-west-1
  ./ebs_snapshot_pre_region eu-central-1
EOF
  exit 0
fi


REGION=$1
#init
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE=/tmp/snap$(openssl rand -hex 12)
mkdir -p $WORKSPACE
# funcs
snapshot_whole_region() {
  PROVIDER_REGION=$1
  FILTERS_PATH=$WORKSPACE/$(openssl rand -hex 12).json
  OUTPUT_PATH=$WORKSPACE/$(openssl rand -hex 12)
  FORMATTED_OUTPUT_PATH=$WORKSPACE/$(openssl rand -hex 12)

  QUERY_INSTANCE_ID='Reservations[*].Instances[*].[InstanceId]'
  QUERY_VOLUME_IDS='Reservations[*].Instances[*].[BlockDeviceMappings[*].Ebs.VolumeId]'
  cat >$FILTERS_PATH <<EOF
[
  {
    "Name": "instance-state-name",
    "Values": ["running"]
  }
]
EOF

  aws ec2 describe-instances \
    --filters file://$FILTERS_PATH \
    --query "Reservations[*].Instances[*].[InstanceId,BlockDeviceMappings[*].Ebs.VolumeId]" \
    --output text \
    --region $PROVIDER_REGION >$OUTPUT_PATH

  # merge each two lines in one line with space
  paste -d " " - - <$OUTPUT_PATH >$FORMATTED_OUTPUT_PATH

  while read line; do
    INSTANCE_ID=$(echo $line | cut -f1 -d" ")
    VOLUME_ID=$(echo $line | cut -f2 -d" ")
    SECOND_VOLUME_ID=$(echo $line | cut -f3 -d" ")
    snapshot_one_volume $INSTANCE_ID $VOLUME_ID 0 $PROVIDER_REGION
    if [[ $SECOND_VOLUME_ID ]]; then
      snapshot_one_volume $INSTANCE_ID $SECOND_VOLUME_ID 1 $PROVIDER_REGION
    fi
  done <$FORMATTED_OUTPUT_PATH

}

snapshot_one_volume() {
  echo Snapshot Volume $2 of instance $1 Index $3
  # $1 INSTANCE_ID
  # $2 VOLUME_ID
  # $2 VOLUME index
  INSTANCE_ID=$1
  VOLUME_ID=$2
  VOLUME_INDEX=$3
  PROVIDER_REGION=$4
  EXPIRES_AT=$(date -v +1m "+%Y-%m-%d %H:%M:%S")

  aws ec2 create-snapshot --volume-id $VOLUME_ID \
    --description "Automated Snapshots of volume $VOLUME_ID instance $INSTANCE_ID" \
    --tag-specifications 'ResourceType=snapshot,Tags=[{Key=InstanceId,Value='"$INSTANCE_ID"'},{Key=VolumeId,Value='"$VOLUME_ID"'},{Key=VolumeIndex,Value='"$VOLUME_INDEX"'},{Key=ExpirationDate,Value='"$EXPIRES_AT"'}]' \
    --region $PROVIDER_REGION
}

snapshot_whole_region $REGION

#clean up
rm -rf $WORKSPACE
