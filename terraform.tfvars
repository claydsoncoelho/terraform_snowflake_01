# variable_values.tfvars

################################################################################
# SNOWFLAKE CONFIGURATION FILE
################################################################################

################################################################################
# SENSITIVE VARIABLES
# In production, provide these via TF_VAR_* environment variables or Azure DevOps Variable Groups.
################################################################################
organization_name           = "egtaggb"
account_name                = "ik00397"
snowflake_user              = "TERRAFORM_SVC"
snowflake_private_key_path  = "~/.ssh/snowflake_tf_private_key.pem"
