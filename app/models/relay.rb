# frozen_string_literal: true

require "net/http"

class Relay < ApplicationRecord

  belongs_to :instrument, inverse_of: :relay

  validates_presence_of :instrument_id, on: :update
  validate :unique_host_and_schedule

  alias_attribute :host, :ip

  delegate :facility, to: :instrument

  CONTROL_MECHANISMS = {
    manual: nil,
    timer: "timer",
    relay: "relay",
  }.freeze

  def get_status
    query_status
  end

  def activate
    toggle(true)
  end

  def deactivate
    toggle(false)
  end

  def control_mechanism
    CONTROL_MECHANISMS[:manual]
  end

  def networked_relay?
    control_mechanism == CONTROL_MECHANISMS[:relay]
  end

  def to_log_s
    instrument.name
  end

  private

  def toggle(_status)
    raise NotImplementedError.new("Subclass must define")
  end

  def query_status
    raise NotImplementedError.new("Subclass must define")
  end

  # Checks for unique combination of host, outlet and ip_port.
  # Shared calendar instruments might actually point to the same physical relay,
  # so they can share a host/outlet/port.
  def unique_host_and_schedule
    return unless host.present?

    scope = Relay.unscoped.where(host: host, outlet: outlet, ip_port: ip_port)
    scope = scope.joins(:instrument).where("products.schedule_id != ?", instrument.schedule_id) if instrument.try(:schedule_id)
    scope = scope.where("relays.id != ?", id) if persisted?
    errors.add(:outlet, :taken) if scope.exists?
  end

end
