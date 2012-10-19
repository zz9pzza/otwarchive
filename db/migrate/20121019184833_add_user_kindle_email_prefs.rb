class AddUserKindleEmailPrefs < ActiveRecord::Migration
  def self.up
    add_column :users, :download_email_address, :string
    add_column :users, :download_prefered_format, :string
    add_column :users, :download_activation_key, :string
  end

  def self.down
    remove_column :users, :download_email_address
    remove_column :users, :download_prefered_format
    remove_column :users, :download_activation_key
  end
end
