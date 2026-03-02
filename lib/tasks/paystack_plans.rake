namespace :paystack do
  desc "Create subscription plans on Paystack"
  task create_plans: :environment do
    plans = [
      {
        name: "Monthly Pro",
        amount: 29_000_00, # ₦29,000 in kobo
        interval: "monthly",
        description: "RezumFit Pro - Unlimited resume optimizations, cover letters, and more."
      },
      {
        name: "Annual Pro",
        amount: 290_000_00, # ₦290,000 in kobo (save 2 months)
        interval: "annually",
        description: "RezumFit Pro Annual - Unlimited usage, save 2 months vs monthly."
      },
      {
        name: "Monthly Premium",
        amount: 59_000_00, # ₦59,000 in kobo
        interval: "monthly",
        description: "RezumFit Premium - Everything in Pro plus priority support and advanced features."
      },
      {
        name: "Annual Premium",
        amount: 590_000_00, # ₦590,000 in kobo (save 2 months)
        interval: "annually",
        description: "RezumFit Premium Annual - Full access, save 2 months vs monthly."
      }
    ]

    puts "Creating Paystack plans..."
    puts "Using #{PaystackService.test_mode? ? 'TEST' : 'LIVE'} mode"
    puts ""

    plans.each do |plan|
      begin
        result = PaystackService.create_plan(
          name: plan[:name],
          amount: plan[:amount],
          interval: plan[:interval],
          description: plan[:description]
        )

        plan_code = result["plan_code"]
        puts "Created: #{plan[:name]}"
        puts "  Plan Code: #{plan_code}"
        puts "  Amount: ₦#{plan[:amount] / 100}"
        puts "  Interval: #{plan[:interval]}"
        puts ""

        # Map plan names to env var names
        env_key = case plan[:name]
        when "Monthly Pro" then "PAYSTACK_PLAN_MONTHLY_PRO"
        when "Annual Pro" then "PAYSTACK_PLAN_ANNUAL_PRO"
        when "Monthly Premium" then "PAYSTACK_PLAN_MONTHLY_PREMIUM"
        when "Annual Premium" then "PAYSTACK_PLAN_ANNUAL_PREMIUM"
        end

        puts "  Set this env var: #{env_key}=#{plan_code}"
        puts ""
      rescue PaystackService::PaystackError => e
        puts "FAILED: #{plan[:name]} - #{e.message}"
      end
    end

    puts "Done! Set the plan codes as environment variables on Hatchbox."
    puts ""
    puts "Env vars to set:"
    puts "  PAYSTACK_PLAN_MONTHLY_PRO=PLN_xxxxx"
    puts "  PAYSTACK_PLAN_ANNUAL_PRO=PLN_xxxxx"
    puts "  PAYSTACK_PLAN_MONTHLY_PREMIUM=PLN_xxxxx"
    puts "  PAYSTACK_PLAN_ANNUAL_PREMIUM=PLN_xxxxx"
  end

  desc "List existing Paystack plans"
  task list_plans: :environment do
    puts "Fetching Paystack plans..."
    puts "Mode: #{PaystackService.test_mode? ? 'TEST' : 'LIVE'}"
    puts ""

    plans = PaystackService.list_plans
    if plans.blank?
      puts "No plans found."
    else
      plans.each do |plan|
        puts "#{plan['name']}"
        puts "  Code: #{plan['plan_code']}"
        puts "  Amount: ₦#{plan['amount'] / 100}"
        puts "  Interval: #{plan['interval']}"
        puts "  Subscriptions: #{plan['subscriptions_count'] || 0}"
        puts ""
      end
    end
  end
end
