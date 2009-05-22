module AuthlogicOpenid
  # This module is responsible for adding all of the OpenID goodness to the Authlogic::Session::Base class.
  module Session
    # Add a simple openid_identifier attribute and some validations for the field.
    def self.included(klass)
      klass.class_eval do
        extend Config
        include Methods
      end
    end
    
    module Config
      # What method should we call to find a record by the openid_identifier?
      # This is useful if you want to store multiple openid_identifiers for a single record.
      # You could do something like:
      #
      #   class User < ActiveRecord::Base
      #     def self.find_by_openid_identifier(identifier)
      #       user.first(:conditions => {:openid_identifiers => {:identifier => identifier}})
      #     end
      #   end
      #
      # Obviously the above depends on what you are calling your assocition, etc. But you get the point.
      #
      # * <tt>Default:</tt> :find_by_openid_identifier
      # * <tt>Accepts:</tt> Symbol
      def find_by_openid_identifier_method(value = nil)
        rw_config(:find_by_openid_identifier_method, value, :find_by_openid_identifier)
      end
      alias_method :find_by_openid_identifier_method=, :find_by_openid_identifier_method
    end
    
    module Methods
      def self.included(klass)
        klass.class_eval do
          attr_reader :openid_identifier
          validate :validate_openid_error
          validate :validate_by_openid, :if => :authenticating_with_openid?
        end
      end
      
      # Hooks into credentials so that you can pass an :openid_identifier key.
      def credentials=(value)
        super
        values = value.is_a?(Array) ? value : [value]
        hash = values.first.is_a?(Hash) ? values.first.with_indifferent_access : nil
        self.openid_identifier = hash[:openid_identifier] if !hash.nil? && hash.key?(:openid_identifier)
      end
      
      def openid_identifier=(value)
        @openid_identifier = value.blank? ? nil : OpenIdAuthentication.normalize_identifier(value)
        @openid_error = nil
      rescue OpenIdAuthentication::InvalidOpenId => e
        @openid_identifier = nil
        @openid_error = e.message
      end
      
      # Cleaers out the block if we are authenticating with OpenID, so that we can redirect without a DoubleRender
      # error.
      def save(&block)
        block = nil if !openid_identifier.blank?
        super(&block)
      end
      
      private
        def authenticating_with_openid?
          attempted_record.nil? && errors.empty? && (!openid_identifier.blank? || (controller.params[:open_id_complete] && controller.params[:for_session]))
        end
        
        def find_by_openid_identifier_method
          self.class.find_by_openid_identifier_method
        end
        
        def validate_by_openid
          self.remember_me = controller.params[:remember_me] == "true" if controller.params.key?(:remember_me)
          controller.send(:authenticate_with_open_id, openid_identifier, :return_to => controller.url_for(:for_session => "1", :remember_me => remember_me?)) do |result, openid_identifier|
            if result.unsuccessful?
              errors.add_to_base(result.message)
              return
            end
            
            self.attempted_record = klass.send(find_by_openid_identifier_method, openid_identifier)
            
            if !attempted_record
              errors.add(:openid_identifier, "did not match any users in our database, have you set up your account to use OpenID?")
              return
            end
          end
        end
        
        def validate_openid_error
          errors.add(:openid_identifier, @openid_error) if @openid_error
        end
    end
  end
end