{ pkgs, variant, ... }:

let
  hardware_deps =
    with pkgs;
    if variant == "CUDA" || variant == "CUDA-BETA" then
      [
        cudaPackages.cudatoolkit
        xorg.libXi
        xorg.libXmu
        freeglut
        xorg.libXext
        xorg.libX11
        xorg.libXv
        xorg.libXrandr
        zlib

        # for xformers
        gcc
      ]
      ++ (if variant == "CUDA" then [ linuxPackages.nvidia_x11 ] else [ linuxPackages.nvidia_x11_beta ])
    else if variant == "ROCM" then
      [
        rocmPackages.rocm-runtime
        pciutils
      ]
    else if variant == "CPU" then
      [
      ]
    else
      throw "You need to specify which variant you want: CPU, ROCm, or CUDA.";
  variantLower = pkgs.lib.toLower variant;
  rocmIndexUrl = "https://download.pytorch.org/whl/rocm6.3";
  pythonForVenv = pkgs.python312;
in
pkgs.mkShell rec {
  name = "comfyui-shell";

  buildInputs =
    with pkgs;
    hardware_deps
    ++ [
      git # The program instantly crashes if git is not present, even if everything is already downloaded
      (python312.withPackages (
        p: with p; [
          pip
        ]
      ))
      stdenv.cc.cc.lib
      stdenv.cc
      ncurses5
      binutils
      gitRepo
      gnupg
      autoconf
      curl
      procps
      gnumake
      util-linux
      m4
      gperf
      unzip
      libGLU
      libGL
      glib
      zstd
    ];

  venvDir = ".venv-${variantLower}";

  LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath buildInputs;
  CUDA_PATH = pkgs.lib.optionalString (
    variant == "CUDA" || variant == "CUDA-BETA"
  ) pkgs.cudaPackages.cudatoolkit;
  EXTRA_LDFLAGS =
    pkgs.lib.optionalString (variant == "CUDA" || variant == "CUDA-BETA")
      "-L${
        (if variant == "CUDA" then pkgs.linuxPackages.nvidia_x11 else pkgs.linuxPackages.nvidia_x11_beta)
      }/lib";

  shellHook =
    ''
      VENV_PATH="${venvDir}"
      if [ ! -d "$VENV_PATH" ]; then
        echo "Creating Python virtualenv at $VENV_PATH"
        ${pythonForVenv}/bin/python -m venv "$VENV_PATH"
      fi
      # shellcheck disable=SC1090
      source "$VENV_PATH/bin/activate"
      export PIP_DISABLE_PIP_VERSION_CHECK=1
    ''
    + pkgs.lib.optionalString (variant == "ROCM") ''
      export PIP_INDEX_URL="${rocmIndexUrl}"
      export PIP_EXTRA_INDEX_URL="https://pypi.org/simple"
      echo "ROCm devshell: pip will pull torch/vision/audio wheels from ${rocmIndexUrl}"
      echo "If you previously installed CUDA wheels, run 'rm -rf ${venvDir}' before reinstalling requirements."
    '';
}
