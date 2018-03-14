#!/bin/bash
source /home/centos/instance_info

# This script is intended to run every 5 minutes from cron.

per_host_options="--namespace AWS/EC2 --region us-west-2 --dimensions TestId=$test_id,Instance=$instance"

LOGS_LAST_5MIN=$(journalctl --since "5 minutes ago" -u chef-automate)

# Count HTTP codes
data_collector_logs=$(echo "$LOGS_LAST_5MIN" | grep data-collector | grep POST)
COUNT_2XX=`echo "$data_collector_logs" | awk '{print $13}' | grep -c "^2"`
COUNT_3XX=`echo "$data_collector_logs" | awk '{print $13}' | grep -c "^3"`
COUNT_4XX=`echo "$data_collector_logs" | awk '{print $13}' | grep -c "^4"`
COUNT_5XX=`echo "$data_collector_logs" | awk '{print $13}' | grep -c "^5"`

aws cloudwatch put-metric-data $per_host_options --metric-name 2xxStatuses --unit Count --value ${COUNT_2XX}
aws cloudwatch put-metric-data $per_host_options --metric-name 3xxStatuses --unit Count --value ${COUNT_3XX}
aws cloudwatch put-metric-data $per_host_options --metric-name 4xxStatuses --unit Count --value ${COUNT_4XX}
aws cloudwatch put-metric-data $per_host_options --metric-name 5xxStatuses --unit Count --value ${COUNT_5XX}

# Get average DataCollector POST times in seconds
#
# Parsing automate-load-balancer log:
# automate-load-balancer.default(O): - [09/Mar/2018:20:11:22 +0000]  "POST /data-collector/v0/ HTTP/1.1" 200 "7.735" 2 "-" "Go-http-client/1.1" "10.42.5.165:2000" "200" "7.734" 45250
#
DC_POST_REQUEST_TIME=$(echo "$data_collector_logs" | awk '{gsub(/\"/, "")} {sum+=$(NF-7)} END {print sum/NR}')
aws cloudwatch put-metric-data $per_host_options --metric-name 5MinuteAveragePostRequestTime --unit Seconds --value ${DC_POST_REQUEST_TIME}

# Get the number of RPC Calls received through the legacy-endpoint (by the Gateway)
GATEWAY_LEGACY_RPC_CALLS=$(echo "$LOGS_LAST_5MIN" | grep automate-gateway | grep "rpc call" | grep -c ProcessLegacyEvent)
aws cloudwatch put-metric-data $per_host_options --metric-name LegacyEvents --unit Count --value ${GATEWAY_LEGACY_RPC_CALLS}

# Metrics
LOGS_METRICS=$(echo "$LOGS_LAST_5MIN" | grep metric)
LOGS_INGEST_TIME=$(echo "$LOGS_METRICS" | grep type=ingest_time)
LOGS_ES_DOC_INSERT_TIME=$(echo "$LOGS_METRICS" | grep type=doc_insert)

# Get the number of ChefRun messages ingested and failed (by the Ingest pipeline)
INGESTED_MESSAGES=$(echo "$LOGS_INGEST_TIME" | grep -c "Message ingested successfully")
FAILED_MESSAGES=$(echo "$LOGS_INGEST_TIME" | grep -c "Unable to ingest message")
# TODO: Add official "Unsupported Messages"
# @afiune: Currently we are not ingesting the 'run_start' messages, fix this when we DO ingest them
UNSUPPORTED_MESSAGES=$(echo "$LOGS_LAST_5MIN" | grep message_type | grep -c "Unsupported message")
UNKNOWN_MESSAGES=$(expr $GATEWAY_LEGACY_RPC_CALLS - $INGESTED_MESSAGES - $UNSUPPORTED_MESSAGES - $FAILED_MESSAGES)
aws cloudwatch put-metric-data $per_host_options --metric-name SuccessIngestedMessages --unit Count --value ${INGESTED_MESSAGES}
aws cloudwatch put-metric-data $per_host_options --metric-name FailedIngestMessages --unit Count --value ${FAILED_MESSAGES}
aws cloudwatch put-metric-data $per_host_options --metric-name UnsupportedIngestMessages --unit Count --value ${UNSUPPORTED_MESSAGES}
aws cloudwatch put-metric-data $per_host_options --metric-name UnknownIngestMessages --unit Count --value ${UNKNOWN_MESSAGES}

# Average Ingest Pipeline time (How long does a message goes through the ingest pipeline?)
INGEST_PIPELINE_TIME_CHEF_ACTION=$(echo "$LOGS_INGEST_TIME" | grep message=ChefAction | grep "Message ingested successfully" | awk '{gsub(/ms/, "")} {print $(NF-1)}' |cut -d= -f2 | awk '{sum+=$1} END {print sum/NR}')
INGEST_PIPELINE_TIME_CHEF_RUN=$(echo "$LOGS_INGEST_TIME" | grep message=ChefRun | grep "Message ingested successfully" | awk '{gsub(/ms/, "")} {print $(NF-1)}' |cut -d= -f2 | awk '{sum+=$1} END {print sum/NR}')
aws cloudwatch put-metric-data $per_host_options --metric-name 5MinuteAverageIngestChefActionPipelineTime --unit Milliseconds --value ${INGEST_PIPELINE_TIME_CHEF_ACTION}
aws cloudwatch put-metric-data $per_host_options --metric-name 5MinuteAverageIngestChefRunPipelineTime --unit Milliseconds --value ${INGEST_PIPELINE_TIME_CHEF_RUN}

# Average ES insertion time (How long does ES takes to insert documents?)
ES_DOC_INSERT_TIME=$(echo "$LOGS_ES_DOC_INSERT_TIME" | awk '{gsub(/ms/, "")} {print $(NF-1)}' |cut -d= -f2 | awk '{sum+=$1} END {print sum/NR}')
aws cloudwatch put-metric-data $per_host_options --metric-name 5MinuteAverageESDocInsertTime --unit Milliseconds --value ${ES_DOC_INSERT_TIME}
