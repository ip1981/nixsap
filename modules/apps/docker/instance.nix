pkgs:

{ lib, name, config, ... }:

let

  inherit (lib)
    mkOption
    ;

  inherit (lib.types)
    bool enum int listOf nullOr package path str
    ;

  default = d: t: mkOption { type = t; default = d; };
  optional = t: mkOption { type = nullOr t; default = null; };
  readonly = d: t: mkOption { type = nullOr t; default = d; readOnly = true; };

  socket = "unix://${config.daemon.exec-root}/dockerd.sock";

in {
  options = {
    package = mkOption {
      description = "Docker package";
      default = pkgs.docker;
      type = package;
    };

    docker-cli = mkOption {
      description = "Convenient wrapper of docker command line uitlity for this Docker instance";
      type = package;
      readOnly = true;
      default = pkgs.runCommand "docker-${name}" {} ''
        mkdir -p $out/bin
        mkdir -p $out/share/bash-completion/completions

        cat << 'ETC' > "$out/share/bash-completion/completions/docker-${name}"
        . ${config.package}/share/bash-completion/completions/docker
        complete -r docker
        complete -F _docker 'docker-${name}'
        ETC

        cat << 'BIN' > "$out/bin/docker-${name}"
        exec ${config.package}/bin/docker --host '${socket}' "$@"
        BIN

        chmod +x "$out/bin/docker-${name}"
      '';
    };

    daemon = {
      debug = optional bool;
      add-runtime = optional (listOf str);
      allow-nondistributable-artifacts  = optional (listOf str);
      api-cors-header = optional str;
      authorization-plugin = optional (listOf str);
      bip = optional str;
      bridge = optional str;
      cgroup-parent = optional str;
      containerd = optional str;
      cpu-rt-period = optional int;
      cpu-rt-runtime = optional int;
      data-root = default "/docker/${name}" path;
      default-gateway = optional str;
      default-gateway-v6 = optional str;
      default-runtime  = optional str;
      # TBD: default-ulimit = optional attributes
      dns = optional (listOf str);
      dns-opt = optional (listOf str);
      dns-search = optional (listOf str);
      exec-root = readonly "${config.daemon.data-root}/run" path;
      experimental = optional bool;
      fixed-cidr = optional str;
      fixed-cidr-v6 = optional str;
      group = default "docker-${name}" str;
      hosts = readonly [socket] (listOf str);
      icc = optional bool;
      init = optional bool;
      init-path = optional path;
      insecure-registry = optional (listOf str);
      ip = optional str;
      ip-forward = optional bool;
      ip-masq = optional bool;
      iptables = optional bool;
      ipv6 = optional bool;
      live-restore = optional bool;
      log-driver = readonly "journald" str;
      log-level = optional (enum ["debug" "info" "warn" "error" "fatal"]);
      max-concurrent-downloads = optional int;
      max-concurrent-uploads = optional int;
      metrics-addr = optional str;
      mtu = optional int;
      no-new-privileges = optional bool;
      oom-score-adjust = optional int;
      pidfile = readonly "${config.daemon.exec-root}/dockerd.pid" path;
      raw-logs = optional bool;
      registry-mirror = optional (listOf str);
      seccomp-profile = optional path;
      selinux-enabled = optional bool;
      shutdown-timeout = optional int;
      storage-driver = optional (enum ["aufs" "devicemapper" "btrfs" "zfs" "overlay" "overlay2"]);
      storage-opt = optional (listOf str);
      swarm-default-advertise-addr = optional str;
      userland-proxy = optional bool;
      userland-proxy-path = optional path;
      userns-remap = optional str;
    };
  };
}
