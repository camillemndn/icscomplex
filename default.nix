let
  inputs = import ./lon.nix;
  system = "x86_64-linux";

  pkgs = import inputs.nixpkgs {
    inherit system;
    overlays = [
      (_: prev: {
        quarto =
          (prev.quarto.override {
            pandoc = prev.stdenvNoCC.mkDerivation (finalAttrs: {
              pname = "pandoc-cli";
              version = "3.10";
              src = prev.fetchurl {
                url = "https://github.com/jgm/pandoc/releases/download/${finalAttrs.version}/pandoc-${finalAttrs.version}-linux-amd64.tar.gz";
                hash = "sha256-4PivYtDyZ9IrqlvO/m1d2joJfMxg3nlLdZ/gMVmSMkQ=";
              };
              nativeBuildInputs = [ pkgs.autoPatchelfHook ];
              buildInputs = with prev; [
                stdenv.cc.cc.lib
                zlib
              ];
              installPhase = ''
                install -Dm755 bin/pandoc $out/bin/pandoc
                ln -s pandoc $out/bin/pandoc-cli
              '';
              meta.mainProgram = "pandoc";
            });
          }).overrideAttrs
            (
              finalAttrs: old: {
                version = "1.10.18";

                src = prev.fetchurl {
                  url = "https://github.com/quarto-dev/quarto-cli/releases/download/v${finalAttrs.version}/quarto-${finalAttrs.version}-linux-amd64.tar.gz";
                  hash = "sha256-r60HG1vSLALy0wBpV0MYnTZQ4FN6Uwc+ZUtjDP8rDHM=";
                };

                patches = (old.patches or [ ]) ++ [
                  ./mermaid-pdf.patch
                  # The ipynb renderer nests a Blocks preamble of layout-ncol figures, which
                  # pandoc 3.10 rejects in pandoc.Div (manuscript notebook output).
                  ./quarto-ipynb-layout.patch
                ];
              }
            );

        rPackages = prev.rPackages.override {
          overrides = with prev.rPackages; {
            dda = buildRPackage {
              name = "dda";
              src = pkgs.fetchFromGitHub {
                owner = "camillemndn";
                repo = "dda";
                rev = "v0.0.0.9021";
                hash = "sha256-aIlpJ2Mea0huPTjvzVbaaJIpBJq/hSM8moLxgBCpU7g=";
              };
              nativeBuildInputs = [
                pkgs.cargo
                pkgs.rustc
              ];
              propagatedBuildInputs = [
                dplyr
                fda
                ggplot2
                tidyr
              ];
            };

            ICSFun = buildRPackage {
              name = "ICSFun";
              src = pkgs.fetchFromGitHub {
                owner = "camillemndn";
                repo = "ICSFun";
                rev = "v0.0.0.9001";
                hash = "sha256-QqLdXgslGIOydVt1hQkvlFKloAJ0agG8f8sg7TZ4I0o=";
              };
              propagatedBuildInputs = [
                compositions
                fda
                GGally
                ggplot2
                gridExtra
                ICS
                ICSOutlier
                memoise
              ];
            };

            tidyfun = buildRPackage {
              name = "tidyfun";
              src = pkgs.fetchFromGitHub {
                owner = "tidyfun";
                repo = "tidyfun";
                rev = "d9c4adbd2ff1179cc1f37cb34464e42f5fe2739a";
                hash = "sha256-uSpwjZZ2+GZZpNn5PFwHfRal7o5MTd5rST8jKd6Kpdo=";
              };
              propagatedBuildInputs = [
                tf
                dplyr
                GGally
                ggplot2
                pillar
                purrr
                tibble
                tidyr
                tidyselect
              ];
            };
          };
        };
      })
      (_: prev: {
        panache = prev.panache.overrideAttrs (
          finalAttrs: _: {
            version = "3.10.0";

            src = prev.fetchFromGitHub {
              owner = "jolars";
              repo = "panache";
              tag = "v${finalAttrs.version}";
              hash = "sha256-13v2J7qRgkX55vjFt0daU26J/IhmECCr1H0fVEW72rk=";
            };

            cargoDeps = prev.rustPlatform.fetchCargoVendor {
              inherit (finalAttrs) src;
              name = "panache-${finalAttrs.version}";
              hash = "sha256-D8SfoPjfIHnrvjYG6lJbqAHL1jkAI5st2105OP9md6s=";
            };
          }
        );
      })
    ];
  };

  r-deps = with pkgs.rPackages; [
    dda
    DeBoinR
    fdaoutlier
    ICSFun
    sf
    tf
    tidyfun
    tidyverse

    devtools
    languageserver
    quarto
  ];

  pre-commit-hook = (import inputs.git-hooks).run {
    src = ./.;

    # git-hooks.nix resolves hook binaries from its own nixpkgs, so pin the
    # panache hooks to the same derivation as the shell.
    tools = { inherit (pkgs) panache; };

    hooks = {
      statix.enable = true;
      deadnix.enable = true;
      rfc101 = {
        enable = true;
        name = "RFC-101 formatting";
        entry = "${pkgs.lib.getExe pkgs.nixfmt}";
        files = "\\.nix$";
      };
      commitizen.enable = true;
      panache-format = {
        enable = true;
        files = "\\.(qmd|Rmd)$";
      };
      panache-lint = {
        enable = true;
        files = "\\.(qmd|Rmd)$";
      };
    };
  };
in

rec {
  devShells.default = pkgs.mkShell {
    nativeBuildInputs = with pkgs; [
      lon
      (quarto.override { extraRPackages = r-deps; })
      (rWrapper.override { packages = r-deps; })
      texliveFull
      librsvg
      panache
      air-formatter
    ];
    shellHook = ''
      ${pre-commit-hook.shellHook}
    '';
  };

  packages.x86_64-linux = {
    website = pkgs.callPackage (
      {
        stdenv,
        image_optim,
        quarto,
        texliveFull,
        which,
        ...
      }:

      stdenv.mkDerivation {
        name = "camillemondon-icscomplex";
        src = builtins.fetchGit ./.;

        buildInputs = [
          image_optim
          (quarto.override { extraRPackages = r-deps; })
          texliveFull
          which
        ];

        HOME = ".";

        buildPhase = ''
          quarto render index.qmd
          image_optim --recursive _manuscript
        '';

        installPhase = ''
          cp -r _manuscript $out
        '';
      }
    ) { };
  };

  checks.default = {
    inherit packages;
  };
}
