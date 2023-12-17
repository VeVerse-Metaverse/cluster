#!/usr/bin/env bash

# Create IAM user access key
aws iam attach-user-policy --user-name deckhouse --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query "Account" --output text):policy/deckhouse-iam-policy