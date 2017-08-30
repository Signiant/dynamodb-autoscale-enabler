#!/usr/local/bin/bash -x

#get list of tables by prefix
#for each table
#  see if we have a scalable target
#    if not, register one
#  see if we have a scaling policy
#    if not, register one


usage()
{
  echo "Usage: $0 [-a <role name>] [-p <table prefix>]" 1>&2
  exit 1
}

role_exists()
{
  role_name=$1
  role_arn=$(aws iam get-role --role-name ${role_name} --query "Role.Arn" --output text)

  if [ -z "${role_arn}" ]; then
    echo "false"
  else
    echo "true"
  fi
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
if [[ "$(role_exists ${rolename})" == "true" ]]; then
  echo "DynamoDB autoscaling role found OK"
else
  echo "DynamoDB autoscaling role not found - create one. See https://goo.gl/JVmkGS"
fi
