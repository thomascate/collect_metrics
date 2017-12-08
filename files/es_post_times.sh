#!/bin/bash
source /home/centos/instance_info

# This script is intended to run every 5 minutes from cron.

per_host_options="--namespace AWS/EC2 --region us-west-2 --dimensions TestId=$test_id,Instance=$instance"

# Count HTTP codes
data_collector_logs=`journalctl --since "5 minutes ago" | grep data-collector | grep POST`
COUNT_2XX=`echo $data_collector_logs | awk '{print $15}' | grep -c "^2"`
COUNT_3XX=`echo $data_collector_logs | awk '{print $15}' | grep -c "^3"`
COUNT_4XX=`echo $data_collector_logs | awk '{print $15}' | grep -c "^4"`
COUNT_5XX=`echo $data_collector_logs | awk '{print $15}' | grep -c "^5"`

aws cloudwatch put-metric-data $per_host_options --metric-name 2xxStatuses --unit Count --value ${COUNT_2XX}
aws cloudwatch put-metric-data $per_host_options --metric-name 3xxStatuses --unit Count --value ${COUNT_3XX}
aws cloudwatch put-metric-data $per_host_options --metric-name 4xxStatuses --unit Count --value ${COUNT_4XX}
aws cloudwatch put-metric-data $per_host_options --metric-name 5xxStatuses --unit Count --value ${COUNT_5XX}
