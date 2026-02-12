# frozen_string_literal: true

class User < ApplicationRecord
  validates :email, presence: true, uniqueness: { scope: :provider }

  def self.from_omniauth(auth)
    email = auth.info&.email || auth.extra&.raw_info&.email
    raise "No email from provider" if email.blank?

    where(provider: auth.provider, uid: auth.uid).first_or_initialize.tap do |user|
      user.email = email
      user.save!
    end
  end
end
