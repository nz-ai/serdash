class CreateNetworkDevices < ActiveRecord::Migration[7.1]
  def change
    create_table :network_devices do |t|
      t.string :name
      t.string :device_type
      t.string :ip
      t.string :mac
      t.text :notes

      t.timestamps
    end
  end
end
