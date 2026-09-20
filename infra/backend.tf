# =============================================================================
# Remote state — S3 + DynamoDB locking
# Create these resources ONCE before running terraform init:
#
#   aws s3api create-bucket \
#     --bucket <your-project>-tfstate \
#     --region eu-west-1 \
#     --create-bucket-configuration LocationConstraint=eu-west-1
#
#   aws s3api put-bucket-versioning \
#     --bucket <your-project>-tfstate \
#     --versioning-configuration Status=Enabled
#
#   aws dynamodb create-table \
#     --table-name <your-project>-tflock \
#     --attribute-definitions AttributeName=LockID,AttributeType=S \
#     --key-schema AttributeName=LockID,KeyType=HASH \
#     --billing-mode PAY_PER_REQUEST \
#     --region eu-west-1
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "agentic-devops-tfstate" # change to your bucket name
    key            = "main/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "agentic-devops-tflock"
    encrypt        = true
  }
}
