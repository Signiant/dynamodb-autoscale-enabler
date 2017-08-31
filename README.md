# dynamodb-autoscale-controller
Enables or disables autoscaling on groups of AWS DynamoDB tables

# Purpose
DynamoDB autoscaling is a bit of a chore to enable or disable if you have a large number of tables.  This script automates adding or removing autoscaling from groups of tables

# autoscale-toggle.sh

Enables or disables autoscaling on a set of tables.  Usage:

`autoscale-toggle.sh [-m [enable|disable>] [-r <role name>] [-p <table prefix>] [-i <min throughput>] [-x <max throughput>]`

Where
* mode is one of enable or disable.  This enables or disables autoscaling for the tables
* role name is a pre-existing [DynamoDB autoscaling IAM role](http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/AutoScaling.CLI.html#AutoScaling.CLI.CreateServiceRole)
* table prefix is a prefix of tables to match.  All tables starting with this prefix will have autoscaling turned on
* min throughput is the minimum provisioned throughput to configure for read and write
* max throughput is the maximum provisioned throughput to configure for read and write
