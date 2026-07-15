namespace :storage do
  desc "Move existing local ActiveStorage blobs to Cloudinary"
  task migrate_to_cloudinary: :environment do
    from = ActiveStorage::Blob.services.fetch(:local)
    to   = ActiveStorage::Blob.services.fetch(:cloudinary)
    scope = ActiveStorage::Blob.where(service_name: "local")
    puts "#{scope.count} blob(s) to migrate"
    scope.find_each do |blob|
      unless from.exist?(blob.key)
        puts "SKIP (missing file): #{blob.filename}"
        next
      end
      from.open(blob.key, checksum: blob.checksum) do |file|
        to.upload(blob.key, file, checksum: blob.checksum, content_type: blob.content_type)
      end
      blob.update_columns(service_name: "cloudinary")
      puts "OK: #{blob.filename}"
    rescue => e
      puts "FAILED #{blob.filename}: #{e.message}"
    end
    puts "Done."
  end
end
