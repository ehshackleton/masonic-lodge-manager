# frozen_string_literal: true

module TokenEncryptable
  extend ActiveSupport::Concern

  class_methods do
    def encrypts_token(*attrs)
      attrs.each do |attr|
        define_method(attr) do
          ciphertext = self["#{attr}_ciphertext"]
          return if ciphertext.blank?

          token_encryptor.decrypt_and_verify(ciphertext)
        rescue ActiveSupport::MessageEncryptor::InvalidMessage
          nil
        end

        define_method("#{attr}=") do |value|
          self["#{attr}_ciphertext"] = if value.present?
                                         token_encryptor.encrypt_and_sign(value.to_s)
          end
        end
      end
    end
  end

  private

  def token_encryptor
    @token_encryptor ||= begin
      len = ActiveSupport::MessageEncryptor.key_len
      key = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base)
                                       .generate_key("workspace-oauth-tokens-v1", len)
      ActiveSupport::MessageEncryptor.new(key)
    end
  end
end
