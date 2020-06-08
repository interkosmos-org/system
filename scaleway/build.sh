#!/usr/bin/env bash

# definitions
image_name="interkosmos-20.03"
image_arch="x86_64"
server_uuid="8DB67A50-B0FD-4AFE-9C8F-DC0615731294"
server_name="interkosmos-build+$server_uuid"
SECONDS=0

# install dependencies
apk add openssh-client wget jq libressl curl || exit 1

# install scaleway cli
wget -q --show-progress -O /usr/bin/scw 'https://github.com/scaleway/scaleway-cli/releases/download/v2.0.0-beta.4/scw-2-0-0-beta-4-linux-x86_64'
chmod a+x /usr/bin/scw
mkdir -p /root/.config/scw
cp /tmp/interkosmos/scaleway/config.yaml /root/.config/scw/config.yaml
[ -f "/root/.config/scw/config.yaml" ] || echo "exit 1"

# delete remnant servers
scw instance server list name=$server_name | tail -n +2 | while read line; do
  remnant_server_id="$(echo $line | awk '{print $1}')"
  echo "remnant server id = $remnant_server_id"
  [[ $remnant_server_id == "" ]] || echo -ne "deleting server ... " && scw instance server delete $remnant_server_id with-volumes=all with-ip=true force-shutdown=true
done

# generate ssh key
rm -f /tmp/{buildkey,buildkey.pub}
ssh-keygen -o -a 100 -t ed25519 -f /tmp/buildkey -C 'build@interkosmos.org' -q -N ""
buildkey="AUTHORIZED_KEY=ssh-ed25519_$(cat /tmp/buildkey.pub | awk '{print $2}')"
[[ $buildkey == "" ]] && exit 1 || echo $buildkey

# create build server
server=$(scw instance server create -w stopped=false type=DEV1-L image=ubuntu_focal root-volume=local:75GB additional-volumes.0=local:5GB tags.0="$buildkey" name="$server_name" -o json)
server_id=$(echo $server | jq -r .id)
server_public_ip=$(echo $server | jq -r .public_ip.address)
[[ $server_public_ip == "" ]] && exit 1 || echo "server id = \"$server_id\" server ip = \"$server_public_ip\""

# define ssh transport
transport="ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -l root -i /tmp/buildkey $server_public_ip"

# wait for ssh transport
until $transport echo 'ping'; do echo "retrying..." && sleep 5; done
cat /root/.ssh/known_hosts | grep $server_public_ip || exit 1

# configure build server
$transport apt update
$transport apt install -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confnew -y bzip2 parted dosfstools sudo

# partition build server
$transport parted /dev/vdb -s -- mklabel gpt
$transport parted /dev/vdb -- mkpart primary 512MiB 100%
$transport parted /dev/vdb -- mkpart ESP fat32 1MiB 512MiB
$transport parted /dev/vdb -- set 2 boot on
$transport partprobe
$transport mkfs.ext4 -L interkosmos /dev/vdb1
$transport mkfs.fat -F 32 -n boot /dev/vdb2
$transport mount /dev/disk/by-label/interkosmos /mnt
$transport mkdir -p /mnt/boot
$transport mount /dev/disk/by-label/boot /mnt/boot || exit 1

# transfer nixos/interkosmos configuration
$transport mkdir -p /mnt/etc/nixos
scp -o ConnectTimeout=2 -o StrictHostKeyChecking=no -i /tmp/buildkey -r /tmp/interkosmos/scaleway/*.nix root@$server_public_ip:/mnt/etc/nixos/
scp -o ConnectTimeout=2 -o StrictHostKeyChecking=no -i /tmp/buildkey -r /tmp/interkosmos/interkosmos root@$server_public_ip:/mnt/etc/nixos/
$transport cat /mnt/etc/nixos/interkosmos/default.nix || exit 1

# install nixos/interkosmos
$transport /bin/bash <<EOT
  groupadd -g 30000 nixbld
  useradd -u 30000 -g nixbld -G nixbld nixbld
  echo "root ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/10-root
  curl https://nixos.org/nix/install | sh
  source "/root/.nix-profile/etc/profile.d/nix.sh"
  nix-channel --add "https://nixos.org/channels/nixos-20.03" nixos
  nix-channel --remove nixpkgs
  nix-channel --update
  export NIX_PATH="nixpkgs=/root/.nix-defexpr/channels/nixos"
  nix-env -iE '_: with import <nixpkgs/nixos> { configuration = {}; }; config.system.build.nixos-install'
  nixos-install --no-root-passwd --root /mnt || exit 1
EOT

# stop server
scw instance server stop -w $server_id || exit 1

# create snapshot
server_volume_id=$(echo $server | jq -r '.volumes."1".id')
server_snapshot=$(scw instance snapshot create volume-id="$server_volume_id" name="$image_name" -o json)
server_snapshot_id=$(echo $server_snapshot | jq -r '.snapshot.id')
echo $server_snapshot_id || exit 1

# create image
until scw instance image create public=false snapshot-id=$server_snapshot_id arch=$image_arch name=$image_name; do echo "retrying..." && sleep 5; done

# delete server 
scw instance server delete $server_id with-volumes=all with-ip=true force-shutdown=true || exit 1

# build finished
duration=$SECONDS
echo
echo "build finished at $(date)"
echo "image built as '$image_name' on scaleway in $(($duration / 60))m $(($duration % 60))s!"
