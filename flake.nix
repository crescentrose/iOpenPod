{
  description = "Open source iPod sync tool. Use your iPod on any OS without iTunes";

  inputs = {
    pyproject-nix = {
      url = "github:nix-community/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, pyproject-nix, ... }:
    let
      inherit (nixpkgs) lib;
      systems = lib.intersectLists lib.systems.flakeExposed lib.platforms.linux;
      forAllSystems = lib.genAttrs systems;
      nixpkgsFor = forAllSystems (system: nixpkgs.legacyPackages.${system});

      project = pyproject-nix.lib.project.loadUVPyproject {
        projectRoot = ./.;
      };

      iOpenPod-package =
        {
          python,
          udevCheckHook,
          ffmpeg,
          chromaprint,
        }:
        let
          attrs = project.renderers.buildPythonPackage { inherit python; };
        in
        python.pkgs.buildPythonApplication (
          attrs
          // {
            patchPhase = ''
                sed -i "s/Exec=iOpenPod/Exec=iopenpod/" flatpak/io.github.therealsavi.iOpenPod.desktop
            '';

            makeWrapperArgs = [
              "--prefix"
              "PATH"
              ":"
              "${lib.makeBinPath [ ffmpeg chromaprint ]}"
            ];
            nativeInstallCheckInputs = [ udevCheckHook ];
            postInstall = ''
              # TODO: Add some beautiful icons here :)
              #
              # install -D icons/icon.png $out/share/icons/hicolor/128x128/apps/io.github.therealsavi.iOpenPod.desktop.png

              install -D scripts/50-ipod.rules $out/lib/udev/rules.d/50-ipod.rules
              install -D flatpak/io.github.therealsavi.iOpenPod.desktop $out/share/applications/iOpenPod.desktop
            '';
          }
        );
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor.${system};
          python = pkgs.python3;

          iOpenPod = pkgs.callPackage iOpenPod-package { inherit python; };
        in
        {
          default = iOpenPod;
        }
      );

      nixosModules.default = {config, lib, pkgs, ...}:
        with lib;
        let cfg = config.programs.iOpenPod;
        in {
          options.programs.iOpenPod = {
            enable = mkEnableOption "Enables the iOpenPod program";
          };

          config = mkIf cfg.enable {
            environment.systemPackages = [ self.packages.${pkgs.system}.default ];
            services.udev.packages = [ self.packages.${pkgs.system}.default ];
          };
        };
    };
}
