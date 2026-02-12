class CreateServers < ActiveRecord::Migration[7.1]
  def change
    create_table :servers do |t|
      t.string :hostname
      t.string :ip
      t.text :agent_public_key
      t.string :status, default: "pending_registration", null: false
      t.datetime :last_seen_at

      t.timestamps
    end
  end
end
