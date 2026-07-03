# variable_values.tfvars

################################################################################
# SNOWFLAKE CONFIGURATION FILE
################################################################################
# All configuration values for Snowflake infrastructure, organized by resource type.
#
# Sections:
# 1.   Environments
# 2.   Account Parameters
# 3.   Account Overseeing Role
# 4.   Session Policies
# 5.   Network Rules
# 5A.  Authentication Policies
# 6.   Network Policies
# 7.   Users
# 8.   Permission Sets
# 9.   Databases & Schemas
# 10.  Integration Roles
# 11.  Custom Roles
# 12.  Warehouses
# 13.  Resource Monitors
# 14.  Storage Integrations
# 14.1 Notification Integrations
# 15.  Stages
################################################################################

################################################################################
# SENSITIVE VARIABLES
# In production, provide these via TF_VAR_* environment variables or Azure DevOps Variable Groups.
################################################################################
snowflake_user                   = "TERRAFORM_SVC"
snowflake_private_key_path       = "~/.ssh/snowflake_tf_snow_key.p8"

#========================================================================
# ROLES
#========================================================================
account_roles = {
  "TRANSFORMER_ROLE" = {
    comment = "Role for running dbt/data transformation jobs"
  }
  "REPORTING_ROLE" = {
    comment = "Role for BI tools and analysts to consume report data"
  }
}

#========================================================================
# ROLE HIERARCHY GRANTS
#========================================================================
role_to_role_grants = [
  { role = "TRANSFORMER_ROLE", parent_role = "SYSADMIN" },
  { role = "REPORTING_ROLE",   parent_role = "SYSADMIN" }
]

#========================================================================
# DATABASES
#========================================================================
databases = {
  "RAW_DB" = {
    comment                     = "Data Lake Landing Zone"
    data_retention_time_in_days = 7 
  }
  "ANALYTICS_DB" = {
    comment                     = "Production Data Warehouse"
    data_retention_time_in_days = 1
    is_transient                = true
  }
}

#========================================================================
# SCHEMAS 
#========================================================================
schemas = {
  "CITI_BIKE"      = { database = "RAW_DB", data_retention_time_in_days = 14 }
  "WEATHER_NYC"    = { database = "RAW_DB" }
  "STRIPE_BILLING" = { database = "RAW_DB" }

  "STAGING"   = { database = "ANALYTICS_DB", with_managed_access = true }
  "MARTS"     = { database = "ANALYTICS_DB", with_managed_access = true }
  "REPORTING" = { database = "ANALYTICS_DB" }
}


#========================================================================
# PRIVILEGES
#========================================================================
database_privileges = [
  { database = "RAW_DB", role = "TRANSFORMER_ROLE", privilege = "USAGE" },
  { database = "ANALYTICS_DB", role = "REPORTING_ROLE", privilege = "USAGE" }
]

schema_privileges = [
  { database = "RAW_DB", schema = "WEATHER_NYC", role = "TRANSFORMER_ROLE", privilege = "USAGE" },
  { database = "ANALYTICS_DB", schema = "MARTS", role = "REPORTING_ROLE", privilege = "USAGE" }
]