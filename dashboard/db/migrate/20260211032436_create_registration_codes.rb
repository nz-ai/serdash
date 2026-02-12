class CreateRegistrationCodes < ActiveRecord::Migration[7.1]
  def change
    create_table :registration_codes do |t|
      t.references :server, null: true, foreign_key: true
      t.string :code, null: false
      t.datetime :expires_at, null: false

      t.timestamps
    end
    add_index :registration_codes, :code, unique: true
  end
end
