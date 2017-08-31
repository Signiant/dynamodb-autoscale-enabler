# dynamodb-autoscale-controller
Enables or disables autoscaling on groups of AWS DynamoDB tables

# Purpose
DynamoDB autoscaling is a bit of a chore to enable or disable if you have a large number of tables.  This script automates adding or removing autoscaling from groups of tables

# Prerequsites
* You will need the [AWS CLI](https://aws.amazon.com/cli/) installed and configured with at least one [profile](http://docs.aws.amazon.com/cli/latest/userguide/cli-multiple-profiles.html)
* To have the tool use specific AWS credentials, use the [AWS_PROFILE](http://docs.aws.amazon.com/cli/latest/userguide/cli-environment.html) environment variable
* To have the tool use a region other than us-east-1, use the [AWS_DEFAULT_REGION](http://docs.aws.amazon.com/cli/latest/userguide/cli-environment.html) environment variable

# autoscale-toggle.sh

Enables or disables autoscaling on a set of tables.  Usage:

`autoscale-toggle.sh [-m <enable|disable>] [-r <role name>] [-p <table prefix>] [-i <min throughput>] [-x <max throughput>]`

ex: `autoscale-toggle.sh -m enable -r DynamoDBAutoscaleRole -p MYTABLES -i 5 -x 10000`

Where
* mode is one of enable or disable.  This enables or disables autoscaling for the tables
* role name is a pre-existing [DynamoDB autoscaling IAM role](http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/AutoScaling.CLI.html#AutoScaling.CLI.CreateServiceRole)
* table prefix is a prefix of tables to match.  All tables starting with this prefix will have autoscaling turned on
* min throughput is the minimum provisioned throughput to configure for read and write
* max throughput is the maximum provisioned throughput to configure for read and write
