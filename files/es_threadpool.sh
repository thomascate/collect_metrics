#!/bin/bash

source /home/centos/instance_info

hostname=`hostname`

command=`curl -s -XGET "http://$hostname:9200/_nodes/_local/stats/thread_pool" | /home/centos/jq-linux64 '(.. | .thread_pool?.index.threads | numbers) , (.. | .thread_pool?.index.queue | numbers) , (.. | .thread_pool?.index.active | numbers) , (.. | .thread_pool?.index.rejected | numbers) , (.. | .thread_pool?.index.largest | numbers) , (.. | .thread_pool?.index.completed | numbers)'`

mapfile -t es_metrics <<<"$command"

# echo "ThreadpoolIndexThreads: ${es_metrics[0]}"
# echo "ThreadpoolIndexQueue: ${es_metrics[1]}"
# echo "tThreadpoolIndexThreadsActive: ${es_metrics[2]}"
# echo "ThreadpoolIndexThreadsRejected: ${es_metrics[3]}"
# echo "ThreadpoolIndexThreadsLargest: ${es_metrics[4]}"
# echo "ThreadpoolIndexThreadsCompleted: ${es_metrics[5]}"

per_host_options="--namespace AWS/EC2 --region us-west-2 --dimensions TestId=$test_id,Instance=$instance"

aws cloudwatch put-metric-data $per_host_options --metric-name ThreadpoolIndexThreads --unit Bytes --value ${es_metrics[0]}
aws cloudwatch put-metric-data $per_host_options --metric-name ThreadpoolIndexQueue --unit Percent --value ${es_metrics[1]}
aws cloudwatch put-metric-data $per_host_options --metric-name ThreadpoolIndexActive --unit Count --value ${es_metrics[2]}
aws cloudwatch put-metric-data $per_host_options --metric-name ThreadpoolIndexRejected --unit Milliseconds --value ${es_metrics[3]}
aws cloudwatch put-metric-data $per_host_options --metric-name ThreadpoolIndexLargest --unit Count --value ${es_metrics[4]}
aws cloudwatch put-metric-data $per_host_options --metric-name ThreadpoolIndexCompleted --unit Milliseconds --value ${es_metrics[5]}
