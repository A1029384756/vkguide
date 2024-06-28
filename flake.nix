{
  description = "Odin Devshell";

  inputs = {
    nixpkgs.url      = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url  = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        nativeBuildInputs = with pkgs; [ 
          odin
          ols
          gcc12
          cmake
          vulkan-tools
          glslls
          #put your env dependencies here
        ];
        buildInputs = with pkgs; [
          SDL2
          vulkan-loader
          vulkan-headers
          #put your runtime and build dependencies here
        ];

        build_command = pkgs.writeShellApplication {
          name = "build";
          runtimeInputs = nativeBuildInputs ++ buildInputs;
          text = ''
            odin build . -extra-linker-flags:"-lstdc++ -lvulkan" -show-timings
          '';
        };
        run_command = pkgs.writeShellApplication {
          name = "run";
          runtimeInputs = nativeBuildInputs ++ buildInputs;
          text = ''
            odin run . -extra-linker-flags:"-lstdc++ -lvulkan" -show-timings
          '';
        };
      in
      with pkgs;
      {
        devShells.default = mkShell {
          packages = nativeBuildInputs ++ buildInputs ++ [ build_command run_command ];
          LD_LIBRARY_PATH = "${lib.makeLibraryPath buildInputs}";
        };
      }
    );
}
