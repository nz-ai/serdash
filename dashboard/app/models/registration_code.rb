# frozen_string_literal: true

class RegistrationCode < ApplicationRecord
  belongs_to :server, optional: true

  validates :code, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :valid, -> { where("expires_at > ?", Time.current) }

  def expired?
    expires_at < Time.current
  end
end
