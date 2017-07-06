#!/bin/bash
source /home/centos/instance_info

hostname=`hostname`

node_index=`curl -s -XGET http://$hostname:9200/_cat/indices | grep 'insights-20' | sort -r | head -1 | awk '{ print $3 }'`
compliance_index=`curl -s -XGET http://$hostname:9200/_cat/indices | grep 'compliance-20' | sort -r | head -1 | awk '{ print $3 }'`

if [ -z $node_index ]
then
echo "no insights index found"
exit 1
fi

if [ -z $node_index ]
then
echo "no compliance index found"
exit 1
fi

node_records=`curl -s -XGET http://$hostname:9200/$node_index/_count | /home/centos/jq-linux64 '.count'`
compliance_records=`curl -s -XGET http://$hostname:9200/$compliance_index/_count | /home/centos/jq-linux64 '.count'`
total_records=$(awk "BEGIN {print $node_records+$compliance_records; exit}")

node_index_bytes=`curl -s -XGET http://$hostname:9200/$node_index/_stats/store?pretty | /home/centos/jq-linux64 '._all.total.store.size_in_bytes'`
compliance_index_bytes=`curl -s -XGET http://$hostname:9200/$compliance_index/_stats/store?pretty | /home/centos/jq-linux64 '._all.total.store.size_in_bytes'`
total_bytes=$(awk "BEGIN {print $node_index_bytes+$compliance_index_bytes; exit}")

curtime=`date +%s`
node_records_per_minute=`/home/centos/index_records.py $node_index $curtime $node_records`
compliance_records_per_minute=`/home/centos/index_records.py $compliance_index $curtime $compliance_records`
total_records_per_minute=$(awk "BEGIN {print $node_records_per_minute+$compliance_records_per_minute; exit}")

es_metrics[0]=$node_records
es_metrics[1]=$node_index_bytes
es_metrics[2]=$node_records_per_minute
es_metrics[3]=$compliance_records
es_metrics[4]=$compliance_index_bytes
es_metrics[5]=$compliance_records_per_minute
es_metrics[6]=$total_records
es_metrics[7]=$total_records_per_minute
es_metrics[8]=$total_bytes

per_host_options="--namespace AWS/EC2 --region us-west-2 --dimensions TestId=$test_id,Instance=$instance"

aws cloudwatch put-metric-data $per_host_options --metric-name NodeRecords --unit Count --value ${es_metrics[0]}
aws cloudwatch put-metric-data $per_host_options --metric-name NodeIndexBytes --unit Bytes --value ${es_metrics[1]}
aws cloudwatch put-metric-data $per_host_options --metric-name NodeRecordsPerMinute --unit Count --value ${es_metrics[2]}
aws cloudwatch put-metric-data $per_host_options --metric-name ComplianceRecords --unit Count --value ${es_metrics[3]}
aws cloudwatch put-metric-data $per_host_options --metric-name ComplianceIndexBytes --unit Bytes --value ${es_metrics[4]}
aws cloudwatch put-metric-data $per_host_options --metric-name ComplianceRecordsPerMinute --unit Count --value ${es_metrics[5]}
aws cloudwatch put-metric-data $per_host_options --metric-name TotalRecords --unit Count --value ${es_metrics[6]}
aws cloudwatch put-metric-data $per_host_options --metric-name TotalRecordsPerMinute --unit Count --value ${es_metrics[7]}
aws cloudwatch put-metric-data $per_host_options --metric-name TotalBytes --unit Bytes --value ${es_metrics[8]}