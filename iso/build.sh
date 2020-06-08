#!/usr/bin/env bash

SECONDS=0

nix-channel --update
nix-build '<nixpkgs/nixos>' -A config.system.build.isoImage -I nixos-config=/tmp/interkosmos/iso/iso.nix
mkdir -p /artifacts/interkosmos-iso
cd /tmp/interkosmos/result/ && \
cp -vrf ./* /artifacts/interkosmos-iso/

duration=$SECONDS
echo
echo "build finished at $(date)"
echo "iso image built in $(($duration / 60))m $(($duration % 60))s!"
