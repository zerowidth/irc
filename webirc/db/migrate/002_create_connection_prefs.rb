class CreateConnectionPrefs < ActiveRecord::Migration
  def self.up
    create_table :connection_prefs do |t|
      t.column :user_id,  :integer,               :null => false
      t.column :nick,     :string,  :limit => 40, :null => false
      t.column :realname, :string,  :limit => 40, :null => false
      t.column :server,   :string,  :limit => 40, :null => false
      t.column :port,     :integer,              :null => false
      t.column :channel,  :string,  :limit => 80, :null => true
    end
  end

  def self.down
    drop_table :connection_prefs
  end
end
