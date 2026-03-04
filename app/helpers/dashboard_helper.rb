module DashboardHelper
  def time_of_day_greeting
    hour = Time.current.hour
    case hour
    when 5..11 then "Good morning"
    when 12..16 then "Good afternoon"
    when 17..20 then "Good evening"
    else "Welcome back"
    end
  end

  def subscription_status_badge(user)
    if user.has_premium_subscription?
      { text: "Premium", classes: "bg-gradient-to-r from-purple-600 to-pink-600 text-white" }
    elsif user.has_active_subscription?
      { text: "Pro", classes: "bg-gradient-to-r from-blue-600 to-purple-600 text-white" }
    elsif user.trial_active?
      { text: "Trial", classes: "bg-blue-100 text-blue-800" }
    else
      { text: "#{user.credits_remaining} credits", classes: "bg-gray-100 text-gray-700" }
    end
  end

  def nav_active?(controller)
    active_for?(controller) ? "border-b-2 border-blue-600 text-blue-600" : "text-gray-600 hover:text-gray-900"
  end

  def mobile_nav_active?(controller)
    active_for?(controller) ? "bg-blue-50 text-blue-700 font-semibold" : "text-gray-700 hover:bg-gray-50"
  end

  private

  def active_for?(controller)
    return true if controller_name == controller

    # Group related controllers under their parent nav item
    case controller
    when "resumes"
      controller_name.in?(%w[resumes resume_wizard resume_builder])
    when "interview_preps"
      controller_name == "interview_preps"
    when "linkedin_optimizations"
      controller_name == "linkedin_optimizations"
    else
      false
    end
  end
end
