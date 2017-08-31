# dynamodb-autoscale-controller
Enables or disables autoscaling on groups of AWS DynamoDB tables

# Purpose
DynamoDB autoscaling is a bit of a chore to enable if you have a large number of tables.  These scripts automated adding or removing autoscaling from groups of tables

# autoscale-enable.sh

Enables autoscaling on a set of tables.  Usage:

`autoscale-enable.sh [-a <role name>] [-p <table prefix>] [-m <min throughput>] [-x <max throughput>]`

Where
* role name is a pre-existing [DynamoDB autoscaling IAM role](http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/AutoScaling.CLI.html#AutoScaling.CLI.CreateServiceRole)
* table prefix is a prefix of tables to match.  All tables starting with this prefix will have autoscaling turned on
* min throughput is the minimum provisioned throughput to configure for read and write
* max throughput is the maximum provisioned throughput to configure for read and write

# autoscale-disable.sh
Disables autoscaling on a set of tables.  Usage:

`autoscale-disable.sh [-p <table prefix>]`

where
* table prefix is a prefix of tables to match.  All tables starting with this prefix will have autoscaling turned off
