# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_02_11_032437) do
  create_schema "_timescaledb_cache"
  create_schema "_timescaledb_catalog"
  create_schema "_timescaledb_config"
  create_schema "_timescaledb_functions"
  create_schema "_timescaledb_internal"
  create_schema "timescaledb_experimental"
  create_schema "timescaledb_information"

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "timescaledb"

  create_table "connection_samples", force: :cascade do |t|
    t.bigint "server_id", null: false
    t.datetime "sampled_at", null: false
    t.string "local_addr"
    t.string "remote_addr"
    t.string "state"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["server_id", "sampled_at"], name: "index_connection_samples_on_server_id_and_sampled_at"
    t.index ["server_id"], name: "index_connection_samples_on_server_id"
  end

  create_table "cpu_samples", force: :cascade do |t|
    t.bigint "server_id", null: false
    t.datetime "sampled_at", null: false
    t.float "usage_percent"
    t.float "temperature_celsius"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["server_id", "sampled_at"], name: "index_cpu_samples_on_server_id_and_sampled_at"
    t.index ["server_id"], name: "index_cpu_samples_on_server_id"
  end

  create_table "disk_samples", force: :cascade do |t|
    t.bigint "server_id", null: false
    t.datetime "sampled_at", null: false
    t.string "mount_point", null: false
    t.bigint "total_bytes"
    t.bigint "free_bytes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["server_id", "sampled_at"], name: "index_disk_samples_on_server_id_and_sampled_at"
    t.index ["server_id"], name: "index_disk_samples_on_server_id"
  end

  create_table "listening_port_samples", force: :cascade do |t|
    t.bigint "server_id", null: false
    t.datetime "sampled_at", null: false
    t.string "protocol", null: false
    t.integer "port", null: false
    t.string "process"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["server_id", "sampled_at"], name: "index_listening_port_samples_on_server_id_and_sampled_at"
    t.index ["server_id"], name: "index_listening_port_samples_on_server_id"
  end

  create_table "memory_samples", force: :cascade do |t|
    t.bigint "server_id", null: false
    t.datetime "sampled_at", null: false
    t.bigint "total_bytes"
    t.bigint "used_bytes"
    t.bigint "free_bytes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["server_id", "sampled_at"], name: "index_memory_samples_on_server_id_and_sampled_at"
    t.index ["server_id"], name: "index_memory_samples_on_server_id"
  end

  create_table "network_devices", force: :cascade do |t|
    t.string "name"
    t.string "device_type"
    t.string "ip"
    t.string "mac"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "network_interface_samples", force: :cascade do |t|
    t.bigint "server_id", null: false
    t.datetime "sampled_at", null: false
    t.string "interface", null: false
    t.string "status"
    t.jsonb "ip_addresses", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["server_id", "sampled_at"], name: "index_network_interface_samples_on_server_id_and_sampled_at"
    t.index ["server_id"], name: "index_network_interface_samples_on_server_id"
  end

  create_table "registration_codes", force: :cascade do |t|
    t.bigint "server_id"
    t.string "code", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_registration_codes_on_code", unique: true
    t.index ["server_id"], name: "index_registration_codes_on_server_id"
  end

  create_table "servers", force: :cascade do |t|
    t.string "hostname"
    t.string "ip"
    t.text "agent_public_key"
    t.string "status", default: "pending_registration", null: false
    t.datetime "last_seen_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "provider"
    t.string "uid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email"
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true, where: "(provider IS NOT NULL)"
  end

  add_foreign_key "connection_samples", "servers"
  add_foreign_key "cpu_samples", "servers"
  add_foreign_key "disk_samples", "servers"
  add_foreign_key "listening_port_samples", "servers"
  add_foreign_key "memory_samples", "servers"
  add_foreign_key "network_interface_samples", "servers"
  add_foreign_key "registration_codes", "servers"
end
