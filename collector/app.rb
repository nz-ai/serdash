# frozen_string_literal: true

require "sinatra"
require "json"
require "pg"
require "jwt"
require "jwt/eddsa"
require "ed25519"
require "securerandom"
require "open3"

# Allow requests from localhost (nginx forwards with Host: localhost)
# and Docker internal names when accessed directly
set :protection, except: [:host_authorization]

def db
  @db ||= PG.connect(ENV["DATABASE_URL"] || "postgres://serdash:serdash_secret@localhost:15432/serdash")
end

def pem_to_ed25519_verify_key(pem)
  # Extract raw 32-byte public key from PEM (SubjectPublicKeyInfo)
  openssl_key = OpenSSL::PKey.read(pem)
  raw = openssl_key.public_to_der
  # Ed25519 OID 1.3.101.112, key is last 32 bytes
  Ed25519::VerifyKey.new(raw[-32, 32])
end

# GET /health - liveness check
get "/health" do
  content_type :json
  { status: "ok" }.to_json
end

# GET /v1/discover?subnet=192.168.1.0/24 - network discovery
get "/v1/discover" do
  content_type :json
  subnet = (params["subnet"] || "").to_s.strip
  subnet = ENV["DISCOVERY_SUBNET"].to_s.strip if subnet.empty?
  halt 400, { error: "Missing subnet. Use ?subnet=192.168.1.0/24 or set DISCOVERY_SUBNET" }.to_json if subnet.to_s.strip.empty?

  hosts = run_discovery(subnet)
  { success: true, subnet: subnet, hosts: hosts }.to_json
rescue StandardError => e
  halt 500, { error: "Discovery failed: #{e.message}" }.to_json
end

def run_discovery(subnet)
  # Prefer nmap (faster, more info)
  if system("which nmap >/dev/null 2>&1")
    discover_via_nmap(subnet)
  else
    discover_via_ping(subnet)
  end
end

def discover_via_nmap(subnet)
  out, err, status = Open3.capture3("nmap", "-sn", "-oG", "-", subnet, timeout: 120)
  return [] unless status.success?

  hosts = []
  out.each_line do |line|
    next unless line =~ /^Host: (\d+\.\d+\.\d+\.\d+)/

    ip = Regexp.last_match(1)
    hostname = line[/\(([^)]+)\)/, 1]
    mac = line[/MAC Address: ([0-9A-Fa-f:]+)/, 1]
    hosts << { ip: ip, hostname: hostname, mac: mac }.compact
  end
  hosts
end

def discover_via_ping(subnet)
  # Parse CIDR and ping each IP (slow; limited to /24)
  base, prefix = subnet.split("/")
  prefix = prefix&.to_i || 24
  return [] if prefix < 16 || prefix > 24

  octets = base.split(".").map(&:to_i)
  return [] unless octets.size == 4

  hosts = []
  (1..254).each do |last|
    ip = "#{octets[0]}.#{octets[1]}.#{octets[2]}.#{last}"
    ok = system("ping", "-c", "1", "-W", "1", ip, out: File::NULL, err: File::NULL)
    hosts << { ip: ip } if ok
  end
  hosts
end

# POST /v1/register - agent registration with code + public key
post "/v1/register" do
  content_type :json
  body = JSON.parse(request.body.read)
  code = body["code"]&.to_s&.strip
  public_key_pem = body["public_key"]&.to_s
  hostname = body["hostname"]&.to_s&.strip

  halt 400, { error: "Missing code or public_key" }.to_json if code.to_s.empty? || public_key_pem.to_s.empty?

  result = db.transaction do |conn|
    row = conn.exec_params(
      "SELECT id, server_id FROM registration_codes WHERE code = $1 AND expires_at > NOW() AND server_id IS NOT NULL",
      [code]
    ).first

    halt 404, { error: "Invalid or expired registration code" }.to_json unless row

    server_id = row["server_id"].to_i
    conn.exec_params(
      "UPDATE servers SET agent_public_key = $1, hostname = $2, status = 'active', last_seen_at = NOW(), updated_at = NOW() WHERE id = $3",
      [public_key_pem.strip, (hostname.to_s.strip.empty? ? "server-#{server_id}" : hostname.strip), server_id]
    )
    conn.exec_params("DELETE FROM registration_codes WHERE code = $1", [code])
    { agent_id: server_id }
  end

  { success: true, agent_id: result[:agent_id] }.to_json
rescue JSON::ParserError
  halt 400, { error: "Invalid JSON" }.to_json
end

# POST /v1/metrics - receive metrics from authenticated agent
post "/v1/metrics" do
  content_type :json
  auth = request.env["HTTP_AUTHORIZATION"]
  halt 401, { error: "Missing Authorization header" }.to_json unless auth

  token = auth.sub(/^Bearer\s+/i, "").strip
  halt 401, { error: "Invalid token" }.to_json if token.empty?

  body = JSON.parse(request.body.read)

  # Decode JWT without verification to get agent_id (we don't know which key yet)
  payload = JWT.decode(token, nil, false).first
  agent_id = payload["agent_id"]&.to_i
  halt 401, { error: "Invalid token: missing agent_id" }.to_json unless agent_id && agent_id.positive?

  # Load server and verify JWT with its public key
  server_row = db.exec_params(
    "SELECT id, agent_public_key FROM servers WHERE id = $1 AND status = 'active'",
    [agent_id]
  ).first

  halt 401, { error: "Unknown agent" }.to_json unless server_row
  halt 401, { error: "Agent not registered" }.to_json if server_row["agent_public_key"].to_s.empty?

  public_key_pem = server_row["agent_public_key"]
  public_key = pem_to_ed25519_verify_key(public_key_pem)
  begin
    JWT.decode(token, public_key, true, { algorithm: "EdDSA" })
  rescue JWT::DecodeError => e
    halt 401, { error: "Invalid signature: #{e.message}" }.to_json
  end

  # Store metrics
  store_metrics(agent_id, body)

  # Update last_seen_at
  db.exec_params("UPDATE servers SET last_seen_at = NOW(), updated_at = NOW() WHERE id = $1", [agent_id])

  { success: true }.to_json
rescue JSON::ParserError
  halt 400, { error: "Invalid JSON" }.to_json
end

def store_metrics(server_id, data)
  sampled_at = (data["sampled_at"] && Time.parse(data["sampled_at"])) || Time.current

  # Disk
  Array(data["disk"]).each do |d|
    next if d["mount_point"].to_s.empty?

    db.exec_params(
      "INSERT INTO disk_samples (server_id, sampled_at, mount_point, total_bytes, free_bytes, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, NOW(), NOW())",
      [server_id, sampled_at, d["mount_point"], d["total_bytes"]&.to_i, d["free_bytes"]&.to_i]
    )
  end

  # Memory
  if data["memory"]
    m = data["memory"]
    db.exec_params(
      "INSERT INTO memory_samples (server_id, sampled_at, total_bytes, used_bytes, free_bytes, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, NOW(), NOW())",
      [server_id, sampled_at, m["total_bytes"]&.to_i, m["used_bytes"]&.to_i, m["free_bytes"]&.to_i]
    )
  end

  # CPU
  if data["cpu"]
    c = data["cpu"]
    db.exec_params(
      "INSERT INTO cpu_samples (server_id, sampled_at, usage_percent, temperature_celsius, created_at, updated_at) VALUES ($1, $2, $3, $4, NOW(), NOW())",
      [server_id, sampled_at, c["usage_percent"]&.to_f, c["temperature_celsius"]&.to_f]
    )
  end

  # Network interfaces
  Array(data["network_interfaces"]).each do |ni|
    next if ni["interface"].to_s.empty?

    db.exec_params(
      "INSERT INTO network_interface_samples (server_id, sampled_at, interface, status, ip_addresses, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, NOW(), NOW())",
      [server_id, sampled_at, ni["interface"], ni["status"], (ni["ip_addresses"] || []).to_json]
    )
  end

  # Listening ports
  Array(data["listening_ports"]).each do |lp|
    db.exec_params(
      "INSERT INTO listening_port_samples (server_id, sampled_at, protocol, port, process, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, NOW(), NOW())",
      [server_id, sampled_at, lp["protocol"] || "tcp", lp["port"]&.to_i, lp["process"]]
    )
  end

  # Connections
  Array(data["connections"]).each do |conn|
    db.exec_params(
      "INSERT INTO connection_samples (server_id, sampled_at, local_addr, remote_addr, state, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, NOW(), NOW())",
      [server_id, sampled_at, conn["local_addr"], conn["remote_addr"], conn["state"]]
    )
  end
rescue PG::Error => e
  puts "DB error storing metrics: #{e.message}"
  raise
end
