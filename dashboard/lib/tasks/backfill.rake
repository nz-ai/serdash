# frozen_string_literal: true

namespace :serdash do
  desc "Backfill test server with representative metrics for last 30 days (dev only)"
  task backfill: :environment do
    unless Rails.env.development?
      puts "Skipping backfill (only runs in development)"
      next
    end

    server = Server.find_by(hostname: "test-server")
    unless server
      puts "Test server not found. Run db:seed first."
      next
    end

    server.update!(status: "active", last_seen_at: Time.current) if server.status != "active"
    Serdash::Backfill.run(server: server)
    puts "Backfill complete."
  end
end
