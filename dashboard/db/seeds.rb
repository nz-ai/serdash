# frozen_string_literal: true

# Development: seed test server with long-lived registration code for e2e testing
if Rails.env.development?
  server = Server.find_or_create_by!(hostname: "test-server") do |s|
    s.status = "pending_registration"
    s.ip = "test-server"
  end
  server.update!(status: "pending_registration") if server.status != "pending_registration"

  code = RegistrationCode.find_or_initialize_by(code: "TESTDEV")
  code.server = server
  code.expires_at = 1.year.from_now
  code.save!

  puts "Seeded test server (id: #{server.id}) with registration code: TESTDEV (expires #{code.expires_at})"

  # Backfill representative metrics for charts (1/7/30 days)
  Serdash::Backfill.run(server: server)
  puts "Backfilled metrics for charts."
end
