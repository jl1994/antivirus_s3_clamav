#!/bin/bash
BUCKET_NAME=$1
aws s3 rm s3://$BUCKET_NAME --recursive