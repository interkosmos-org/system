{ config, pkgs, lib, ... }: {
  boot = {
    kernelPackages = pkgs.linuxPackages_latest_hardened;
    kernelModules = [ "virtio" "virtio_pci" "virtio_blk" ];
    kernel.sysctl = {
      "vm.swappiness" = 1;
      "vm.dirty_writeback_centisecs" = 1500;
    };
    blacklistedKernelModules = [
      "ax25"
      "netrom"
      "rose"
    ];
    cleanTmpDir = true;
    enableContainers = true;
  };

  # gitops container
  containers.gitops = {
    config = { config, pkgs, ... }: {
      system.stateVersion = "20.03";
      services.postgresql.enable = true;
      services.postgresql.package = pkgs.postgresql_9_6;
    };
  };

  system.nixos.label = "interkosmos";
  services.mingetty.greetingLine = with config; ''Interkosmos System ${system.nixos.release} (\m) - \l'';

  environment.etc.os-release.text = with config;
  ''
    NAME=Interkosmos
    ID=interkosmos
    VERSION="${system.nixos.version} (${system.nixos.codeName})"
    VERSION_CODENAME=${lib.toLower system.nixos.codeName}
    VERSION_ID="${system.nixos.version}"
    PRETTY_NAME="Interkosmos ${system.nixos.release} (${system.nixos.codeName})"
    LOGO="nix-snowflake"
    HOME_URL="https://interkosmos.org/"
    DOCUMENTATION_URL="https://nixos.org/learn.html"
    SUPPORT_URL="https://nixos.org/community.html"
    BUG_REPORT_URL="https://github.com/NixOS/nixpkgs/issues"
  '';

  # network
  networking = {
    hostName = "interkosmos";

    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
    };
  };
  
  # users
  users = {
    defaultUserShell = "${pkgs.zsh}/bin/zsh";
    motd = with config; ''

Welcome to Interkosmos!

  System   Interkosmos ${system.nixos.release} (NixOS ${system.nixos.version} ${system.nixos.codeName})
  Kernel   ${nixpkgs.localSystem.uname.system} ${boot.kernelPackages.kernel.version} ${nixpkgs.localSystem.config}
  Channel  ${system.defaultChannel}

    '';
  };

  # nix package management
  nix = {
    # garbage collection
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };

    # nix store optimization
    optimise = {
      automatic = true;
      dates = [ "daily" ];
    };

    autoOptimiseStore = true;

#    extraOptions = ''
#      binary-caches-parallel-connections = 20
#      connect-timeout = 10
#    '';
  };

  # allow unfree packages (for firmware)
  nixpkgs = {
    config.allowUnfree = true;
  };

  # disable nixos documentation, available online
  documentation.nixos.enable = false;

  security.rngd.enable = true;

  services = {
    openssh = {
      enable = true;
      allowSFTP = false;
      challengeResponseAuthentication = false;
    };

    ntp = {
      enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    wget
    neovim
    dnsutils
    tmux
    pciutils
    file
    gitFull
    git-crypt
    gnupg
    gnupg1compat
    which
    usbutils
    lsof
    psmisc
    htop
    binutils
    curl
    zsh
    libressl
    qemu_kvm
    qemu-utils
  ];

  environment.shellAliases = {
    "sudo" = "sudo ";
    "vim" = "nvim";
  };

  environment.variables = {
    EDITOR = "vim";
  };

  # update microcode
  hardware = {
    # TODO: detect cpu and enable accordingly
    cpu.intel.updateMicrocode = true;
    cpu.amd.updateMicrocode = true;
  };

  programs = {
    zsh = {
      enable = true;
      autosuggestions.enable = true;
      enableCompletion = true;
      syntaxHighlighting.enable = true;
    };
  };

  system = {
    stateVersion = "20.03";

    autoUpgrade = {
      enable = true;
      dates = "daily";
      channel = "https://nixos.org/channels/nixos-20.03";
    };
  };
}
