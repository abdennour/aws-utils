# Overview

According to the specified region, the script will search on all running instances, then it extracts the volumes ids attached to those EBS volumes, then it takes a snapshot for each volume with a consistent tagging approach.  
# Pre-requistes

- aws-cli 1.14.50 or later (https://github.com/aws/aws-cli/archive/1.14.50.tar.gz)


```
AWS_REGION=eu-central-1  create_ebs_snapshot_per_region
```
