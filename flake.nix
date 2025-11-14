{
  description = "Easily package your Maven Java application with the Nix package manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      utils,
    }:
    let
      localOverlay = import ./overlay.nix;

      pkgsForSystem =
        system:
        import nixpkgs {
          overlays = [
            localOverlay
          ];
          inherit system;
        };
    in
    utils.lib.eachSystem utils.lib.defaultSystems (system: rec {
      legacyPackages = pkgsForSystem system;

      packages = utils.lib.flattenTree {
        inherit (legacyPackages)
          mvn2nix
          mvn2nix-bootstrap
          buildMavenRepository
          buildMavenRepositoryFromLockFile
          ;
      };
      defaultPackage = packages.mvn2nix;
      apps.mvn2nix = utils.lib.mkApp { drv = packages.mvn2nix; };

      devShells.default = legacyPackages.mkShell (
        let
          _jdk = legacyPackages.jdk21_headless;
          gh-md-toc-source = legacyPackages.fetchurl {
            url = "https://raw.githubusercontent.com/ekalinin/github-markdown-toc/master/gh-md-toc";
            sha256 = "sha256-nBL6/iwgHLu+r+xXe73F9FxYtTWM9mOkAj6m7Jp1yBw=";
          };

          gh-md-toc = legacyPackages.writeScriptBin "gh-md-toc" ''
            ${legacyPackages.runtimeShell} ${gh-md-toc-source} "$@"
          '';
        in
        {
          name = "mvn2nix-shell";

          buildInputs = with legacyPackages; [
            _jdk
            maven
            gh-md-toc
            git
          ];

          M2_HOME = legacyPackages.maven;
          shellHook = "";
        }
      );
    })
    // {
      overlay = localOverlay;
    };
}
