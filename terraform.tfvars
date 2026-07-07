# variable_values.tfvars

################################################################################
# SNOWFLAKE CONFIGURATION FILE
################################################################################

################################################################################
# SENSITIVE VARIABLES
# In production, provide these via TF_VAR_* environment variables or Azure DevOps Variable Groups.
################################################################################
snowflake_user                   = "TERRAFORM_SVC"
snowflake_private_key_path       = "~/.ssh/snowflake_tf_private_key.pem"
