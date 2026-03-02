class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "ReZum <wintan1418@gmail.com>")
  layout "mailer"
end
