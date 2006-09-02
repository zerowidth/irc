
class Tail
  include DRbUndumped

  attr_accessor :filename

  def initialize(options)
    @filename = options[:filename]
    p options
    @count = 0
    @logger = BACKGROUNDRB_LOGGER
  end

  def tail(lines=10)
     @logger.debug "tail call count = #{@count += 1}"
     result = `tail -#{lines} #{@filename}`
     result
  end
end
