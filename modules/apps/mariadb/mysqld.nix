{ lib, ... }:
with lib;
with lib.types;

let
  engines = [
    "Archive"
    "Aria"
    "Blackhole"
    "CSV"
    "Example"
    "InnoDB"
    "Memory"
    "MyISAM"
  ];

  syslog-facilities = [
    "LOG_USER"
    "LOG_MAIL"
    "LOG_DAEMON"
    "LOG_AUTH"
    "LOG_SYSLOG"
    "LOG_LPR"
    "LOG_NEWS"
    "LOG_UUCP"
    "LOG_CRON"
    "LOG_AUTHPRIV"
    "LOG_FTP"
    "LOG_LOCAL0"
    "LOG_LOCAL1"
    "LOG_LOCAL2"
    "LOG_LOCAL3"
    "LOG_LOCAL4"
    "LOG_LOCAL5"
    "LOG_LOCAL6"
    "LOG_LOCAL7"
  ];

  syslog-priorities = [
    "LOG_EMERG"
    "LOG_ALERT"
    "LOG_CRIT"
    "LOG_ERR"
    "LOG_WARNING"
    "LOG_NOTICE"
    "LOG_INFO"
    "LOG_DEBUG"
  ];

  sql-modes = [
    "ALLOW_INVALID_DATES"
    "ANSI"
    "ANSI_QUOTES"
    "DB2"
    "ERROR_FOR_DIVISION_BY_ZERO"
    "HIGH_NOT_PRECEDENCE"
    "IGNORE_BAD_TABLE_OPTIONS"
    "IGNORE_SPACE"
    "MAXDB"
    "MSSQL"
    "MYSQL323"
    "MYSQL40"
    "NO_AUTO_CREATE_USER"
    "NO_AUTO_VALUE_ON_ZERO"
    "NO_BACKSLASH_ESCAPES"
    "NO_DIR_IN_CREATE"
    "NO_ENGINE_SUBSTITUTION"
    "NO_FIELD_OPTIONS"
    "NO_KEY_OPTIONS"
    "NO_TABLE_OPTIONS"
    "NO_UNSIGNED_SUBTRACTION"
    "NO_ZERO_DATE"
    "NO_ZERO_IN_DATE"
    "ONLY_FULL_GROUP_BY"
    "ORACLE"
    "PAD_CHAR_TO_FULL_LENGTH"
    "PIPES_AS_CONCAT"
    "POSTGRESQL"
    "REAL_AS_FLOAT"
    "STRICT_ALL_TABLES"
    "STRICT_TRANS_TABLES"
    "TRADITIONAL"
  ];

  flush-methods = [
    "ALL_O_DIRECT"
    "O_DIRECT"
    "O_DSYNC"
    "fdatasync"
  ];

  default = v: type: mkOption { type = type; default = v; };
  mandatory = type: mkOption { inherit type; };
  optional = type: mkOption { type = nullOr type; default = null; };
  set = opts: mkOption { type = nullOr (submodule opts); default = null; };

  oneOrMore = l: let en = enum' l; in either en (uniq (listOf en));

  # XXX https://github.com/NixOS/nixpkgs/issues/9826
  enum' = values:
    let show = v: let t = builtins.typeOf v;
            in if t == "string" then ''"${v}"''
          else if t == "int" then builtins.toString v
          else ''<${t}>'';
    in mkOptionType {
      name = "one of ${concatStringsSep ", " (map show values)}";
      check = flip elem values;
      merge = mergeOneOption;
    };

  isFloat = x: builtins.match "^[0-9]+(\\.[0-9]+)?$" (builtins.toString x) != null;

  float = mkOptionType {
    name = "positive float";
    check = isFloat;
  };

  # https://mariadb.com/kb/en/mariadb/optimizer-switch/
  optimizer = {
    options = {
      derived_merge                 = optional bool;
      derived_with_keys             = optional bool;
      exists_to_in                  = optional bool;
      extended_keys                 = optional bool;
      firstmatch                    = optional bool;
      in_to_exists                  = optional bool;
      index_merge                   = optional bool;
      index_merge_intersection      = optional bool;
      index_merge_sort_intersection = optional bool;
      index_merge_sort_union        = optional bool;
      index_merge_union             = optional bool;
      join_cache_bka                = optional bool;
      join_cache_hashed             = optional bool;
      join_incremental              = optional bool;
      loosescan                     = optional bool;
      materialization               = optional bool;
      mrr                           = optional bool;
      mrr_cost_based                = optional bool;
      mrr_sort_keys                 = optional bool;
      optimize_join_buffer_size     = optional bool;
      outer_join_with_cache         = optional bool;
      partial_match_rowid_merge     = optional bool;
      partial_match_table_scan      = optional bool;
      semijoin                      = optional bool;
      semijoin_with_cache           = optional bool;
      subquery_cache                = optional bool;
      table_elimination             = optional bool;
    };
  };

in {
  options = {
    binlog_checksum                         = optional (enum ["NONE" "CRC32"]);
    binlog_commit_wait_count                = optional int;
    binlog_commit_wait_usec                 = optional int;
    binlog_direct_non_transactional_updates = optional bool;
    binlog_format                           = optional (enum ["ROW" "MIXED" "STATEMENT"]);
    binlog_optimize_thread_scheduling       = optional bool;
    binlog_row_image                        = optional (enum ["FULL" "NOBLOB" "MINIMAL"]);
    binlog_stmt_cache_size                  = optional int;
    character_set_server                    = optional str;
    collation_server                        = optional str;
    connect_timeout                         = optional int;
    datadir                                 = mandatory path;
    default_storage_engine                  = optional (enum engines);
    default_time_zone                       = optional str;
    encrypt_binlog                          = optional bool;
    event_scheduler                         = optional (either bool (enum ["DISABLED"]));
    expire_logs_days                        = optional int;
    general_log                             = optional bool;
    group_concat_max_len                    = optional int;
    ignore_db_dirs                          = optional (uniq (listOf str));
    init_connect                            = optional str;
    init_slave                              = optional str;
    innodb_autoinc_lock_mode                = optional (enum' [ 0 1 2 ]);
    innodb_buffer_pool_dump_at_shutdown     = optional bool;
    innodb_buffer_pool_instances            = optional int;
    innodb_buffer_pool_load_at_startup      = optional bool;
    innodb_buffer_pool_size                 = optional int;
    innodb_compression_algorithm            = optional (enum ["none" "zlib" "lz4" "lzo" "lzma" "bzip2" "snappy"]);
    innodb_compression_failure_threshold_pct = optional (addCheck int (i: 0 <= i && i <= 100));
    innodb_compression_level                = optional (enum' [0 1 2 3 4 5 6 7 8 9]);
    innodb_compression_pad_pct_max          = optional (addCheck int (i: 0 <= i && i <= 75));
    innodb_doublewrite                      = optional bool;
    innodb_file_format                      = optional (enum ["antelope" "barracuda"]);
    innodb_file_per_table                   = optional bool;
    innodb_flush_log_at_trx_commit          = optional (enum' [0 1 2]);
    innodb_flush_method                     = optional (enum flush-methods);
    innodb_io_capacity                      = optional int;
    innodb_io_capacity_max                  = optional int;
    innodb_lock_wait_timeout                = optional int;
    innodb_log_file_size                    = optional int;
    innodb_open_files                       = optional int;
    innodb_read_io_threads                  = optional int;
    innodb_rollback_on_timeout              = optional bool;
    innodb_thread_concurrency               = optional int;
    innodb_write_io_threads                 = optional int;
    interactive_timeout                     = optional int;
    join_buffer_size                        = optional int;
    local_infile                            = optional bool;
    log_bin                                 = optional path;
    log_bin_index                           = optional str;
    log_output                              = optional (oneOrMore ["TABLE" "FILE"]);
    log_queries_not_using_indexes           = optional bool;
    log_slave_updates                       = default false bool;
    log_slow_rate_limit                     = optional int;
    log_slow_verbosity                      = optional (enum' ["query_plan" "innodb" "explain"]);
    log_warnings                            = optional (enum' [ 0 1 2 3 ]);
    long_query_time                         = optional float;
    max_allowed_packet                      = optional int;
    max_binlog_cache_size                   = optional int;
    max_binlog_size                         = optional int;
    max_binlog_stmt_cache_size              = optional int;
    max_connect_errors                      = optional int;
    max_connections                         = optional int;
    max_heap_table_size                     = optional int;
    max_relay_log_size                      = optional int;
    max_user_connections                    = optional int;
    net_read_timeout                        = optional int;
    net_write_timeout                       = optional int;
    optimizer_switch                        = set optimizer;
    port                                    = default 3306 int;
    query_alloc_block_size                  = optional int;
    query_cache_limit                       = optional int;
    query_cache_min_res_unit                = optional int;
    query_cache_size                        = optional int;
    query_cache_strip_comments              = optional bool;
    query_cache_type                        = optional (enum' [ 0 1 "DEMAND"]);
    query_cache_wlock_invalidate            = optional bool;
    query_prealloc_size                     = optional int;
    relay_log                               = optional path;
    relay_log_index                         = optional str;
    relay_log_purge                         = optional bool;
    relay_log_recovery                      = optional bool;
    relay_log_space_limit                   = optional int;
    server_audit_events                     = optional (uniq (listOf (enum ["CONNECT" "QUERY" "TABLE" "QUERY_DDL" "QUERY_DML"])));
    server_audit_excl_users                 = optional (listOf str);
    server_audit_file_path                  = optional path;
    server_audit_file_rotate_size           = optional int;
    server_audit_file_rotations             = optional int;
    server_audit_incl_users                 = optional (listOf str);
    server_audit_logging                    = optional bool;
    server_audit_output_type                = optional (enum ["SYSLOG" "FILE"]);
    server_audit_query_log_limit            = optional int;
    server_audit_syslog_facility            = optional (enum syslog-facilities);
    server_audit_syslog_ident               = optional str;
    server_audit_syslog_info                = optional str;
    server_audit_syslog_priority            = optional (enum syslog-priorities);
    server_id                               = optional int;
    skip_log_bin                            = optional bool;
    skip_name_resolve                       = optional bool;
    skip_networking                         = optional bool;
    slave_compressed_protocol               = optional bool;
    slave_ddl_exec_mode                     = optional (enum ["IDEMPOTENT" "STRICT"]);
    slave_domain_parallel_threads           = optional int;
    slave_exec_mode                         = optional (enum ["IDEMPOTENT" "STRICT"]);
    slave_load_tmpdir                       = optional path;
    slave_max_allowed_packet                = optional int;
    slave_net_timeout                       = optional int;
    slave_parallel_max_queued               = optional int;
    slave_parallel_mode                     = optional (enum ["conservative" "optimisitic" "none" "aggressive" "minimal"]);
    slave_parallel_threads                  = optional int;
    slave_skip_errors                       = optional (uniq (listOf int));
    slave_sql_verify_checksum               = optional bool;
    slave_transaction_retries               = optional int;
    slow_query_log                          = optional bool;
    slow_query_log_file                     = optional path;
    sort_buffer_size                        = optional int;
    sql_mode                                = optional (uniq (listOf (enum sql-modes)));
    ssl_ca                                  = optional path;
    ssl_capath                              = optional path;
    ssl_cert                                = optional path;
    ssl_cipher                              = optional str;
    ssl_crl                                 = optional path;
    ssl_crlpath                             = optional path;
    ssl_key                                 = optional path;
    table_definition_cache                  = optional int;
    table_open_cache                        = optional int;
    thread_cache_size                       = optional int;
    tmp_table_size                          = optional int;
    tmpdir                                  = optional path;
    wait_timeout                            = optional int;
  };
  config = {
    ignore_db_dirs = [ "lost+found" ];
  };

}

