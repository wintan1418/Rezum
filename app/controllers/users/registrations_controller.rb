class Users::RegistrationsController < Devise::RegistrationsController
  # POST /resource
  def create
    super do |resource|
      # Auto-confirm the user so they can sign in immediately
      if resource.persisted? && resource.respond_to?(:confirmed_at)
        resource.update_column(:confirmed_at, Time.current) if resource.confirmed_at.nil?
      end
    end
  end
end

