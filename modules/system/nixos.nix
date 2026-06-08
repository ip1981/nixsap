{ config, lib, ...}:
{
  system.stateVersion = lib.mkDefault config.system.nixos.release;
}
