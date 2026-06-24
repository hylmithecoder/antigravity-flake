{
  description = "Google Antigravity - Next-generation agentic IDE (Nix package)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in {
        packages = {
          default = pkgs.callPackage ./package.nix {};
          google-antigravity = pkgs.callPackage ./package.nix {};
          google-antigravity-no-fhs = pkgs.callPackage ./package.nix {useFHS = false;};
        };

        # Development shell
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nix
            git
            curl
            jq
          ];

          shellHook = ''
            echo "Google Antigravity 2.1.1 Flake Environment"
          '';
        };
      }
    )
    // {
      # Version information
      version = "2.1.1-6123990880747520";

      # Overlay for easy integration into configurations
      overlays.default = final: prev: {
        google-antigravity = final.callPackage ./package.nix {};
        google-antigravity-no-fhs = final.callPackage ./package.nix {useFHS = false;};
      };
    };
}
