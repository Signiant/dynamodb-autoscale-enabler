#!/usr/local/bin/bash

declare -a table_array

# constants
scaleable_write_dimension="dynamodb:table:WriteCapacityUnits"
scaleable_read_dimension="dynamodb:table:ReadCapacityUnits"
write_metric_type="DynamoDBWriteCapacityUtilization"
read_metric_type="DynamoDBReadCapacityUtilization"


usage()
{
  echo "Usage: $0 [-m <enable|disable>] [-r <role name>] [-p <table prefix>] [-i <min throughput>] [-x <max throughput>]" 1>&2
  exit 1
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
  # This takes the returned data (which is space seperated) and puts it into an array
  IFS='	' read -r -a table_array <<< "$table_list_str"
}

scalable_target_exists()
{
  table_name=$1
  scalable_dimension=$2

  scalable_target=$(aws application-autoscaling describe-scalable-targets \
                        --service-namespace dynamodb \
                        --resource-id "table/${table_name}" \
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
  table_name=$1
  scalable_dimension=$2
  role_arn=$3
  min_tput=$4
  max_tput=$5

  aws application-autoscaling register-scalable-target \
    --service-namespace dynamodb \
    --resource-id "table/${table_name}" \
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
  table_name=$1
  scalable_dimension=$2

  aws application-autoscaling deregister-scalable-target \
    --service-namespace dynamodb \
    --resource-id "table/${table_name}" \
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
  table_name=$1
  metric_type=$2

  policy_name=$(get_policy_name $table_name $metric_type)

  scaling_policy=$(aws application-autoscaling describe-scaling-policies \
                      --service-namespace dynamodb \
                      --resource-id "table/${table_name}" \
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
  table_name=$1
  metric_type=$2
  scalable_dimension=$3

scaling_policy=$(cat <<  EOF
{"PredefinedMetricSpecification":{"PredefinedMetricType": "${metric_type}"},"TargetValue": 50.0}
EOF
)

  policy_name=$(get_policy_name $table_name $metric_type)

  aws application-autoscaling put-scaling-policy \
    --service-namespace dynamodb \
    --resource-id "table/${table_name}" \
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
  table_name=$1
  metric_type=$2
  scalable_dimension=$3

  policy_name=$(get_policy_name $table_name $metric_type)

  aws application-autoscaling delete-scaling-policy \
    --service-namespace dynamodb \
    --resource-id "table/${table_name}" \
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
  table_name=$1
  policy_type=$2

  echo "${policy_type}:table/${table_name}"
}

# ======================
# ====== MAIN
# ======================

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

  list_tables_with_filter ${prefix}

  for table_name in "${table_array[@]}"
  do
    echo -n "checking for scalable target (read throughput) for ${table_name}..."
    if [[ "$(scalable_target_exists ${table_name} ${scaleable_read_dimension})" == "true" ]]; then
      if [ "${mode}" == "disable" ]; then
        echo -n "DISABLING...."
        if [[ "$(deregister_scalable_target ${table_name} ${scaleable_read_dimension})" == "true" ]]; then
          echo "DONE"
        else
          echo "ERROR"
        fi
      else
        echo "FOUND"
      fi
    else
      if [ "${mode}" == "enable" ]; then
        echo -n "CREATING...."
        if [[ "$(register_scalable_target ${table_name} ${scaleable_read_dimension} ${role_arn} ${min_tput} ${max_tput})" == "true" ]]; then
          echo "DONE"
        else
          echo "ERROR"
        fi
      else
        echo "NOT FOUND"
      fi
    fi

    echo -n "checking for scalable target (write throughput) for ${table_name}..."
    if [[ "$(scalable_target_exists ${table_name} ${scaleable_write_dimension})" == "true" ]]; then
      if [ "${mode}" == "disable" ]; then
        echo -n "DISABLING...."
        if [[ "$(deregister_scalable_target ${table_name} ${scaleable_write_dimension})" == "true" ]]; then
          echo "DONE"
        else
          echo "ERROR"
        fi
      else
        echo "FOUND"
      fi
    else
      if [ "${mode}" == "enable" ]; then
        echo -n "CREATING..."
        if [[ "$(register_scalable_target ${table_name} ${scaleable_write_dimension} ${role_arn} ${min_tput} ${max_tput})" == "true" ]]; then
          echo "DONE"
        else
          echo "ERROR"
        fi
      else
        echo "NOT FOUND"
      fi
    fi

    # Once we have the scalable targets, we can see if the scaling policies exist
    echo -n "checking for scaling policy (read throughput) for ${table_name}..."
    if [[ "$(scaling_policy_exists ${table_name} ${read_metric_type})" == "true" ]]; then
      if [ "${mode}" == "disable" ]; then
        echo -n "DISABLING...."
        if [[ "$(delete_scaling_policy ${table_name} ${read_metric_type} ${scaleable_read_dimension})" == "true" ]]; then
          echo "DONE"
        else
          echo "ERROR"
        fi
      else
        echo "FOUND"
      fi
    else
      if [ "${mode}" == "enable" ]; then
        echo -n "CREATING..."
        if [[ "$(put_scaling_policy ${table_name} ${read_metric_type} ${scaleable_read_dimension})" == "true" ]]; then
          echo "DONE"
        else
          echo "ERROR"
        fi
      else
        echo "NOT FOUND"
      fi
    fi

    # Once we have the scalable targets, we can see if the scaling policies exist
    echo -n "checking for scaling policy (write throughput) for ${table_name}..."
    if [[ "$(scaling_policy_exists ${table_name} ${write_metric_type})" == "true" ]]; then
      if [ "${mode}" == "disable" ]; then
        echo -n "DISABLING...."
        if [[ "$(delete_scaling_policy ${table_name} ${write_metric_type} ${scaleable_write_dimension})" == "true" ]]; then
          echo "DONE"
        else
          echo "ERROR"
        fi
      else
        echo "FOUND"
      fi
    else
      if [ "${mode}" == "enable" ]; then
        echo -n "CREATING..."
        if [[ "$(put_scaling_policy ${table_name} ${write_metric_type} ${scaleable_write_dimension})" == "true" ]]; then
          echo "DONE"
        else
          echo "ERROR"
        fi
      else
        echo "NOT FOUND"
      fi
    fi
  done
else
  echo "DynamoDB autoscaling role not found - create one. See https://goo.gl/JVmkGS"
fi
