require "#{RAILS_ROOT}/script/backgroundrb/lib/backgroundrb.rb"
# module BackgrounDRb
#   class MiddleMan
#     @@jobs ||= {}
#     def jobs
#       @@jobs
#     end
#   end
# end
MiddleMan = BackgrounDRb::MiddleMan.new # assign it to the global namespace