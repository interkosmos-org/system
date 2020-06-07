#!/usr/bin/env bash

source mission/mission.sh

image_name="interkosmos-20.03"
image_arch="x86_64"

server_uuid="0981FE9A-10D4-4B26-89D6-62122BCC1175"
server_name="interkosmos-build+$server_uuid"

SECONDS=0

mission "install scaleway cli"
  phase apk add openssh-client wget jq libressl curl
  phase wget -q --show-progress -O /usr/bin/scw 'https://github.com/scaleway/scaleway-cli/releases/download/v2.0.0-beta.3/scw-2-0-0-beta-3-linux-x86_64'
  phase chmod a+x /usr/bin/scw
  phase mkdir -p /root/.config/scw
  phase tee -a /root/.config/scw/config.yaml <<EOT
access_key: $SCALEWAY_ACCESS_KEY
secret_key: $SCALEWAY_SECRET_KEY
default_organization_id: $SCALEWAY_ORGANIZATION
default_region: $SCALEWAY_REGION
default_zone: $SCALEWAY_ZONE
EOT

mission "delete remnant servers"
  scw instance server list name=$server_name | tail -n +2 | while read line; do
    remnant_server_id="$(echo $line | awk '{print $1}')"
    phase echo $remnant_server_id
    [[ $remnant_server_id == "" ]] || phase scw instance server delete $remnant_server_id with-volumes=all with-ip=true force-shutdown=true
  done

mission "generate ed25519 key"
  phase rm -f /tmp/{buildkey,buildkey.pub}
  phase ssh-keygen -o -a 100 -t ed25519 -f /tmp/buildkey -C 'build@interkosmos.org' -q -N ''
  buildkey="AUTHORIZED_KEY=ssh-ed25519_$(cat /tmp/buildkey.pub | awk '{print $2}')"
  phase echo $buildkey

mission "start server"
  server=$(scw instance server create -w stopped=false type=DEV1-M image=ubuntu_focal root-volume=local:38GB additional-volumes.0=local:2GB tags.0="$buildkey" name=$server_name -o json)
  server_id=$(echo $server | jq -r .id)
  server_public_ip=$(echo $server | jq -r .public_ip.address)
  phase echo "$server_id [$server_public_ip]"

mission "define exo phase"
  exo="ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -l root -i /tmp/buildkey $server_public_ip"
  phase echo $exo

mission "wait for exo phase"
  until $exo echo 'ping'; do echo "retrying..." && sleep 5; done
  phase cat /root/.ssh/known_hosts

mission "configure build environment"
  phase $exo apt update
  phase $exo "apt install -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confnew -y bzip2 parted dosfstools sudo"

mission "partition future image"
  phase $exo parted /dev/vdb -s -- mklabel gpt
  phase $exo parted /dev/vdb -- mkpart primary 512MiB 100%
  phase $exo parted /dev/vdb -- mkpart ESP fat32 1MiB 512MiB
  phase $exo parted /dev/vdb -- set 2 boot on
  phase $exo partprobe
  phase $exo mkfs.ext4 -L nixos /dev/vdb1
  phase $exo mkfs.fat -F 32 -n boot /dev/vdb2
  phase $exo mount /dev/disk/by-label/nixos /mnt
  phase $exo mkdir -p /mnt/boot
  phase $exo mount /dev/disk/by-label/boot /mnt/boot

mission "transfer nixos configuration"
  phase $exo mkdir -p /mnt/etc/nixos
  phase scp -o ConnectTimeout=2 -o StrictHostKeyChecking=no -i /tmp/buildkey -r /tmp/interkosmos/scaleway/*.nix root@$server_public_ip:/mnt/etc/nixos/

mission "install nixos"
  phase $exo tee -a /etc/sudoers.d/10-root <<EOT
root ALL=(ALL) NOPASSWD:ALL
EOT
  phase $exo groupadd -g 30000 nixbld
  phase $exo useradd -u 30000 -g nixbld -G nixbld nixbld
  phase $exo /bin/bash <<EOT
curl https://nixos.org/nix/install | sh
source "/root/.nix-profile/etc/profile.d/nix.sh"
nix-channel --add "https://nixos.org/channels/nixos-20.03" nixos
nix-channel --remove nixpkgs
nix-channel --update
export NIX_PATH="nixpkgs=/root/.nix-defexpr/channels/nixos"
nix-env -iE '_: with import <nixpkgs/nixos> { configuration = {}; }; config.system.build.nixos-install'
nixos-install --root /mnt --no-root-passwd
EOT

mission "stop server"
  phase scw instance server stop -w $server_id

mission "create snapshot"
  server_volume_id=$(echo $server | jq -r '.volumes."1".id')
  phase echo $server_volume_id
  server_snapshot=$(scw instance snapshot create volume-id="$server_volume_id" name="$image_name" -o json)
  phase echo $server_snapshot
  server_snapshot_id=$(echo $server_snapshot | jq -r '.snapshot.id')
  phase echo $server_snapshot_id

mission "create image"
  until scw instance image create public=false snapshot-id=$server_snapshot_id arch=$image_arch name=$image_name; do echo "retrying..." && sleep 5; done

mission "delete server"
  phase scw instance server delete $server_id with-volumes=all with-ip=true force-shutdown=true

duration=$SECONDS
echo "image built as '$image_name' on scaleway in $(($duration / 60))m $(($duration % 60))s!"
