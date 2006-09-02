defaults = {'host' => 'localhost', 
            'port' => '22222',
            'environment' => 'development',
            'databse_yml' => 'config/database.yml',
            'load_rails'  => true}
begin
  BACKGROUNDRB_CONFIG = defaults.merge(YAML.load(ERB.new(IO.read("#{RAILS_ROOT}/config/backgroundrb.yml")).result))
rescue
  BACKGROUNDRB_CONFIG = defaults
end

# Backgroundrb
require "drb"
DRb.start_service

MiddleMan = DRbObject.new(nil, "druby://#{BACKGROUNDRB_CONFIG['host']}:#{BACKGROUNDRB_CONFIG['port']}")
class << MiddleMan
  def cache_as(named_key, data=nil)
    if data
      cache(named_key, Marshal.dump(data))
      data
    elsif block_given?
      res = yield
      cache(named_key, Marshal.dump(res))
      res
    end  
  end

  def cache_get(named_key)
    if self[named_key]
      return Marshal.load(self[named_key])
    elsif block_given?
      self[named_key] = Marshal.dump(yield)
      return Marshal.load(self[named_key])
    else
      return nil    
    end     
  end
end