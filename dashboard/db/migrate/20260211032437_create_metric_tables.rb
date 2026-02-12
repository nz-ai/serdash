# frozen_string_literal: true

class CreateMetricTables < ActiveRecord::Migration[7.1]
  def change
    create_table :disk_samples do |t|
      t.references :server, null: false, foreign_key: true
      t.datetime :sampled_at, null: false
      t.string :mount_point, null: false
      t.bigint :total_bytes
      t.bigint :free_bytes

      t.timestamps
    end
    add_index :disk_samples, [:server_id, :sampled_at]

    create_table :memory_samples do |t|
      t.references :server, null: false, foreign_key: true
      t.datetime :sampled_at, null: false
      t.bigint :total_bytes
      t.bigint :used_bytes
      t.bigint :free_bytes

      t.timestamps
    end
    add_index :memory_samples, [:server_id, :sampled_at]

    create_table :cpu_samples do |t|
      t.references :server, null: false, foreign_key: true
      t.datetime :sampled_at, null: false
      t.float :usage_percent
      t.float :temperature_celsius

      t.timestamps
    end
    add_index :cpu_samples, [:server_id, :sampled_at]

    create_table :network_interface_samples do |t|
      t.references :server, null: false, foreign_key: true
      t.datetime :sampled_at, null: false
      t.string :interface, null: false
      t.string :status
      t.jsonb :ip_addresses, default: []

      t.timestamps
    end
    add_index :network_interface_samples, [:server_id, :sampled_at]

    create_table :listening_port_samples do |t|
      t.references :server, null: false, foreign_key: true
      t.datetime :sampled_at, null: false
      t.string :protocol, null: false
      t.integer :port, null: false
      t.string :process

      t.timestamps
    end
    add_index :listening_port_samples, [:server_id, :sampled_at]

    create_table :connection_samples do |t|
      t.references :server, null: false, foreign_key: true
      t.datetime :sampled_at, null: false
      t.string :local_addr
      t.string :remote_addr
      t.string :state

      t.timestamps
    end
    add_index :connection_samples, [:server_id, :sampled_at]
  end
end
