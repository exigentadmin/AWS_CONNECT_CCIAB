provider "aws" {
  region = "us-east-1"
}

data "aws_lex_bot" "order_flowers" {
  name    = aws_lex_bot.order_flowers_bot.name
  version = aws_lex_bot.order_flowers_bot.version
}

data "aws_lex_bot_alias" "order_flowers_prod" {
  bot_name = aws_lex_bot_alias.order_flowers_prod.bot_name
  name     = aws_lex_bot_alias.order_flowers_prod.name
}

data "aws_lex_intent" "order_flowers_intent" {
  name    = aws_lex_intent.order_flowers_intent.name
  version = aws_lex_intent.order_flowers_intent.version
}

data "aws_lex_slot_type" "flower_types" {
  name    = aws_lex_slot_type.flower_types.name
  version = aws_lex_slot_type.flower_types.version
}
locals {
  project     = "Call Center In A Box"
  description = "This is built for the Call Center In A Box Project"
} #aws connect instance
resource "aws_connect_instance" "AWS-CONNECT-CCIAB-DEMO" {
  # (resource arguments)
  identity_management_type       = "CONNECT_MANAGED"
  inbound_calls_enabled          = true
  instance_alias                 = "AWS-CONNECT-CCIAB-DEMO"
  multi_party_conference_enabled = true
  outbound_calls_enabled         = true
  contact_flow_logs_enabled      = true
}

data "archive_file" "lambda-zip" {
  type        = "zip"
  source_dir  = "lambda"
  output_path = "lambda.zip"
}

resource "aws_iam_role" "lambda-iam" {
  name               = "lambda-iam"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
    EOF
}

resource "aws_lambda_function" "lambda" {
  filename         = "lambda.zip"
  function_name    = "lambda_function"
  role             = aws_iam_role.lambda-iam.arn
  handler          = "lambda.lambda_handler"
  source_code_hash = data.archive_file.lambda-zip.output_base64sha256
  runtime          = "python3.8"
}

resource "aws_lexv2models_bot" "how_can_I_help_you" {
  name = "how_can_I_help_you"
  data_privacy {
    child_directed = "false"
  }
  idle_session_ttl_in_seconds = 60
  role_arn                    = "arn:aws:iam::433162890764:role/aws-service-role/lexv2.amazonaws.com/AWSServiceRoleForLexV2Bots_2UUS7NRDB"
}

#module to build lex bot
module "amazon_lexbot" {
  source = "./modules/amazon_lexbot"
}

# Amazon Lex Bot
resource "aws_lex_bot" "order_flowers_bot" {
  abort_statement {
    message {
      content      = "Sorry, I am not able to assist at this time"
      content_type = "PlainText"
    }
  }

  child_directed = false

  clarification_prompt {
    max_attempts = 2

    message {
      content      = "I didn't understand you, what would you like to do?"
      content_type = "PlainText"
    }
  }

  create_version              = false
  description                 = "Bot to order flowers on the behalf of a user"
  idle_session_ttl_in_seconds = 600

  intent {
    intent_name    = aws_lex_intent.order_flowers_intent.name
    intent_version = aws_lex_intent.order_flowers_intent.version
  }

  locale           = "en-US"
  name             = "OrderFlowers"
  process_behavior = "SAVE"
  voice_id         = "Salli"
}

resource "aws_lex_bot_alias" "order_flowers_prod" {
  bot_name    = aws_lex_bot.order_flowers_bot.name
  bot_version = aws_lex_bot.order_flowers_bot.version
  description = "Production Version of the OrderFlowers Bot."
  name        = "OrderFlowersProd"
}

resource "aws_lex_intent" "order_flowers_intent" {
  confirmation_prompt {
    max_attempts = 2

    message {
      content      = "Okay, your {FlowerType} will be ready for pickup by {PickupTime} on {PickupDate}.  Does this sound okay?"
      content_type = "PlainText"
    }

    message {
      content      = "Okay, your {FlowerType} will be ready for pickup by {PickupTime} on {PickupDate}, and will cost [Price] dollars.  Does this sound okay?"
      content_type = "PlainText"
    }
  }

  description = "Intent to order a bouquet of flowers for pick up"

  fulfillment_activity {
    type = "ReturnIntent"
  }

  name = "OrderFlowers"

  rejection_statement {
    message {
      content      = "Okay, I will not place your order."
      content_type = "PlainText"
    }
  }

  sample_utterances = [
    "I would like to pick up flowers",
    "I would like to order some flowers",
  ]

  slot {
    description = "The type of flowers to pick up"
    name        = "FlowerType"
    priority    = 1

    sample_utterances = [
      "I would like to order {FlowerType}",
    ]

    slot_constraint   = "Required"
    slot_type         = aws_lex_slot_type.flower_types.name
    slot_type_version = aws_lex_slot_type.flower_types.version

    value_elicitation_prompt {
      max_attempts = 2

      message {
        content      = "What type of flowers would you like to order?"
        content_type = "PlainText"
      }
    }
  }

  slot {
    description     = "The date to pick up the flowers"
    name            = "PickupDate"
    priority        = 2
    slot_constraint = "Required"
    slot_type       = "AMAZON.DATE"

    value_elicitation_prompt {
      max_attempts = 2

      message {
        content      = "What day do you want the {FlowerType} to be picked up?"
        content_type = "PlainText"
      }

      message {
        content      = "Pick up the {FlowerType} at {PickupTime} on what day?"
        content_type = "PlainText"
      }
    }
  }

  slot {
    description     = "The time to pick up the flowers"
    name            = "PickupTime"
    priority        = 3
    slot_constraint = "Required"
    slot_type       = "AMAZON.TIME"

    value_elicitation_prompt {
      max_attempts = 2

      message {
        content      = "At what time do you want the {FlowerType} to be picked up?"
        content_type = "PlainText"
      }

      message {
        content      = "Pick up the {FlowerType} at what time on {PickupDate}?"
        content_type = "PlainText"
      }
    }
  }
}

resource "aws_lex_slot_type" "flower_types" {
  create_version = true
  description    = "Types of flowers to order"

  enumeration_value {
    synonyms = [
      "Lirium",
      "Martagon",
    ]

    value = "lilies"
  }

  enumeration_value {
    synonyms = [
      "Eduardoregelia",
      "Podonix",
    ]

    value = "tulips"
  }

  enumeration_value { value = "roses" }

  name                     = "FlowerTypes"
  value_selection_strategy = "ORIGINAL_VALUE"
}

