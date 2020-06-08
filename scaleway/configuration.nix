{ config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./scaleway-configuration.nix
    ./interkosmos
  ];
  system.stateVersion = "20.03";
}
