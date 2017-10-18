#!/usr/local/bin/bash

# constants
table_scaleable_write_dimension="dynamodb:table:WriteCapacityUnits"
table_scaleable_read_dimension="dynamodb:table:ReadCapacityUnits"
index_scaleable_write_dimension="dynamodb:index:WriteCapacityUnits"
index_scaleable_read_dimension="dynamodb:index:ReadCapacityUnits"

write_metric_type="DynamoDBWriteCapacityUtilization"
read_metric_type="DynamoDBReadCapacityUtilization"

usage()
{
  echo "Usage: $0 [-m <enable|disable>] [-r <role name>] [-p <table prefix>] [-i <min throughput>] [-x <max throughput>]" 1>&2
  exit 1
}

check_cli_version()
{
  min_ver='1.11.129'
  current_ver=$(aws --version 2>&1 |cut -f2 -d"/" |cut -f1 -d" ")

  vercomp ${current_ver} ${min_ver}
  status=$?

  if [ ${status} -eq 2 ]; then
    echo "You do not have the required version of the AWS CLI to run this script"
    echo "Your version: ${current_ver}  Minimum version: ${min_ver}"
    echo "Use: pip install awscli --upgrade"
    exit 1
  fi
}

# Compare 2 symantic versions
# https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash
vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

# Sees if a role exists in IAM
role_exists()
{
  role_name=$1

  role_arn=$(aws iam get-role \
                 --role-name ${role_name} \
                 --query "Role.Arn" \
                 --output text)

  if [ -z "${role_arn}" ]; then
    echo "false"
  else
    echo "${role_arn}"
  fi
}

# Populates the global array of tables matching our prefix filter
list_tables_with_filter()
{
  prefix=$1

  # get the table list and use JMESPath to filter it
  table_list_str=$(aws dynamodb list-tables \
                      --query "TableNames[?starts_with(@,\`${prefix}\`) == \`true\`]" \
                      --output text)

  echo "${table_list_str}"
}

get_table_indexes()
{
  table_name=$1

  table_index_list=$(aws dynamodb describe-table \
                        --table-name ${table_name} \
                        --query "Table.GlobalSecondaryIndexes[*].IndexName" \
                        --output text)

  if [ "${table_index_list}" == "None" ]; then
    echo ""
  else
    echo "${table_index_list}"
  fi
}

scalable_target_exists()
{
  resource_id=$1
  scalable_dimension=$2

  scalable_target=$(aws application-autoscaling describe-scalable-targets \
                        --service-namespace dynamodb \
                        --resource-id "${resource_id}" \
                        --query "ScalableTargets[?contains(ScalableDimension,\`${scalable_dimension}\`) == \`true\`]" \
                        --output text)

  if [ -z "${scalable_target}" ]; then
    echo "false"
  else
    echo "true"
  fi
}

register_scalable_target()
{
  resource_id=$1
  scalable_dimension=$2
  role_arn=$3
  min_tput=$4
  max_tput=$5

  aws application-autoscaling register-scalable-target \
    --service-namespace dynamodb \
    --resource-id "${resource_id}" \
    --scalable-dimension "${scalable_dimension}" \
    --min-capacity ${min_tput} \
    --max-capacity ${max_tput} \
    --role-arn ${role_arn}

  status=$?

  if [ ${status} -eq 0 ]; then
    echo "true"
  else
    echo "false"
  fi
}

deregister_scalable_target()
{
  resource_id=$1
  scalable_dimension=$2

  aws application-autoscaling deregister-scalable-target \
    --service-namespace dynamodb \
    --resource-id "${resource_id}" \
    --scalable-dimension "${scalable_dimension}"

  status=$?

  if [ ${status} -eq 0 ]; then
    echo "true"
  else
    echo "false"
  fi
}

scaling_policy_exists()
{
  resource_id=$1
  metric_type=$2

  policy_name=$(get_policy_name $resource_id $metric_type)

  scaling_policy=$(aws application-autoscaling describe-scaling-policies \
                      --service-namespace dynamodb \
                      --resource-id "${resource_id}" \
                      --policy-name "${policy_name}" \
                      --output text)

  if [ -z "${scaling_policy}" ]; then
    echo "false"
  else
    echo "true"
  fi
}

put_scaling_policy()
{
  resource_id=$1
  metric_type=$2
  scalable_dimension=$3

scaling_policy=$(cat <<  EOF
{"PredefinedMetricSpecification":{"PredefinedMetricType": "${metric_type}"},"TargetValue": 50.0}
EOF
)

  policy_name=$(get_policy_name $resource_id $metric_type)

  aws application-autoscaling put-scaling-policy \
    --service-namespace dynamodb \
    --resource-id "${resource_id}" \
    --scalable-dimension "${scalable_dimension}" \
    --policy-name "${policy_name}" \
    --policy-type "TargetTrackingScaling" \
    --target-tracking-scaling-policy-configuration "${scaling_policy}" > /dev/null

  status=$?

  if [ ${status} -eq 0 ]; then
    echo "true"
  else
    echo "false"
  fi
}

delete_scaling_policy()
{
  resource_id=$1
  metric_type=$2
  scalable_dimension=$3

  policy_name=$(get_policy_name $table_name $metric_type)

  aws application-autoscaling delete-scaling-policy \
    --service-namespace dynamodb \
    --resource-id "${resource_id}" \
    --scalable-dimension "${scalable_dimension}" \
    --policy-name "${policy_name}"  > /dev/null

  status=$?

  if [ ${status} -eq 0 ]; then
    echo "true"
  else
    echo "false"
  fi
}

get_policy_name()
{
  resource_id=$1
  metric_type=$2

  echo "${metric_type}:${resource_id}"
}

handle_resource()
{
  resource_id=$1
  resource_type=$2
  role_arn=$3
  status="true"

  if [ "${resource_type}" == "table" ]; then
    read_dimension=${table_scaleable_read_dimension}
    write_dimension=${table_scaleable_write_dimension}
  elif [ "${resource_type}" == "index" ]; then
    read_dimension=${index_scaleable_read_dimension}
    write_dimension=${index_scaleable_write_dimension}
  fi

  echo -n "checking for scalable target (read throughput) for ${resource_id}..." 1>&2
  if [[ "$(scalable_target_exists ${resource_id} ${read_dimension})" == "true" ]]; then
    if [ "${mode}" == "disable" ]; then
      echo -n "DISABLING...." 1>&2
      if [[ "$(deregister_scalable_target ${resource_id} ${read_dimension})" == "true" ]]; then
        echo "DONE" 1>&2
      else
        echo "ERROR" 1>&2
        status="false"
      fi
    else
      echo "FOUND" 1>&2
    fi
  else
    if [ "${mode}" == "enable" ]; then
      echo -n "CREATING...." 1>&2
      if [[ "$(register_scalable_target ${resource_id} ${read_dimension} ${role_arn} ${min_tput} ${max_tput})" == "true" ]]; then
        echo "DONE" 1>&2
      else
        echo "ERROR" 1>&2
        status="false"
      fi
    else
      echo "NOT FOUND" 1>&2
    fi
  fi

  echo -n "checking for scalable target (write throughput) for ${resource_id}..." 1>&2
  if [[ "$(scalable_target_exists ${resource_id} ${write_dimension})" == "true" ]]; then
    if [ "${mode}" == "disable" ]; then
      echo -n "DISABLING...." 1>&2
      if [[ "$(deregister_scalable_target ${resource_id} ${write_dimension})" == "true" ]]; then
        echo "DONE" 1>&2
      else
        echo "ERROR" 1>&2
        status="false"
      fi
    else
      echo "FOUND" 1>&2
    fi
  else
    if [ "${mode}" == "enable" ]; then
      echo -n "CREATING..." 1>&2
      if [[ "$(register_scalable_target ${resource_id} ${write_dimension} ${role_arn} ${min_tput} ${max_tput})" == "true" ]]; then
        echo "DONE" 1>&2
      else
        echo "ERROR" 1>&2
        status="false"
      fi
    else
      echo "NOT FOUND" 1>&2
    fi
  fi

  # Once we have the scalable targets, we can see if the scaling policies exist
  echo -n "checking for scaling policy (read throughput) for ${resource_id}..." 1>&2
  if [[ "$(scaling_policy_exists ${resource_id} ${read_metric_type})" == "true" ]]; then
    if [ "${mode}" == "disable" ]; then
      echo -n "DISABLING...." 1>&2
      if [[ "$(delete_scaling_policy ${resource_id} ${read_metric_type} ${read_dimension})" == "true" ]]; then
        echo "DONE" 1>&2
      else
        echo "ERROR" 1>&2
        status="false"
      fi
    else
      echo "FOUND" 1>&2
    fi
  else
    if [ "${mode}" == "enable" ]; then
      echo -n "CREATING..." 1>&2
      if [[ "$(put_scaling_policy ${resource_id} ${read_metric_type} ${read_dimension})" == "true" ]]; then
        echo "DONE" 1>&2
      else
        echo "ERROR" 1>&2
        status="false"
      fi
    else
      echo "NOT FOUND" 1>&2
    fi
  fi

  # Once we have the scalable targets, we can see if the scaling policies exist
  echo -n "checking for scaling policy (write throughput) for ${resource_id}..." 1>&2
  if [[ "$(scaling_policy_exists ${resource_id} ${write_metric_type})" == "true" ]]; then
    if [ "${mode}" == "disable" ]; then
      echo -n "DISABLING...." 1>&2
      if [[ "$(delete_scaling_policy ${resource_id} ${write_metric_type} ${write_dimension})" == "true" ]]; then
        echo "DONE" 1>&2
      else
        echo "ERROR" 1>&2
        status="false"
      fi
    else
      echo "FOUND" 1>&2
    fi
  else
    if [ "${mode}" == "enable" ]; then
      echo -n "CREATING..." 1>&2
      if [[ "$(put_scaling_policy ${resource_id} ${write_metric_type} ${write_dimension})" == "true" ]]; then
        echo "DONE" 1>&2
      else
        echo "ERROR" 1>&2
        status="false"
      fi
    else
      echo "NOT FOUND" 1>&2
    fi
  fi

  echo "${status}"
}

# ======================
# ====== MAIN
# ======================

check_cli_version

while getopts ":m:r:p:i:x:" o; do
    case "${o}" in
        m)
            mode=${OPTARG}
            ;;
        r)
            rolename=${OPTARG}
            ;;
        p)
            prefix=${OPTARG}
            ;;
        i)
            min_tput=${OPTARG}
            ;;
        x)
            max_tput=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${mode}" ] || [ -z "${rolename}" ] || [ -z "${prefix}" ] || [ -z "${min_tput}" ] || [ -z "${max_tput}" ]; then
  usage
fi

if [ "${mode}" == "enable" ] || [ "${mode}" == "disable" ] ; then
  echo "Running in ${mode} mode"
else
  usage
fi

# Main logic
role_arn=$(role_exists ${rolename})

if [[ "${role_arn}" != "false" ]]; then
  echo "DynamoDB autoscaling role found OK"

  table_list=$(list_tables_with_filter ${prefix})

  for table_name in $(echo $table_list)
  do
    table_resource_id="table/${table_name}"

    if [[ "$(handle_resource ${table_resource_id} 'table' ${role_arn})" == "true" ]]; then
      echo "Successfully processed table ${table_name}"

      # Does this table have indexes?  If so, we need to enable scaling for each
      table_indexes=$(get_table_indexes ${table_name})

      for index_name in $(echo ${table_indexes})
      do
        echo "Found index ${index_name} for table ${table_name} - processing"
        index_resource_id="table/${table_name}/index/${index_name}"

        if [[ "$(handle_resource ${index_resource_id} 'index' ${role_arn})" == "true" ]]; then
          echo "Successfully processed index ${index_name}"
        else
          echo "Error processing index ${index_name}"
        fi
      done
    else
      echo "ERROR processing table ${table_name}"
    fi
  done
else
  echo "DynamoDB autoscaling role not found - create one. See https://goo.gl/JVmkGS"
fi
