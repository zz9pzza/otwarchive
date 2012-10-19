class AddMobileDownloadsToPrefs < ActiveRecord::Migration
  def self.up
    add_column :preferences, :download_email_address, :string
    add_column :preferences, :download_preffered_format, :string
    add_column :preferences, :download_activation_key, :string
    add_column :preferences, :download_activated, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :preferences, :download_email_address
    remove_column :preferences, :download_preffered_format
    remove_column :preferences, :download_activation_key
    remove_column :preferences, :download_activated
  end
end
