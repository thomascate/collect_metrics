#!/bin/bash
source /home/centos/instance_info

# This script is intended to run every 5 minutes from cron.

per_host_options="--namespace AWS/EC2 --region us-west-2 --dimensions TestId=$test_id,Instance=$instance"

LOGS_LAST_5MIN=$(journalctl --since "5 minutes ago" -u chef-automate)

# Count HTTP codes
data_collector_logs=$(echo "$LOGS_LAST_5MIN" | grep data-collector | grep POST)
COUNT_2XX=`echo "$data_collector_logs" | awk '{print $15}' | grep -c "^2"`
COUNT_3XX=`echo "$data_collector_logs" | awk '{print $15}' | grep -c "^3"`
COUNT_4XX=`echo "$data_collector_logs" | awk '{print $15}' | grep -c "^4"`
COUNT_5XX=`echo "$data_collector_logs" | awk '{print $15}' | grep -c "^5"`

aws cloudwatch put-metric-data $per_host_options --metric-name 2xxStatuses --unit Count --value ${COUNT_2XX}
aws cloudwatch put-metric-data $per_host_options --metric-name 3xxStatuses --unit Count --value ${COUNT_3XX}
aws cloudwatch put-metric-data $per_host_options --metric-name 4xxStatuses --unit Count --value ${COUNT_4XX}
aws cloudwatch put-metric-data $per_host_options --metric-name 5xxStatuses --unit Count --value ${COUNT_5XX}

# Get average DataCollector POST times in seconds
DC_POST_REQUEST_TIME=$(echo "$data_collector_logs" | awk '{gsub(/ms/, "")} {sum22+=$22} END {print (sum22/NR)/1000.0}')
aws cloudwatch put-metric-data $per_host_options --metric-name 5MinuteAveragePostRequestTime --unit Seconds --value ${DC_POST_REQUEST_TIME}

# Get the number of RPC Calls received through the legacy-endpoint (by the Gateway)
GATEWAY_LEGACY_RPC_CALLS=$(echo "$LOGS_LAST_5MIN" | grep automate-gateway | grep "rpc call" | grep -c ProcessLegacyEvent)
aws cloudwatch put-metric-data $per_host_options --metric-name LegacyEvents --unit Count --value ${GATEWAY_LEGACY_RPC_CALLS}

LOGS_INGEST_TIME=$(echo "$LOGS_LAST_5MIN" | grep metric | grep type=ingest_time)

# Get the number of ChefRun messages ingested and failed (by the Ingest pipeline)
INGESTED_MESSAGES=$(echo "$LOGS_INGEST_TIME" | grep -c "ChefRun ingested successfully")
FAILED_MESSAGES=$(echo "$LOGS_LAST_5MIN" | grep -c "Unable to ingest ChefRun message")
aws cloudwatch put-metric-data $per_host_options --metric-name SuccessIngestedMessages --unit Count --value ${INGESTED_MESSAGES}
aws cloudwatch put-metric-data $per_host_options --metric-name FailedIngestMessages --unit Count --value ${FAILED_MESSAGES}

# Average Ingest Pipeline time (How long does a message goes through the ingest pipeline?)
INGEST_PIPELINE_PROCESSING_TIME=$(echo "$LOGS_INGEST_TIME" | grep "ChefRun ingested successfully" | awk '{gsub(/ms/, "")} {print $(NF-1)}' |cut -d= -f2 | awk '{sum+=$1} END {print sum/NR}')
aws cloudwatch put-metric-data $per_host_options --metric-name 5MinuteAverageIngestPipelineTime --unit Milliseconds --value ${INGEST_PIPELINE_PROCESSING_TIME}

# Average ES insertion time (How long does ES takes to insert documents?)
ES_DOC_INSERT_TIME=$(echo "$LOGS_INGEST_TIME" | awk '{gsub(/ms/, "")} {print $(NF-1)}' |cut -d= -f2 | awk '{sum+=$1} END {print sum/NR}')
aws cloudwatch put-metric-data $per_host_options --metric-name 5MinuteAverageESDocInsertTime --unit Milliseconds --value ${ES_DOC_INSERT_TIME}
