# frozen_string_literal: true

class NetworkDevice < ApplicationRecord
  validates :name, presence: true
  validates :device_type, inclusion: { in: %w[esp32 router switch other], allow_nil: true }
end
