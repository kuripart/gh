provider "aws" {
  region = "us-east-1"  # Change this to your desired region
}

resource "random_id" "rng" {
  keepers = {
    first = "${timestamp()}"
  }
  byte_length = 8
}

# data "archive_file" "lambda" {
#   type        = "zip"
#   source_file = "execute.py"
#   output_path = "execute.zip"
# }

# resource "aws_lambda_function" "example" {
#   filename         = "execute.zip"
#   function_name    = "execute"
#   role             = aws_iam_role.lambda_role.arn
#   handler          = "execute.lambda_handler"
#   source_code_hash = data.archive_file.lambda.output_base64sha256
#   runtime          = "python3.8"
# }

# resource "aws_iam_role" "lambda_role" {
#   name = "lambda_role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "lambda.amazonaws.com"
#         }
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "lambda_attachment" {
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
#   role       = aws_iam_role.lambda_role.name
# }

# resource "aws_iam_policy" "s3_policy" {
#   name        = "s3_policy"
#   description = "Policy to allow Lambda to copy objects between S3 buckets"

#   policy = jsonencode({
#     # Enable: S3 CopyObject
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = [
#             "s3:ListBucket",
#             "s3:GetObject",
#             "s3:PutObject",
#         ]
#         Effect   = "Allow"
#         Resource = [
#           "arn:aws:s3:::pkuri-source-99898",
#           "arn:aws:s3:::pkuri-source-99898/*",
#           "arn:aws:s3:::pkuri-destination-80888",
#           "arn:aws:s3:::pkuri-destination-80888/*",
#         ]
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
#   policy_arn = aws_iam_policy.s3_policy.arn
#   role       = aws_iam_role.lambda_role.name
# }

# resource "aws_lambda_permission" "sns_permission" {
#   statement_id  = "AllowExecutionFromSNS"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.example.function_name
#   principal     = "sns.amazonaws.com"
#   source_arn    = aws_sns_topic.s3_events.arn
# }

resource "aws_sns_topic" "s3_events" {
  name   = "s3_events_topic"
  policy = data.aws_iam_policy_document.snsPublishDefault.json
}

resource "aws_s3_bucket" "bucket1" {
  bucket = "pkuri-source-99898"
}

resource "aws_s3_bucket" "bucket2" {
  bucket = "pkuri-destination-80888"
}

# resource "aws_s3_bucket" "bucket3" {
#   bucket = "pkuri-destination-${random_id.rng.hex}"
# }

data "archive_file" "rand_foo" {
  type        = "zip"
  source_file = "execute.py"
  output_path = "execute_${random_id.rng.hex}.zip"
}

data aws_iam_policy_document snsPublishDefault {
  # sns
  statement {
    effect = "Allow"
    actions = [
      "SNS:Publish"
    ]
    principals {
      identifiers = ["*"]
      type        = "AWS"
    }
    resources = [
      "arn:aws:sns:*:*:s3_events_topic"
    ]
    condition {
      test = "ArnLike"
      values = [
        "arn:aws:s3:::pkuri-source-99898"
      ]
      variable = "aws:SourceArn"
    }
  }
}

resource aws_s3_bucket_notification bucket_notification_default {
  bucket = "pkuri-source-99898"

  topic {
    topic_arn     = aws_sns_topic.s3_events.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "import/"
  }
}


# apply after lambda creation.
resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = aws_sns_topic.s3_events.arn
  protocol  = "lambda"
  endpoint  = "arn:aws:lambda:us-east-1:477312987951:function:jocasta_copyobject"
}
