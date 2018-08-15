{ config, pkgs, lib, ... }:

let

  inherit (builtins)
    attrNames
    ;

  inherit (lib)
    concatStringsSep filterAttrs foldl genAttrs mapAttrs' mapAttrsToList
    mkOption nameValuePair removePrefix replaceStrings
    ;

  inherit (lib.types)
    attrsOf enum int listOf path submodule
    ;

  groups = filterAttrs (n: _: n != "_module") config.nixsap.system.lvm.raid0;

  createLV = vg: lv: s: opts:
    let
      new = toString s;
      stripes = toString opts.stripes;
      sizeSpec = if opts.units == "%"
                 then "--extents ${new}%VG"
                 else "--size ${new}${opts.units}";
      scale = {
        "%" = "* 100 / $(vgs --unit b --noheadings --nosuffix --options vg_size ${vg})";
        "M" = "/ ${toString (1000 * 1000)}";
        "m" = "/ ${toString (1024 * 1024)}";
        "G" = "/ ${toString (1000 * 1000 * 1000)}";
        "g" = "/ ${toString (1024 * 1024 * 1024)}";
        "T" = "/ ${toString (1000 * 1000 * 1000 * 1000)}";
        "t" = "/ ${toString (1024 * 1024 * 1024 * 1024)}";
      };
    in pkgs.writeBashScript "raid0-create-${vg}-${lv}" ''
      set -eu
      device=/dev/${vg}/${lv}

      lv_size=$(lvs --unit b --noheadings --nosuffix --options lv_size "$device" || echo 0)
      old=$(( lv_size ${scale."${opts.units}"} ))

      if (( ${new} == old )) ; then
        exit 0
      elif (( old == 0 )); then
        lvcreate ${vg} --name ${lv} ${sizeSpec} --stripes ${stripes}
      elif (( ${new} < old )) ; then
        echo "Cannot shrink volume $device from $old ${opts.units} to ${new} ${opts.units}" >&2
        exit 1
      else
        lvextend "$device" ${sizeSpec}
        resize2fs "$device"
      fi
    '';

  createVG = vg: pv: pkgs.writeBashScript "raid0-create-vg-${vg}" ''
    set -eu
    for pv in ${toString pv}; do
      type=$(blkid -p -s TYPE -o value "$pv" || true)
      if [ "$type" != LVM2_member ]; then
        pvcreate "$pv"
        if ! vgs ${vg}; then
          vgcreate ${vg} "$pv"
        else
          vgextend ${vg} "$pv"
        fi
      fi
    done
  '';

  mkRaidService = vg: opts:
    let
      ExecStart = pkgs.writeBashScript "raid0-${vg}" ''
        set -eu
        ${createVG vg opts.physical}
        ${concatStringsSep "\n" (
          mapAttrsToList (v: s:
            "${createLV vg (baseNameOf v) s opts}")
            opts.fileSystems
         )}
        vgchange -ay ${vg}
        udevadm trigger --action=add
      '';

    in nameValuePair "raid0-${vg}" rec {
      wantedBy = map (v: "dev-${vg}-${baseNameOf v}.device") (attrNames opts.fileSystems);
      requires = map (pv: replaceStrings ["/"] ["-"] (removePrefix "/" pv) + ".device") opts.physical;
      after = requires;
      before = wantedBy;
      unitConfig.DefaultDependencies = false;
      path = with pkgs; [ utillinux lvm2 e2fsprogs ];
      serviceConfig = {
        inherit ExecStart;
        RemainAfterExit = true;
        Type = "oneshot";
      };
    };

in {
  options.nixsap.system = {
    lvm.raid0 = mkOption {
      description = "Set of LVM2 volume groups";
      default = {};
      type = attrsOf (submodule {
        options = {
          stripes = mkOption {
            description = "Number of stripes";
            type = int;
            example = 2;
          };
          physical = mkOption {
            description = "List of physical devices (must be even for stripes)";
            example = [ "/dev/sdb" "/dev/sdc" ];
            type = listOf path;
          };
          fileSystems = mkOption {
            description = "Filesystems and their sizes";
            type = attrsOf int;
            example = { "/mariadb/db" = 100; };
          };
          units = mkOption {
            description = "Units of size";
            type = enum [ "%" "m" "g" "t"  "M" "G" "T"];
          };
        };
      });
    };
  };

  config = {
    systemd.services = mapAttrs' mkRaidService groups;

    fileSystems = foldl (a: b: a//b) {} (
      mapAttrsToList (vg: opts: genAttrs (attrNames opts.fileSystems)
        (fs: {
          fsType = "ext4";
          autoFormat = true;
          device = "/dev/${vg}/${baseNameOf fs}";
        })
      ) groups
    );
  };
}

