class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "ReZum <noreply@rezum.ai>")
  layout "mailer"
end
