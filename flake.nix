{
  description = "NixOS Flake configuration for nixos-mediacenter";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    soltros-nixpkgs = {
      url = "github:soltros/soltros_nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, soltros-nixpkgs, ... }@inputs: {
    nixosConfigurations.nixos-mediacenter = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ config, pkgs, lib, modulesPath, ... }: {
          imports = [
            (modulesPath + "/installer/scan/not-detected.nix")
          ];

          nixpkgs.overlays = [
            soltros-nixpkgs.overlays.default
          ];

          # Hardware & Bootloader
          boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
          boot.initrd.kernelModules = [ ];
          boot.kernelModules = [ "kvm-intel" ];
          boot.extraModulePackages = [ ];

          fileSystems."/" = {
            device = "/dev/disk/by-uuid/2e1b7016-c5cc-46ff-8a55-d944da55882d";
            fsType = "btrfs";
          };

          fileSystems."/boot" = {
            device = "/dev/disk/by-uuid/D9E4-D4BC";
            fsType = "vfat";
            options = [ "fmask=0022" "dmask=0022" ];
          };

          swapDevices = [
            {
              device = "/var/lib/swapfile";
              size = 4 * 1024; # 4GB swapfile
            }
          ];

          nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
          hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;

          # Unfree packages
          nixpkgs.config.allowUnfree = true;

          # Networking & Hostname
          networking.hostName = "nixos-mediacenter";
          networking.networkmanager.enable = true;
          networking.firewall.checkReversePath = "loose";

          # Timezone and Localization
          time.timeZone = "America/Detroit";
          i18n.defaultLocale = "en_US.UTF-8";
          i18n.extraLocaleSettings = {
            LC_ADDRESS = "en_US.UTF-8";
            LC_IDENTIFICATION = "en_US.UTF-8";
            LC_MEASUREMENT = "en_US.UTF-8";
            LC_MONETARY = "en_US.UTF-8";
            LC_NAME = "en_US.UTF-8";
            LC_NUMERIC = "en_US.UTF-8";
            LC_PAPER = "en_US.UTF-8";
            LC_TELEPHONE = "en_US.UTF-8";
            LC_TIME = "en_US.UTF-8";
          };

          # Desktop Environment (KDE Plasma 6 / X11)
          services.xserver.enable = true;
          services.displayManager.sddm.enable = true;
          services.displayManager.defaultSession = "plasma";
          services.displayManager.sddm.wayland.enable = false;
          services.desktopManager.plasma6.enable = true;
          environment.plasma6.excludePackages = with pkgs.kdePackages; [ ];

          # Audio (Pipewire)
          services.pulseaudio.enable = false;
          security.rtkit.enable = true;
          services.pipewire = {
            enable = true;
            alsa.enable = true;
            alsa.support32Bit = true;
            pulse.enable = true;
          };

          # Bluetooth
          hardware.bluetooth.enable = true;
          hardware.bluetooth.powerOnBoot = true;

          # Flatpak & Portals
          services.flatpak.enable = true;
          xdg.portal.enable = true;

          # Services (SSH, Tailscale, Fstrim)
          services.openssh.enable = true;
          services.tailscale.enable = true;
          services.fstrim = {
            enable = true;
            interval = "weekly";
          };

          # Programs & Security
          programs.gamemode = {
            enable = true;
            settings = {
              custom = {
                start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
                end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
              };
            };
          };

          programs.gnupg.agent = {
            enable = true;
            enableSSHSupport = true;
            pinentryPackage = lib.mkForce pkgs.pinentry-qt;
          };

          # Nix Flakes Support
          nix.settings.experimental-features = [ "nix-command" "flakes" ];

          # User Account
          users.users.derrik = {
            isNormalUser = true;
            description = "Derrik Diener";
            extraGroups = [ "networkmanager" "wheel" "gamemode" ];
          };

          # System Packages
          environment.systemPackages = with pkgs; [
            # Base tools & apps
            wget
            git
            screen
            unzip
            ncdu
            mlocate
            btrfs-progs
            ntfs3g

            # Applications from derriks-apps.nix
            bitwarden-desktop
            python312
            appimage-run
            papirus-icon-theme
            libreoffice-qt
            spotify
            tailscale
            vlc
            gimp
            zettlr
            winetricks
            wine-staging
            pavucontrol
            distrobox
            geany
            thunderbird
            flatpak
            discord
            kopia
            telegram-desktop
            nodejs
            pipx
            python311Packages.pip
            caffeine-ng
            php
            adapta-gtk-theme
            yt-dlp
            pamixer
            gthumb
            lxrandr
            pinta
            virt-manager
          ];

          # NixOS State Version
          system.stateVersion = "26.05";
        })
      ];
    };
  };
}
