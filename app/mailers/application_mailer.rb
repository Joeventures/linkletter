class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "Linkletter <no-reply@example.com>")
  layout "mailer"
end
