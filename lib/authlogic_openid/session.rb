module AuthlogicOpenid
  module Session
    def self.included(klass)
      klass.class_eval do
        attr_accessor :openid_identifier
        validate :validate_by_openid, :if => :authenticating_with_openid?
      end
    end
  
    def credentials=(value)
      super
      values = value.is_a?(Array) ? value : [value]
      hash = values.first.is_a?(Hash) ? values.first.with_indifferent_access : nil
      self.openid_identifier = hash[:openid_identifier] if !hash.nil? && hash.key?(:openid_identifier)
    end
  
    def save(&block)
      block = nil if !openid_identifier.blank?
      super(&block)
    end
  
    private
      def authenticating_with_openid?
        !openid_identifier.blank? || (controller.params[:open_id_complete] && controller.params[:for_session])
      end
    
      def validate_by_openid
        controller.send(:authenticate_with_open_id, openid_identifier, :return_to => controller.url_for(:for_session => "1")) do |result, openid_identifier|
          if result.unsuccessful?
            errors.add_to_base(result.message)
            return
          end

          self.attempted_record = klass.find_by_openid_identifier(openid_identifier)

          if !attempted_record
            errors.add(:openid_identifier, "did not match any users in our database, have you set up your account to use OpenID?")
            return
          end
        end
      end
  end
end