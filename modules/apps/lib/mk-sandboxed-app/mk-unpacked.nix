{ pkgs, lib }:

let
  typesLib = import ./types.nix { inherit lib; };
in
{
  # 多架构映射.
  resolveArch =
    { x86_64 ? "amd64"
    , aarch64 ? "arm64"
    , riscv64 ? "riscv64"
    , loongarch64 ? "loong64"
    }:
    let system = pkgs.stdenv.hostPlatform.system; in
    if system == "x86_64-linux" then x86_64
    else if system == "aarch64-linux" then aarch64
    else if system == "riscv64-linux" then riscv64
    else if system == "loongarch64-linux" then loongarch64
    else throw "Unsupported system architecture: ${system}";

  # Src ADT 静态分发.
  mkUnpacked = { pname, version, srcADT, postUnpackHooks ? [ ] }:
    let
      postUnpack = typesLib.resolvePostUnpack { inherit postUnpackHooks; };
      file = srcADT.file;
      outFile = typesLib.srcOutPath file;
    in
    if srcADT.kind == "deb" then
      pkgs.stdenv.mkDerivation {
        pname = "${pname}-unpacked";
        inherit version;
        src = outFile;
        nativeBuildInputs = [ pkgs.dpkg ];
        dontBuild = true;
        dontConfigure = true;
        unpackPhase = ''
          dpkg-deb --fsys-tarfile "$src" | tar -x --no-same-owner --no-same-permissions
        '';
        installPhase = ''
          mkdir -p $out
          if [ -d "opt" ]; then cp -a --reflink=auto opt $out/ 2>/dev/null || cp -a opt $out/; fi
          if [ -d "usr" ]; then cp -a --reflink=auto usr/* $out/ 2>/dev/null || cp -a usr/* $out/; fi
          ${postUnpack}
        '';
      }
    else if srcADT.kind == "tarball" then
      if lib.isDerivation file || builtins.isPath file then
        if postUnpackHooks == [ ] then file
        else
          pkgs.stdenv.mkDerivation {
            pname = "${pname}-unpacked";
            inherit version;
            src = file;
            dontBuild = true;
            dontConfigure = true;
            installPhase = ''
              mkdir -p $out
              cp -a --reflink=auto * $out/ 2>/dev/null || cp -a * $out/
              ${postUnpack}
            '';
          }
      else if builtins.isAttrs file && file ? outPath then
        # npins unpack=true 的 fetchTarball 结果 outPath 已是解包目录: 零拷贝复用
        if postUnpackHooks == [ ] then outFile
        else
          pkgs.stdenv.mkDerivation {
            pname = "${pname}-unpacked";
            inherit version;
            src = outFile;
            dontBuild = true;
            dontConfigure = true;
            installPhase = ''
              mkdir -p $out
              cp -a --reflink=auto * $out/ 2>/dev/null || cp -a * $out/
              ${postUnpack}
            '';
          }
      else
        pkgs.stdenv.mkDerivation {
          pname = "${pname}-unpacked";
          inherit version;
          src = outFile;
          dontBuild = true;
          dontConfigure = true;
          installPhase = ''
            mkdir -p $out
            cp -a --reflink=auto * $out/ 2>/dev/null || cp -a * $out/
            ${postUnpack}
          '';
        }
    else
      outFile;
}
