#!/usr/bin/env bash

source mission/mission.sh

SECONDS=0

mission "update nixos channel"
  phase nix-channel --update

mission "build nixos image"
  phase nix-build '<nixpkgs/nixos>' -A config.system.build.isoImage -I nixos-config=/tmp/interkosmos/iso/iso.nix

mission "extract interkosmos image"
  phase mkdir -p /artifacts/interkosmos-iso
  phase cd /tmp/interkosmos/result/ && cp -vrf ./* /artifacts/interkosmos-iso/

duration=$SECONDS
echo "iso image built in $(($duration / 60))m $(($duration % 60))s!"

