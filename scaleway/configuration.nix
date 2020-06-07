{ config, pkgs, ... }:
{
    imports = [
        ./hardware-configuration.nix
        ./scaleway-configuration.nix
    ];
    system.stateVersion = "20.03";
}

