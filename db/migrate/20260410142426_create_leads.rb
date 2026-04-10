class CreateLeads < ActiveRecord::Migration[7.2]
  def change
    create_table :leads do |t|
      t.string :email, null: false
      t.string :source, default: "ats_checker"
      t.string :ip_address
      t.timestamps
    end
    add_index :leads, :email
    add_index :leads, :source
  end
end
