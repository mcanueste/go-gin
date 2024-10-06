{
  description = "Go API Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ {
    nixpkgs,
    flake-parts,
    ...
  }:
  # FIXME: Can remove this part until `flake-parts`.
    {
      templates.default = {
        description = "Go API Template with Gin";
        path = ./.;
      };
    }
    // flake-parts.lib.mkFlake {inherit inputs;} {
      systems = nixpkgs.lib.systems.flakeExposed;

      perSystem = {
        self',
        inputs',
        system,
        pkgs,
        config,
        ...
      }: let
        # FIXME: Change the project name, and version is you need a specific one instead of commit sha.
        name = "go-api";
        version = self'.rev or "dirty";
      in {
        packages.default = pkgs.buildGoModule {
          pname = name;
          inherit version;
          src = ./.;
          vendorSha256 = pkgs.lib.fakeSha256;
        };

        packages.docker = pkgs.dockerTools.buildImage {
          inherit name;
          tag = version;
          created = "now";
          copyToRoot = pkgs.buildEnv {
            name = "image-root";
            paths = [
              self'.packages.default
            ];
            pathsToLink = ["/bin"];
          };
          config = {
            Cmd = ["/bin/go-api"];
            Env = [
              "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              "PATH=/bin/"
            ];
          };
        };

        devShells.default = pkgs.mkShell {
          inherit name;
          buildInputs = [
            pkgs.go
            pkgs.golangci-lint
            # FIXME: Add more tools if needed.
          ];

          # Run on each venv activation.
          postShellHook = ''
            unset SOURCE_DATE_EPOCH
            export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$NIX_LD_LIBRARY_PATH"
          '';
        };
      };
    };
}
