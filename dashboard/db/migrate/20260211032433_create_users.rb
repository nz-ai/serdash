class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :provider
      t.string :uid

      t.timestamps
    end
    add_index :users, [:provider, :uid], unique: true, where: "provider IS NOT NULL"
    add_index :users, :email
  end
end
