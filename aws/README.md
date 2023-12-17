# Cloud Provider - AWS

## Prerequisites

You need to be sure that you have the quotas needed to create resources as well as cloud access credentials.

### Preparing the AWS account

> Note: You can skip this step if you already set up the Deckhouse IAM user and the policy (e.g. if you rebuilding the cluster from scratch on the
> same AWS account as was used previously).

To create resources in the AWS cloud, you need to create a policy and an IAM user with required permissions and access.

> Note: You can find shell scripts and a JSON configuration files in the aws directory.

#### 00: Create policy:

```shell 
aws iam create-policy --policy-name deckhouse-iam-policy --policy-document 00-deckhouse-iam-policy.json
```

The command will return JSON with policy metadata.

#### 01: Create IAM user:

```shell
aws iam create-user --user-name deckhouse
```

The command will return JSON with user metadata.

#### 02: Create access key for the IAM user:

> Note: You will need to store the access key ID and secret key in a safe place. You will not be able to view the secret key again after this step.

```shell
aws iam create-access-key --user-name deckhouse
```

The command will return JSON with AccessKeyId and SecretAccessKey, these values must go to the deckhouse installation configuration file.

#### 03: Attach the policy to the IAM user:

```shell
aws iam attach-user-policy --user-name deckhouse \
 --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query "Account" --output text):policy/deckhouse-iam-policy
```
