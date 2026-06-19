let
  inputs = import ./lon.nix;
  system = "x86_64-linux";

  pkgs = import inputs.nixpkgs {
    inherit system;
    overlays = [
      (_: prev: {
        quarto = prev.quarto.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ./panel-layout.patch ];
        });

        rPackages = prev.rPackages.override {
          overrides = with prev.rPackages; {
            dda = buildRPackage {
              name = "dda";
              src = pkgs.fetchFromGitHub {
                owner = "camillemndn";
                repo = "dda";
                rev = "v0.0.0.9019";
                hash = "sha256-yCwR9+pEULJ4s6nseWIg/xSrE1wj1mXyvPaJLQF7hH8=";
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
                hash = "sha256-5hgcPy1l51Ifqnmh7ETjQ4YoF62b7XYhpW2KotUOM1U=";
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
