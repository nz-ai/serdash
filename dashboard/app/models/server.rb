# frozen_string_literal: true

class Server < ApplicationRecord
  has_many :registration_codes, dependent: :destroy
  has_many :disk_samples, dependent: :destroy
  has_many :memory_samples, dependent: :destroy
  has_many :cpu_samples, dependent: :destroy
  has_many :network_interface_samples, dependent: :destroy
  has_many :listening_port_samples, dependent: :destroy
  has_many :connection_samples, dependent: :destroy

  validates :status, inclusion: { in: %w[pending_registration active unreachable] }

  scope :active, -> { where(status: "active") }
end
