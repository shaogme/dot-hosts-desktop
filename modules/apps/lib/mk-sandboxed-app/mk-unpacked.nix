{ pkgs, lib }:

let
  typesLib = import ./types.nix { inherit lib; };
  fetchWithRetry = import ../fetch-with-retry.nix { inherit pkgs lib; };
  sevenZipTool = pkgs.sevenZip or pkgs._7zip-zstd;
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
      file = fetchWithRetry.ensureFetched srcADT.file;
      outFile = typesLib.srcOutPath file;

      stripRootCmd =
        if srcADT.stripRoot then ''
          chmod -R u+w "$out"
          shopt -s nullglob dotglob
          entries=("$out"/*)
          if [ "''${#entries[@]}" -eq 1 ] && [ -d "''${entries[0]}" ]; then
            single_dir="''${entries[0]}"
            tmp_strip=$(mktemp -d "''${TMPDIR:-/tmp}/strip-XXXXXX")
            mv "$single_dir" "$tmp_strip/root"
            mv "$tmp_strip/root"/* "$out"/ 2>/dev/null || true
            rm -rf "$tmp_strip"
          fi
          shopt -u dotglob nullglob
        '' else "";
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
    else if srcADT.kind == "zip" then
      pkgs.stdenv.mkDerivation {
        pname = "${pname}-unpacked";
        inherit version;
        src = outFile;
        nativeBuildInputs = [ sevenZipTool ];
        dontBuild = true;
        dontConfigure = true;
        unpackPhase = ''
          mkdir -p $out
          7z x -y "$src" -o$out/
        '';
        installPhase = ''
          ${stripRootCmd}
          ${postUnpack}
        '';
      }
    else if srcADT.kind == "nsis" then
      pkgs.stdenv.mkDerivation {
        pname = "${pname}-unpacked";
        inherit version;
        src = outFile;
        nativeBuildInputs = [ sevenZipTool ];
        dontBuild = true;
        dontConfigure = true;
        unpackPhase = ''
          mkdir -p $out
          7z x -y "$src" -o$out/
          rm -rf $out/\$PLUGINSDIR $out/\$_OUTDIR 2>/dev/null || true
        '';
        installPhase = ''
          ${stripRootCmd}
          ${postUnpack}
        '';
      }
    else if srcADT.kind == "inno" then
      pkgs.stdenv.mkDerivation {
        pname = "${pname}-unpacked";
        inherit version;
        src = outFile;
        nativeBuildInputs = [ pkgs.innoextract ];
        dontBuild = true;
        dontConfigure = true;
        unpackPhase = ''
          mkdir -p $out
          innoextract --silent --extract --output-dir "$out" "$src"
          if [ -d "$out/app" ] && [ "${if srcADT.stripRoot then "1" else "0"}" = "1" ]; then
            chmod -R u+w "$out"
            cp -a --reflink=auto "$out/app"/. "$out"/ 2>/dev/null || cp -a "$out/app"/. "$out"/
            rm -rf "$out/app"
          fi
        '';
        installPhase = ''
          ${stripRootCmd}
          ${postUnpack}
        '';
      }
    else if srcADT.kind == "msi" then
      pkgs.stdenv.mkDerivation {
        pname = "${pname}-unpacked";
        inherit version;
        src = outFile;
        nativeBuildInputs = [ pkgs.msitools ];
        dontBuild = true;
        dontConfigure = true;
        unpackPhase = ''
          mkdir -p $out
          msiextract "$src" -C "$out"
        '';
        installPhase = ''
          ${stripRootCmd}
          ${postUnpack}
        '';
      }
    else if srcADT.kind == "tarball" then
      pkgs.stdenv.mkDerivation {
        pname = "${pname}-unpacked";
        inherit version;
        src = outFile;
        nativeBuildInputs = [ pkgs.gnutar pkgs.zstd ];
        dontBuild = true;
        dontConfigure = true;
        unpackPhase = "true";
        installPhase = ''
          mkdir -p $out
          if [ -d "$src" ]; then
            cp -a --reflink=auto "$src"/. "$out"/ 2>/dev/null || cp -a "$src"/. "$out"/
          else
            tar -xf "$src" -C "$out" --no-same-owner --no-same-permissions
          fi
          ${stripRootCmd}
          ${postUnpack}
        '';
      }
    else if srcADT.kind == "custom" then
      if postUnpackHooks == [ ] && !srcADT.stripRoot then outFile
      else
        pkgs.stdenv.mkDerivation {
          pname = "${pname}-unpacked";
          inherit version;
          src = outFile;
          dontBuild = true;
          dontConfigure = true;
          unpackPhase = "true";
          installPhase = ''
            mkdir -p $out
            if [ -d "$src" ]; then
              cp -a --reflink=auto "$src"/. "$out"/ 2>/dev/null || cp -a "$src"/. "$out"/
            else
              cp -a --reflink=auto "$src" "$out"/ 2>/dev/null || cp -a "$src" "$out"/
            fi
            ${stripRootCmd}
            ${postUnpack}
          '';
        }
    else
      throw "mkSandboxedApp: 未知 srcADT kind '${srcADT.kind}'";
}
