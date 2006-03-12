#!/usr/local/bin/ruby
# from ezmobius
#server
require 'rubygems'
require 'drb/drb'
require_gem 'activerecord'
 
ActiveRecord::Base.establish_connection(
    :adapter  => "mysql",
    :username => "root",
    :host     => "localhost",
    :password => "xxxxxxx",
    :database => "remote_drb"
)
 
ActiveRecord::Schema.define(:version => 1) do
  create_table "remote_records", :force => true do |t|
    t.column :title, :string
    t.column :desc, :string
  end
end
 
class RemoteRecord < ActiveRecord::Base
   include DRb::DRbUndumped
end
 
DRb.start_service("druby://127.0.0.1:3500", RemoteRecord)
puts DRb.uri
DRb.thread.join
 
__END__
#client run in irb
require 'rubygems'
require 'drb/drb'
require_gem 'activerecord'
 
DRb.start_service
RemoteRecord = DRbObject.new(nil, 'druby://127.0.0.1:3500')
[
  ['foo','bar'],
  ['qux', 'baz'],
  ['nik', 'nuk']
].each do |record|
   RemoteRecord.create :title => record[0], :desc => record[1]
end
 
test = RemoteRecord.find :all
test.each{|o| p "#{o.title} : #{o.desc}" }
 
# results in:
#  "foo : bar"
#  "qux : baz"
#  "nik : nuk"