#!/usr/local/bin/bash -x

#get list of tables by prefix
#for each table
#  see if we have a scalable target
#    if not, register one
#  see if we have a scaling policy
#    if not, register one
declare -a table_array

usage()
{
  echo "Usage: $0 [-a <role name>] [-p <table prefix>]" 1>&2
  exit 1
}

# Sees if a role exists in IAM
role_exists()
{
  role_name=$1
  role_arn=$(aws iam get-role --role-name ${role_name} --query "Role.Arn" --output text)

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

  table_list_str=$(aws dynamodb list-tables --query "TableNames[?starts_with(@,\`${prefix}\`) == \`true\`]" --output text)
  IFS='	' read -r -a table_array <<< "$table_list_str"
}

scalable_target_exists()
{
  echo "checking if scalable target exists"
}

register_scalable_target()
{
  echo "registering scalable target"
}

scaling_policy_exists()
{
  echo "checking if policy exists"
}

register_scaling_policy()
{
  echo "registering policy"
}

# ======================
# ====== MAIN
# ======================

while getopts ":r:p:" o; do
    case "${o}" in
        r)
            rolename=${OPTARG}
            ;;
        p)
            prefix=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${rolename}" ] || [ -z "${prefix}" ]; then
    usage
fi

# Main logic
role_arn=$(role_exists ${rolename})

if [[ "${role_arn}" != "false" ]]; then
  echo "DynamoDB autoscaling role found OK"

  list_tables_with_filter ${prefix}

  for table_name in "${table_array[@]}"
  do
    echo "table found $table_name"
  done

else
  echo "DynamoDB autoscaling role not found - create one. See https://goo.gl/JVmkGS"
fi
