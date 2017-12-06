pkgs:
{ config, lib, name, ... }:

let

  inherit (builtins)
    toJSON ;

  inherit (lib)
    filterAttrs mapAttrs mapAttrsToList mkOption ;

  inherit (lib.types)
    attrsOf bool enum int listOf nullOr package path str ;

  explicit = filterAttrs (n: v: n != "_module" && v != null);

  default = d: t: mkOption { type = t; default = d; };
  optional = t: mkOption { type = nullOr t; default = null; };
  readonly = d: t: mkOption { type = nullOr t; default = d; readOnly = true; };

  params = config.parameters;

  entries =
    let
      transform = n: v:
        if n == "seed_provider" then
          mapAttrsToList (p: o:
            { class_name = p;
              parameters = mapAttrsToList (a: b: { ${a} = b; }) o;
            }
          ) v
        else v;
    in mapAttrs transform (explicit params);

  configFile = pkgs.runCommand "cassandra-${name}.yml" {} ''
    ${pkgs.haskellPackages.yaml}/bin/json2yaml \
    ${pkgs.writeText "cassandra-${name}.json" (toJSON entries)} > "$out"
  '';


in {
  options = {

    package = mkOption {
      description = ''
        The Cassandra package.  This is a convenient way to set Java class
        path and library path.  The package should include `$out/share/java`
        directory with all jars required to run Cassandra and `$out/lib/jni`
        with all runtime libraries.
      '';
      default = pkgs.cassandra3;
      type = package;
    };

    jre = {
      package = mkOption {
        description = "Java runtime package";
        default = pkgs.jre8;
        type = package;
      };

      # TODO: this should be generalized, see default.nix
      properties = {
        cassandra.config = readonly "file://${configFile}" str;
        java.io.tmpdir = readonly "${config.home}/tmp" path;
        java.library.path = default [ "${config.package}/lib/jni" ] (listOf path);
      };
    };

    classpath = mkOption {
      description = "Cassandra's Java class path";
      type = listOf path;
      default = [ "${config.package}/share/java/*" ];
    };

    user = mkOption {
      description = "User to run as";
      default = "cassandra-${name}";
      type = str;
    };

    home = mkOption {
      description = "Cassandra home directory";
      default = "/cassandra/${name}";
      type = path;
    };

    # XXX "Default" is missleading in Cassandra docs.
    # XXX Parameters shall be defined in config file.
    parameters = {
      seed_provider = mkOption {
        description = "Seed providers with paramaters";
        type = attrsOf (attrsOf str);
        default = {
          "org.apache.cassandra.locator.SimpleSeedProvider" = {
            seeds = "127.0.0.1";
          };
        };
      };

      # TBD: back_pressure_strategy
      # TBD: client_encryption_options
      # TBD: commitlog_compression
      # TBD: hints_compression
      # TBD: otc_coalescing_strategy
      # TBD: seed_provider
      # TBD: server_encryption_options
      # TBD: transparent_data_encryption_options
      allocate_tokens_for_keyspace                         = optional str;
      authenticator                                        = optional str;
      authorizer                                           = optional str;
      auto_snapshot                                        = optional bool;
      back_pressure_enabled                                = optional bool;
      batch_size_fail_threshold_in_kb                      = optional int;
      batch_size_warn_threshold_in_kb                      = optional int;
      batchlog_replay_throttle_in_kb                       = optional int;
      broadcast_address                                    = optional str;
      broadcast_rpc_address                                = optional str;
      buffer_pool_use_heap_if_exhausted                    = optional bool;
      cas_contention_timeout_in_ms                         = optional int;
      cdc_enabled                                          = optional bool;
      cdc_free_space_check_interval_ms                     = optional int;
      cdc_raw_directory                                    = readonly "${config.home}/cdc_raw" path;
      cdc_total_space_in_mb                                = optional int;
      cluster_name                                         = default name str;
      column_index_cache_size_in_kb                        = optional int;
      column_index_size_in_kb                              = optional int;
      commit_failure_policy                                = optional (enum ["die" "stop" "stop_commit" "ignore"]);
      commitlog_directory                                  = readonly "${config.home}/commitlog" path;
      commitlog_segment_size_in_mb                         = optional int;
      commitlog_sync                                       = default "periodic" (enum ["periodic" "batch"]);
      commitlog_sync_batch_window_in_ms                    = optional int;
      commitlog_sync_period_in_ms                          = default 10000 int;
      commitlog_total_space_in_mb                          = optional int;
      compaction_large_partition_warning_threshold_mb      = optional int;
      compaction_throughput_mb_per_sec                     = optional int;
      concurrent_compactors                                = optional int;
      concurrent_counter_writes                            = optional int;
      concurrent_materialized_view_writes                  = optional int;
      concurrent_reads                                     = optional int;
      concurrent_writes                                    = optional int;
      counter_cache_keys_to_save                           = optional int;
      counter_cache_save_period                            = optional int;
      counter_cache_size_in_mb                             = optional int;
      counter_write_request_timeout_in_ms                  = optional int;
      credentials_update_interval_in_ms                    = optional int;
      credentials_validity_in_ms                           = optional int;
      cross_node_timeout                                   = optional bool;
      data_file_directories                                = readonly ["${config.home}/data"] (listOf path);
      disk_failure_policy                                  = optional (enum ["die" "stop_paranoid" "stop" "best_effort" "ignore"]);
      disk_optimization_strategy                           = optional (enum ["ssd" "spinning"]);
      dynamic_snitch_reset_interval_in_ms                  = optional int;
      dynamic_snitch_update_interval_in_ms                 = optional int;
      enable_scripted_user_defined_functions               = optional bool;
      enable_user_defined_functions                        = optional bool;
      endpoint_snitch                                      = default "SimpleSnitch" str;
      file_cache_size_in_mb                                = optional int;
      gc_log_threshold_in_ms                               = optional int;
      gc_warn_threshold_in_ms                              = optional int;
      hinted_handoff_disabled_datacenters                  = optional (listOf str);
      hinted_handoff_enabled                               = optional bool;
      hinted_handoff_throttle_in_kb                        = optional int;
      hints_directory                                      = readonly "${config.home}/hints" path;
      hints_flush_period_in_ms                             = optional int;
      ideal_consistency_level                              = optional str;
      incremental_backups                                  = optional bool;
      index_summary_capacity_in_mb                         = optional int;
      index_summary_resize_interval_in_minutes             = optional int;
      initial_token                                        = optional str;
      inter_dc_stream_throughput_outbound_megabits_per_sec = optional int;
      inter_dc_tcp_nodelay                                 = optional bool;
      internode_authenticator                              = optional str;
      internode_compression                                = optional (enum ["all" "dc" "none"]);
      internode_recv_buff_size_in_bytes                    = optional int;
      internode_send_buff_size_in_bytes                    = optional int;
      key_cache_keys_to_save                               = optional int;
      key_cache_save_period                                = optional int;
      key_cache_size_in_mb                                 = optional int;
      listen_address                                       = default "localhost" str; # TODO: Set listen_address OR listen_interface, not both.
      listen_interface                                     = optional str; # TODO: Set listen_address OR listen_interface, not both.
      listen_interface_prefer_ipv6                         = optional bool;
      listen_on_broadcast_address                          = optional bool;
      max_hint_window_in_ms                                = optional int;
      max_hints_delivery_threads                           = optional int;
      max_hints_file_size_in_mb                            = optional int;
      max_value_size_in_mb                                 = optional int;
      memtable_allocation_type                             = optional (enum ["heap_buffers" "offheap_buffers" "offheap_objects"]);
      memtable_flush_writers                               = optional int;
      memtable_heap_space_in_mb                            = optional int;
      memtable_offheap_space_in_mb                         = optional int;
      native_transport_max_concurrent_connections          = optional int;
      native_transport_max_concurrent_connections_per_ip   = optional int;
      native_transport_max_frame_size_in_mb                = optional int;
      native_transport_max_threads                         = optional int;
      native_transport_port                                = optional int;
      native_transport_port_ssl                            = optional int;
      num_tokens                                           = optional int;
      otc_backlog_expiration_interval_ms                   = optional int;
      otc_coalescing_enough_coalesced_messages             = optional int;
      otc_coalescing_window_us                             = optional int;
      partitioner                                          = default "org.apache.cassandra.dht.Murmur3Partitioner" str;
      permissions_update_interval_in_ms                    = optional int;
      permissions_validity_in_ms                           = optional int;
      phi_convict_threshold                                = optional int;
      prepared_statements_cache_size_mb                    = optional int;
      range_request_timeout_in_ms                          = optional int;
      read_request_timeout_in_ms                           = optional int;
      request_timeout_in_ms                                = optional int;
      role_manager                                         = optional str;
      roles_update_interval_in_ms                          = optional int;
      roles_validity_in_ms                                 = optional int;
      row_cache_class_name                                 = optional str;
      row_cache_keys_to_save                               = optional int;
      row_cache_save_period                                = optional int;
      row_cache_size_in_mb                                 = optional int;
      rpc_address                                          = optional str; # TODO: Set rpc_address OR rpc_interface, not both.
      rpc_interface                                        = optional str; # TODO: Set rpc_address OR rpc_interface, not both.
      rpc_interface_prefer_ipv6                            = optional bool;
      rpc_keepalive                                        = optional bool;
      saved_caches_directory                               = readonly "${config.home}/saved_caches" path;
      slow_query_log_timeout_in_ms                         = optional int;
      snapshot_before_compaction                           = optional bool;
      ssl_storage_port                                     = default 7001 int;
      sstable_preemptive_open_interval_in_mb               = optional int;
      start_native_transport                               = optional bool;
      storage_port                                         = default 7000 int;
      stream_throughput_outbound_megabits_per_sec          = optional int;
      streaming_connections_per_host                       = optional int;
      streaming_keep_alive_period_in_secs                  = optional int;
      tombstone_failure_threshold                          = optional int;
      tombstone_warn_threshold                             = optional int;
      tracetype_query_ttl                                  = optional int;
      tracetype_repair_ttl                                 = optional int;
      trickle_fsync                                        = optional bool;
      trickle_fsync_interval_in_kb                         = optional int;
      truncate_request_timeout_in_ms                       = optional int;
      unlogged_batch_across_partitions_warn_threshold      = optional int;
      windows_timer_interval                               = optional int;
      write_request_timeout_in_ms                          = optional int;
    };
  };
}

