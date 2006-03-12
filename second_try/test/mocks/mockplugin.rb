require 'rubygems'
require 'flexmock'

class MockPlugin < FlexMock
  def initialize
    super('mock client')
  end
  
  # even new isn't defined for mocks!
  def new
    self
  end
  
  def teardown
  end

  def add_method(sym)
    instance_eval %{
      def #{sym}(arg)
        self.method_called(:#{sym})
      end
    }
  end
end
