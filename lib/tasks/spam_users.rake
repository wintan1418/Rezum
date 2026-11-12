# Find and remove sign-up spam: accounts whose names carry adverts or links,
# or that used a throwaway inbox, and never paid.
#   bin/rails users:spam_report          # list only
#   bin/rails users:purge_spam CONFIRM=1 # delete them
namespace :users do
  spam = lambda do
    User.where.not(id: Payment.select(:user_id)).where.not(id: Subscription.select(:user_id)).where(admin: [ false, nil ]).select do |user|
      names = [ user.first_name, user.last_name ].compact
      bad_name = names.any? { |n| n.length > 40 || !n.match?(User::NAME_FORMAT) || n.match?(User::LINK_LIKE) }
      bad_name || User.disposable_email?(user.email)
    end
  end

  desc "List likely spam sign-ups (no changes)"
  task spam_report: :environment do
    users = spam.call
    users.each { |u| puts "#{u.id}\t#{u.email}\t#{u.full_name.truncate(60)}\t#{u.created_at.to_date}" }
    puts "#{users.size} likely spam accounts"
  end

  desc "Delete likely spam sign-ups (set CONFIRM=1)"
  task purge_spam: :environment do
    users = spam.call
    abort "#{users.size} found. Run again with CONFIRM=1 to delete." unless ENV["CONFIRM"] == "1"
    users.each(&:destroy!)
    puts "Deleted #{users.size} spam accounts"
  end
end
