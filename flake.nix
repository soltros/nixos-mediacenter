{
  description = "NixOS Flake configuration for nixos-mediacenter";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    soltros-nixpkgs = {
      url = "github:soltros/soltros_nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, soltros-nixpkgs, antigravity-nix, ... }@inputs: {
    nixosConfigurations.nixos-mediacenter = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ config, pkgs, lib, modulesPath, ... }:
        let
          browserosVersion = "0.44.0.1";
          browserosSrc = pkgs.fetchurl {
            url = "https://github.com/browseros-ai/BrowserOS/releases/download/v${browserosVersion}/BrowserOS_v${browserosVersion}_x64.AppImage";
            hash = "sha256-ALnyVMnexYy48br9qbWaEbOZm7hJR9g39a9nYzbWXwo=";
          };
          browserosContents = pkgs.appimageTools.extract {
            pname = "browseros";
            version = browserosVersion;
            src = browserosSrc;
          };
          browseros = pkgs.appimageTools.wrapType2 {
            pname = "browseros";
            version = browserosVersion;
            src = browserosSrc;
            extraInstallCommands = ''
              install -m 444 -D ${browserosContents}/browseros.desktop -t $out/share/applications
              substituteInPlace $out/share/applications/browseros.desktop \
                --replace 'Exec=AppRun' 'Exec=browseros'
              cp -r ${browserosContents}/usr/share/icons $out/share
            '';
            meta = {
              description = "Open-source agentic AI web browser";
              homepage = "https://browseros.com/";
              downloadPage = "https://github.com/browseros-ai/BrowserOS/releases";
              license = pkgs.lib.licenses.agpl3Only;
              sourceProvenance = with pkgs.lib.sourceTypes; [ binaryNativeCode ];
              platforms = [ "x86_64-linux" ];
              mainProgram = "browseros";
            };
          };
        in {
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

          # Zsh & Starship Configuration
          programs.zsh = {
            enable = true;
            shellAliases = {
              nrb = "sudo nixos-rebuild switch --flake /home/derrik/nixos-mediacenter#$(cat /etc/hostname)";
              nrb-test = "sudo nixos-rebuild test --flake /home/derrik/nixos-mediacenter#$(cat /etc/hostname)";
              nrb-boot = "sudo nixos-rebuild boot --flake /home/derrik/nixos-mediacenter#$(cat /etc/hostname)";
              nfu = "sudo nix flake update --flake /home/derrik/nixos-mediacenter";
              nfu-rebuild = "cd /home/derrik/nixos-mediacenter && sudo ./deploy.sh";
              ngc = "sudo nix-collect-garbage -d";
              nix-search = "nix search nixpkgs";
              nix-lint = "nix flake check --flake /home/derrik/nixos-mediacenter";
              # Replacements for common utilities
              cat = "bat --paging=never";
              grep = "rg";
              find = "fd";
              df = "duf";
              ls = "eza --icons=auto";
              ll = "eza -la --icons=auto --git";
              tree = "eza --tree --icons=auto";
            };
            autosuggestions.enable = true;
            ohMyZsh = {
              enable = true;
              plugins = [ "git" "sudo" ];
            };
          };
          programs.starship.enable = true;

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
            chatgpt
            eza
            bat
            ripgrep
            fd
            vpn-manager
            duf
            flakebuilder
            waterfox
            browseros
            nixboutique
            antigravity-nix.packages.x86_64-linux.default
            antigravity-nix.packages.x86_64-linux.google-antigravity-ide
            antigravity-nix.packages.x86_64-linux.google-antigravity-cli
            wtype
            wl-clipboard
            ydotool
            dotool
            papirus-icon-theme
            zsh-autosuggestions

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
