require 'irc/common'
require 'monitor'

module IRC
  
class PluginManager
  
  cattr_accessor :logger
  
  def self.register_plugin plugin
    @@plugins ||= []
    @@plugins << plugin
  end

  def self.instantiate_plugins(client)
    @@plugins ||= [] # just in case
    plugins = []
    @@plugins.uniq.each do |plugin_class|
      # instantiate each plugin
      plugin = plugin_class.new(client)
      plugins << plugin
    end
    plugins
  end
  
  def self.load_plugins_from_dir(plugin_dir)
    dir = File.expand_path(plugin_dir)
    logger.info "loading plugins from #{dir}:"
    Dir.foreach(dir) do |entry| # not recursive!
      filename = dir + '/' + entry
      if File.file?(filename) && entry =~ /\.rb$/ # only load ruby files
        begin 
          load(filename)
          logger.info "loaded #{filename}"
        rescue Exception => e # catch any exceptions, including syntax errors
          # all exceptions are caught so reloading plugins won't cause the 
          # client to crash.
          logger.warn "Plugin Manager caught exception #{e}"
          logger.warn e.backtrace[0]
        end
      end
    end
  end
  
end

end # module