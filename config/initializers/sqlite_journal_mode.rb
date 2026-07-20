# ADR-003: keep SQLite in default rollback-journal mode (never WAL) while the
# database lives on NFS. Assert after each connection so a misconfigured
# PRAGMA cannot silently enable WAL.
Rails.application.config.after_initialize do
  next unless defined?(ActiveRecord::Base)

  ActiveRecord::Base.connection_handler.connection_pool_list(:writing).each do |pool|
    pool.with_connection do |connection|
      next unless connection.adapter_name.match?(/sqlite/i)

      mode = connection.select_value("PRAGMA journal_mode;")
      if mode.to_s.downcase == "wal"
        raise "SQLite journal_mode is WAL (got #{mode.inspect}); ADR-003 requires delete/rollback mode"
      end
    end
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
    # DB may not exist yet during first boot / db:prepare — skip until connected.
  end
end
