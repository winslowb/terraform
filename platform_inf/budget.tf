variable "budget_alert_email" {
  type        = string
  description = "Email for budget notifications"
}

resource "aws_budgets_budget" "monthly_cost" {
  name              = "Chet-Monthly-Spend"
  budget_type       = "COST"
  limit_amount      = "20"
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  cost_types {
    include_credit             = true
    include_discount           = true
    include_other_subscription = true
    include_recurring          = true
    include_refund             = true
    include_subscription       = true
    include_support            = true
    include_tax                = true
    include_upfront            = true
    use_blended                = false
  }

  # 85% actual
  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "ACTUAL"
    threshold                  = 85
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  # 100% actual
  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "ACTUAL"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  # 120% forecast (oops safety)
  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "FORECASTED"
    threshold                  = 120
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = [var.budget_alert_email]
  }
}
