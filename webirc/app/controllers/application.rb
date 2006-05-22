# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base
  
#   def rescue_action(exception)
#     case exception
#       when DRb::DRbConnError
#         drb_error(exception)
#       else
#         super(exception)
#     end
#   end

  def rescue_action_in_public(exception)
    case exception
      when DRb::DRbConnError
        drb_error(exception)
      else
        super(exception)
    end
  end
  
  private
  
  def drb_error(e)
    log_error e
    render_text '<html><body><h1>Application error (Rails)</h1><p>Could not connect to DRb back-end service</p></body></html>'
  end

end