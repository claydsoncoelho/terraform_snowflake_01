# Links

https://www.snowflake.com/en/developers/guides/terraforming-snowflake/#0


# Snowflake

egtaggb.ik00397


# Steps

## Create an RSA key for Authentication

This creates the private and public keys we use to authenticate the service account we will use for Terraform.

```
$ cd ~/.ssh
$ openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out snowflake_tf_snow_key.p8 -nocrypt
$ openssl rsa -in snowflake_tf_snow_key.p8 -pubout -out snowflake_tf_snow_key.pub
```
## Create the User in Snowflake

```
USE ROLE ACCOUNTADMIN;

CREATE USER TERRAFORM_SVC
    TYPE = SERVICE
    COMMENT = "Service user for Terraforming Snowflake"
    RSA_PUBLIC_KEY = "<RSA_PUBLIC_KEY_HERE>";

GRANT ROLE SYSADMIN TO USER TERRAFORM_SVC;
GRANT ROLE SECURITYADMIN TO USER TERRAFORM_SVC;
```

## Preparing the Project to Run

```
terraform init
```

## Plan

```
terraform plan
```

## Execute

```
terraform apply
```

or 

```
terraform plan -var-file=variables_values_dev.tfvars
```

# Directory Structure
```
├── main.tf                     # Root configuration (calls modules and sets up provider)
├── variables.tf                # Root input variables
├── variable_values.tfvars # (Optional) Local variable values (do not commit secrets)
└── modules/
    ├── databases/
    ├── schemas/
    ├── security/
    └── roles/              
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```