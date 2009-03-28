module AuthlogicOpenid
  module ActsAsAuthentic
    def self.included(klass)
      klass.class_eval do
        add_acts_as_authentic_module(Methods)
      end
    end
    
    module Methods
      def self.included(klass)
        klass.class_eval do
          validates_uniqueness_of :openid_identifier, :scope => validations_scope, :if => :using_openid?
          validate :validate_openid
          [:validates_length_of_login_field_options, :validates_format_of_login_field_options, :validates_length_of_password_field_options,
            :validates_confirmation_of_password_field_options, :validates_length_of_password_confirmation_field_options].each do |method|
              send(method, send(method).merge(:unless => :using_openid?))
          end
        end
      end
      
      def save(*args, &block)
        normalize_openid_identifier if using_openid?
        if !authenticate_with_openid? || (authenticate_with_openid? && authenticate_with_openid)
          result = super
          yield(result) if block_given?
          result
        else
          false
        end
      end
      
      private
        def normalize_openid_identifier
          begin
            self.openid_identifier = OpenIdAuthentication.normalize_identifier(openid_identifier)
          rescue Exception
          end
        end
        
        def authenticate_with_openid
          @openid_error = nil
          
          if !openid_complete?
            attrs_to_persist = attributes.delete_if do |k, v|
              [:password, crypted_password_field, password_salt_field, :persistence_token, :perishable_token, :single_access_token, :login_count, 
                :failed_login_count, :last_request_at, :current_login_at, :last_login_at, :current_login_ip, :last_login_ip, :created_at,
                :updated_at, :lock_version].include?(k.to_sym)
            end
            attrs_to_persist.merge!(:password => password, :password_confirmation => password_confirmation)
            session_class.controller.session[:openid_attributes] = attrs_to_persist
          else
            self.attributes = session_class.controller.session[:openid_attributes]
            session_class.controller.session[:openid_attributes] = nil
          end
          
          session_class.controller.send(:authenticate_with_open_id, openid_identifier, :return_to => session_class.controller.url_for(:for_model => "1")) do |result, openid_identifier|
            @openid_error = result.message if result.unsuccessful?
            return true
          end
          
          return false
        end
        
        def validate_openid
          errors.add(:openid_identifier, "had the following error: #{@openid_error}") if @openid_error
        end
        
        def using_openid?
          !openid_identifier.blank?
        end
        
        def openid_complete?
          session_class.controller.params[:open_id_complete] && session_class.controller.params[:for_model]
        end
        
        def authenticate_with_openid?
          session_class.activated? && ((using_openid? && openid_identifier_changed?) || openid_complete?)
        end
    end
  end
end