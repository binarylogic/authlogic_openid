# The only reason I am doing all of this non sense is becuase the openid_authentication requires that
# these constants be present. The only other alternative is to use an entire rails application for testing
# which is a little too overboard for this, I think.

RAILS_ROOT = ''

class ActionController < Authlogic::TestCase::MockController
  class Request < Authlogic::TestCase::MockRequest
    def request_method
      ""
    end
  end
  
  def root_url
    ''
  end
  
  def request
    return @request if defined?(@request)
    super
    # Rails does some crazy s#!t with the "method" method. If I don't do this I get a "wrong arguments (0 for 1) error"
    @request.class.class_eval do
      def method
        nil
      end
    end
    @request
  end
  
  def url_for(*args)
    ''
  end
  
  def redirecting_to
    @redirect_to
  end
  
  def redirect_to(*args)
    @redirect_to = args
  end
end