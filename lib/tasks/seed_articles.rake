namespace :articles do
  desc "Seed blog articles (safe to run multiple times - skips existing)"
  task seed: :environment do
    require Rails.root.join("db/seeds/articles")

    puts "Done! #{Article.count} total articles."
  end
end
