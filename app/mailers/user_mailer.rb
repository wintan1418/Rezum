class UserMailer < ApplicationMailer
  def welcome_email(user)
    @user = user
    mail(to: @user.email, subject: "Welcome to RezumFit — Let's optimize your resume!")
  end

  def trial_ending_reminder(user, days_remaining:)
    @user = user
    @days_remaining = days_remaining
    mail(to: @user.email, subject: "Your RezumFit trial ends in #{days_remaining} day#{'s' if days_remaining != 1}")
  end

  def credits_low(user)
    @user = user
    mail(to: @user.email, subject: "You have #{user.credits_remaining} credit left on RezumFit")
  end

  def credits_exhausted(user)
    @user = user
    mail(to: @user.email, subject: "You're out of credits — Upgrade to keep optimizing")
  end

  def weekly_tips(user, tip_number:)
    @user = user
    @tip_number = tip_number
    mail(to: @user.email, subject: weekly_tip_subject(tip_number))
  end

  def re_engagement(user, inactive_days:)
    @user = user
    @inactive_days = inactive_days
    mail(to: @user.email, subject: re_engagement_subject(inactive_days))
  end

  def payment_confirmation(user, payment)
    @user = user
    @payment = payment
    mail(to: @user.email, subject: "Payment confirmed — #{payment.credits_purchased} credits added to your account")
  end

  def subscription_activated(user, subscription)
    @user = user
    @subscription = subscription
    mail(to: @user.email, subject: "Your RezumFit subscription is now active!")
  end

  def subscription_cancelled(user, subscription)
    @user = user
    @subscription = subscription
    mail(to: @user.email, subject: "Your RezumFit subscription has been cancelled")
  end

  def rebrand_notification(user)
    @user = user
    mail(to: @user.email, subject: "We've got a new name! ReZum is now RezumFit")
  end

  def credits_gifted(user, credits:, reason: nil)
    @user = user
    @credits = credits
    @reason = reason.presence
    mail(to: @user.email, subject: "You've received #{credits} free credits on RezumFit!")
  end

  def hire_message_notification(hire_message)
    @hire_message = hire_message
    mail(to: ENV.fetch("MAILER_FROM", "wintan1418@gmail.com"), subject: "New Hire Message from #{hire_message.name}")
  end

  def follow_up_reminder(user, job_application)
    @user = user
    @job_application = job_application
    mail(to: @user.email, subject: "Follow up on your #{job_application.role} application at #{job_application.company_name}")
  end

  private

  def weekly_tip_subject(n)
    subjects = [
      "5 ATS hacks that actually work",
      "The #1 resume mistake (and how to fix it)",
      "How to write a cover letter that gets interviews",
      "Keywords that make recruiters notice your resume",
      "How top candidates optimize their job search"
    ]
    subjects[n % subjects.length]
  end

  def re_engagement_subject(days)
    case days
    when 7..13 then "We miss you! Your resume toolkit is waiting"
    when 14..29 then "Your job search assistant is ready when you are"
    else "Come back and land your dream job with RezumFit"
    end
  end
end
