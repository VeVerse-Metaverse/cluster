#!/usr/bin/env bash

# Create IAM policy
aws iam create-policy --policy-name deckhouse-iam-policy --policy-document file://00-deckhouse-iam-policy.json