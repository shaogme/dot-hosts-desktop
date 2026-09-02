{ pkgs, lib }:

rec {
  # 多系统架构名称映射辅助器
  resolveArch = {
    x86_64 ? "amd64",
    aarch64 ? "arm64",
    riscv64 ? "riscv64",
    loongarch64 ? "loong64",
  }:
    let
      system = pkgs.stdenv.hostPlatform.system;
    in
    if system == "x86_64-linux" then x86_64
    else if system == "aarch64-linux" then aarch64
    else if system == "riscv64-linux" then riscv64
    else if system == "loongarch64-linux" then loongarch64
    else throw "Unsupported system architecture: ${system}";

  # 解包 Derivation 生成器
  mkUnpackedDerivation = {
    pname,
    version,
    src,
    srcType ? "deb", # "deb" | "tarball" | "custom"
    postUnpack ? "",
  }:
    if srcType == "deb" then
      pkgs.stdenv.mkDerivation {
        pname = "${pname}-unpacked";
        inherit version src;
        nativeBuildInputs = [ pkgs.dpkg ];
        dontBuild = true;
        dontConfigure = true;
        unpackPhase = ''
          dpkg-deb --fsys-tarfile "$src" | tar -x --no-same-owner --no-same-permissions
        '';
        installPhase = ''
          mkdir -p $out
          if [ -d "opt" ]; then cp -r opt $out/; fi
          if [ -d "usr" ]; then cp -r usr/* $out/; fi
          ${postUnpack}
        '';
      }
    else if srcType == "tarball" then
      if lib.isDerivation src || builtins.isPath src then
        src
      else
        pkgs.stdenv.mkDerivation {
          pname = "${pname}-unpacked";
          inherit version src;
          dontBuild = true;
          dontConfigure = true;
          installPhase = ''
            mkdir -p $out
            cp -r * $out/
            ${postUnpack}
          '';
        }
    else
      src;
}
