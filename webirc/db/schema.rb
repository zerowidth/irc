# This file is autogenerated. Instead of editing this file, please use the
# migrations feature of ActiveRecord to incrementally modify your database, and
# then regenerate this schema definition.

ActiveRecord::Schema.define(:version => 2) do

  create_table "connection_prefs", :force => true do |t|
    t.column "user_id",  :integer,               :null => false
    t.column "nick",     :string,  :limit => 40, :null => false
    t.column "realname", :string,  :limit => 40, :null => false
    t.column "server",   :string,  :limit => 40, :null => false
    t.column "port",     :integer,               :null => false
    t.column "channel",  :string,  :limit => 80
  end

  create_table "users", :force => true do |t|
    t.column "login",            :string,   :limit => 40
    t.column "email",            :string,   :limit => 100
    t.column "crypted_password", :string,   :limit => 40
    t.column "salt",             :string,   :limit => 40
    t.column "created_at",       :datetime
    t.column "updated_at",       :datetime
  end

end
