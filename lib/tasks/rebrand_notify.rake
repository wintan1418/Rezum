namespace :rebrand do
  desc "Send rebrand notification email to all existing users"
  task notify_users: :environment do
    users = User.where.not(email_unsubscribed: true)
    total = users.count

    puts "Sending rebrand notification to #{total} users..."
    puts ""

    sent = 0
    failed = 0

    users.find_each do |user|
      UserMailer.rebrand_notification(user).deliver_later
      sent += 1
      print "\rSent: #{sent}/#{total}"
    rescue => e
      failed += 1
      puts "\nFailed for #{user.email}: #{e.message}"
    end

    puts ""
    puts ""
    puts "Done! Queued #{sent} emails, #{failed} failures."
    puts "Emails will be delivered via Sidekiq background jobs."
  end
end
