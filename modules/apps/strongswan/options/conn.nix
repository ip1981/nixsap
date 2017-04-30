{ config, lib, ... }:

let

  inherit (lib) foldl attrNames head;
  inherit (lib.types) int str path either listOf enum;
  inherit (import ./lib.nix lib) boolean boolOr default optional;

  leftright = map
    (a: let n = head (attrNames a);
      in {
        "left${n}" = a."${n}";
        "right${n}" = a."${n}";
      })
  [
    { allowany   = optional boolean; }
    { auth       = optional str; }
    { auth2      = optional str; }
    { ca         = optional str; }
    { ca2        = optional str; }
    { cert       = optional path; }
    { cert2      = optional path; }
    { dns        = optional (listOf str); }
    { firewall   = optional boolean; }
    { groups     = optional (listOf str); }
    { hostaccess = optional boolean; }
    { id         = optional str; }
    { id2        = optional str; }
    { policy     = optional (listOf str); }
    { sendcert   = optional (boolOr [ "never" "always" "ifasked" ]); }
    { sigkey     = optional str; }
    { sourceip   = optional str; }
    { subnet     = optional (listOf str); }
    { updown     = optional path; }
  ];

  conn = leftright ++ [
    { aaa_identity   = optional str; }
    { aggressive     = optional boolean; }
    { ah             = optional (listOf str); }
    { also           = optional str; }
    { authby         = optional (enum [ "pubkey" "rsasig" "ecdsasig" "psk" "secret" "xauthrsasig" "xauthpsk" "never" ]); }
    { auto           = optional (enum [ "ignore" "add" "route" "start" ]); }
    { closeaction    = optional (enum [ "none" "clear" "hold" "restart" ]); }
    { compress       = optional boolean; }
    { dpdaction      = optional (enum [ "none" "clear" "hold" "restart" ]); }
    { dpddelay       = optional int; }
    { dpdtimeout     = optional int; }
    { eap_identity   = optional str; }
    { esp            = optional (listOf str); }
    { forceencaps    = optional boolean; }
    { fragmentation  = optional (boolOr [ "force" ]); }
    { ike            = optional (listOf str); }
    { ikedscp        = optional str; }
    { ikelifetime    = optional int; }
    { inactivity     = optional int; }
    { installpolicy  = optional boolean; }
    { keyexchange    = optional (enum [ "ikev1" "ikev2" ]); }
    { keyingtries    = optional (either int (enum [ "%forever" ])); }
    { left           = optional str; }
    { lifebytes      = optional int; }
    { lifepackets    = optional int; }
    { lifetime       = optional int; }
    { marginbytes    = optional int; }
    { marginpackets  = optional int; }
    { mark           = optional str; }
    { mark_in        = optional str; }
    { mark_out       = optional str; }
    { me_peerid      = optional str; }
    { mediated_by    = optional str; }
    { mediation      = optional boolean; }
    { mobike         = optional boolean; }
    { modeconfig     = optional (enum [ "push" "pull" ]); }
    { reauth         = optional boolean; }
    { rekey          = optional boolean; }
    { rekeyfuzz      = optional int; }
    { replay_window  = optional int; }
    { reqid          = optional int; }
    { right          = optional str; }
    { tfc            = optional (either int (enum [ "%mtu" ])); }
    { type           = optional (enum [ "tunnel" "transport" "transport_proxy" "passthrough" "drop" ]); }
    { xauth          = optional (enum [ "client" "server" ]); }
    { xauth_identity = optional str; }
  ];

in {
  options = foldl (a: b: a//b) {} conn;
}
