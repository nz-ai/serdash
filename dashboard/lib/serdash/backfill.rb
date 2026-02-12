# frozen_string_literal: true

module Serdash
  module Backfill
    def self.run(server:)
      sid = server.id
      interval_min = 30
      now = Time.current
      start_time = 30.days.ago
      samples_count = (30.days / interval_min.minutes).to_i

      disk_mounts = ["/", "/media", "/opt/backup"]
      disk_config = {
        "/" => { total: 128 * 1024**3, used_pct: 0.78 },
        "/media" => { total: 2 * 1024**4, used_pct: 0.65 },
        "/opt/backup" => { total: 4 * 1024**4, used_pct: 0.82 },
      }

      mem_total = 32 * 1024**3
      mem_used_pct = 0.45..0.75
      cpu_usage_range = 5.0..95.0
      cpu_temp_range = 35.0..72.0

      disk_rows = []
      mem_rows = []
      cpu_rows = []
      port_rows = []
      conn_rows = []

      samples_count.times do |i|
        t = start_time + i * interval_min.minutes
        next if t > now

        ts = t.utc
        day_offset = (t - start_time) / 1.day
        variation = Math.sin(day_offset * 0.3) * 0.05 + (day_offset % 7) * 0.01

        disk_mounts.each do |mp|
          cfg = disk_config[mp]
          used_pct = cfg[:used_pct] + variation + ("#{mp}#{i}".hash % 100) / 10_000.0
          used_pct = used_pct.clamp(0.5, 0.95)
          used = (cfg[:total] * used_pct).to_i
          free = cfg[:total] - used
          disk_rows << { server_id: sid, sampled_at: ts, mount_point: mp, total_bytes: cfg[:total], free_bytes: free }
        end

        pct = mem_used_pct.min + (mem_used_pct.max - mem_used_pct.min) * (0.5 + 0.5 * Math.sin(i * 0.1))
        used = (mem_total * pct).to_i
        free = mem_total - used
        mem_rows << { server_id: sid, sampled_at: ts, total_bytes: mem_total, used_bytes: used, free_bytes: free }

        usage = cpu_usage_range.min + ("cpu#{i}".hash % 10_000) / 10_000.0 * (cpu_usage_range.max - cpu_usage_range.min)
        temp = cpu_temp_range.min + ("temp#{i}".hash % 10_000) / 10_000.0 * (cpu_temp_range.max - cpu_temp_range.min)
        cpu_rows << { server_id: sid, sampled_at: ts, usage_percent: usage.round(2), temperature_celsius: temp.round(2) }

        if i % 6 == 0
          [[22, "sshd"], [80, "nginx"], [443, "nginx"], [3306, "mysqld"], [5432, "postgres"]].each do |port, proc_name|
            port_rows << { server_id: sid, sampled_at: ts, port: port, protocol: "tcp", process: proc_name }
          end
        end

        if i % 4 == 0
          [["192.168.1.100:22", "10.0.0.5:54321", "ESTABLISHED"], ["0.0.0.0:80", "*:*", "LISTEN"], ["0.0.0.0:443", "*:*", "LISTEN"]].each do |local, remote, state|
            conn_rows << { server_id: sid, sampled_at: ts, local_addr: local, remote_addr: remote, state: state }
          end
        end
      end

      # Delete existing backfill for this server, then bulk insert
      [DiskSample, MemorySample, CpuSample, ListeningPortSample, ConnectionSample].each do |model|
        model.where(server_id: sid).delete_all
      end

      DiskSample.insert_all(disk_rows.map { |r| r.merge(created_at: Time.current, updated_at: Time.current) })
      MemorySample.insert_all(mem_rows.map { |r| r.merge(created_at: Time.current, updated_at: Time.current) })
      CpuSample.insert_all(cpu_rows.map { |r| r.merge(created_at: Time.current, updated_at: Time.current) })
      ListeningPortSample.insert_all(port_rows.map { |r| r.merge(created_at: Time.current, updated_at: Time.current) })
      ConnectionSample.insert_all(conn_rows.map { |r| r.merge(created_at: Time.current, updated_at: Time.current) })
    end
  end
end
