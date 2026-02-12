# frozen_string_literal: true

class ServersController < ApplicationController
  before_action :require_login
  before_action :set_server, only: [:show, :destroy, :metrics, :ports, :connections]

  def index
    @servers = Server.all.order(:hostname)
  end

  def show
    @tab = params[:tab].presence || "metrics"
    @ports_date = params[:ports_date].presence ? Date.parse(params[:ports_date]) : Date.current
    @connections_date = params[:connections_date].presence ? Date.parse(params[:connections_date]) : Date.current

    samples = @server.listening_port_samples
      .where(sampled_at: @ports_date.beginning_of_day..@ports_date.end_of_day)
      .order(:sampled_at)
    @ports = samples.group_by(&:port).transform_values(&:last).values.sort_by(&:port)

    @connections = @server.connection_samples
      .where(sampled_at: @connections_date.beginning_of_day..@connections_date.end_of_day)
      .order(:sampled_at)
  end

  def metrics
    range = params[:range].presence || "7d"
    since = case range
            when "1d" then 1.day.ago
            when "7d" then 7.days.ago
            when "30d" then 30.days.ago
            else 7.days.ago
            end

    disk = @server.disk_samples.where("sampled_at >= ?", since).order(:sampled_at)
    disk_by_mount = disk.group_by(&:mount_point)

    memory = @server.memory_samples.where("sampled_at >= ?", since).order(:sampled_at)
    cpu = @server.cpu_samples.where("sampled_at >= ?", since).order(:sampled_at)

    data = {
      disk: disk_by_mount.transform_values { |samples| samples.map { |s| { t: s.sampled_at.to_i * 1000, used_pct: (s.total_bytes && s.total_bytes > 0) ? (1 - s.free_bytes.to_f / s.total_bytes) * 100 : 0, free_gb: (s.free_bytes / 1024.0**3).round(2) } } },
      memory: memory.map { |s| { t: s.sampled_at.to_i * 1000, used_pct: (s.total_bytes && s.total_bytes > 0) ? (s.used_bytes.to_f / s.total_bytes) * 100 : 0, used_gb: (s.used_bytes / 1024.0**3).round(2) } },
      cpu: cpu.map { |s| { t: s.sampled_at.to_i * 1000, usage: s.usage_percent, temp: s.temperature_celsius } },
    }
    respond_to do |f|
      f.json { render json: data }
    end
  end

  def ports
    @date = params[:date].presence ? Date.parse(params[:date]) : Date.current
    start_at = @date.beginning_of_day
    end_at = @date.end_of_day
    samples = @server.listening_port_samples
      .where(sampled_at: start_at..end_at)
      .order(:sampled_at)
    @by_port = samples.group_by(&:port).transform_values(&:last)
    @ports = @by_port.values.sort_by(&:port)
  end

  def connections
    @date = params[:date].presence ? Date.parse(params[:date]) : Date.current
    start_at = @date.beginning_of_day
    end_at = @date.end_of_day
    @connections = @server.connection_samples
      .where(sampled_at: start_at..end_at)
      .order(:sampled_at)
  end

  def new
    @server = Server.new(
      hostname: params[:hostname],
      ip: params[:ip]
    )
  end

  def create
    @server = Server.new(server_params)
    @server.status = "pending_registration"

    if @server.save
      code = SecureRandom.hex(4).upcase
      RegistrationCode.create!(
        server: @server,
        code: code,
        expires_at: 15.minutes.from_now
      )
      redirect_to server_path(@server), notice: "Server created. Registration code: #{code} (expires in 15 min)"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @server.destroy
    redirect_to servers_path, notice: "Server removed."
  end

  private

  def set_server
    @server = Server.find(params[:id])
  end

  def server_params
    params.require(:server).permit(:hostname, :ip)
  end
end
