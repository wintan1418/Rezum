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
    controller_name == controller ? "border-b-2 border-blue-600 text-blue-600" : "text-gray-600 hover:text-gray-900"
  end
end
