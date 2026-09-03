{ pkgs, lib }:

rec {
  mkDesktopItem = { pname, binaryName, desktop ? { } }:
    pkgs.makeDesktopItem ({
      name = pname;
      desktopName = desktop.desktopName or pname;
      genericName = desktop.genericName or "Application";
      comment = desktop.comment or "${pname} (Bubblewrap Isolated)";
      exec = "${binaryName} %U";
      icon = desktop.icon or pname;
      terminal = desktop.terminal or false;
      type = "Application";
      categories = desktop.categories or [ "Utility" ];
      startupWMClass = desktop.startupWMClass or pname;
    } // (builtins.removeAttrs desktop [ "desktopName" "genericName" "comment" "icon" "terminal" "categories" "startupWMClass" ]));

  # icons ADT 分发 (无字符串比较).
  mkIcons = { pname, unpacked, iconsADT, aliases ? [ ] }:
    if iconsADT.kind == "none" then null
    else if iconsADT.kind == "firefox" then mkFirefoxIcons { inherit pname unpacked aliases; sizes = iconsADT.sizes; }
    else mkHicolorIcons { inherit pname unpacked aliases; };

  # firefox: sizes 经 Nix 展开成独立 if 块.
  # 别名经 Nix 展开成独立 if 块.
  mkFirefoxIcons = { pname, unpacked, aliases ? [ ], sizes ? [ 16 24 32 48 64 128 256 ] }:
    let
      sizedCopy = lib.concatStringsSep "\n" (map
        (size:
          let s = toString size; in
          ''
            icon_file="${unpacked}/browser/chrome/icons/default/default${s}.png"
            if [ -f "$icon_file" ]; then
              mkdir -p "$out/share/icons/hicolor/${s}x${s}/apps"
              cp "$icon_file" "$out/share/icons/hicolor/${s}x${s}/apps/${pname}.png"
            fi
          '')
        sizes);
      aliasCopy = lib.concatStringsSep "\n" (lib.flatten (map
        (size:
          let s = toString size; in
          map
            (alias: ''
              if [ -f "$out/share/icons/hicolor/${s}x${s}/apps/${pname}.png" ]; then
                ln -sf "$out/share/icons/hicolor/${s}x${s}/apps/${pname}.png" "$out/share/icons/hicolor/${s}x${s}/apps/${alias}.png"
              fi
            '')
            aliases)
        sizes));
      pixAlias = lib.concatStringsSep "\n" (map
        (alias: ''
          if [ -f "$out/share/pixmaps/${pname}.png" ]; then
            ln -sf "$out/share/pixmaps/${pname}.png" "$out/share/pixmaps/${alias}.png"
          fi
        '')
        aliases);
    in
    pkgs.runCommand "${pname}-icons" { } ''
      mkdir -p $out/share
      ${sizedCopy}
      if [ -f "${unpacked}/browser/chrome/icons/default/default128.png" ]; then
        mkdir -p "$out/share/pixmaps"
        cp "${unpacked}/browser/chrome/icons/default/default128.png" "$out/share/pixmaps/${pname}.png"
      fi
      ${aliasCopy}
      ${pixAlias}
    '';

  # hicolor/auto: 单次 cp -a --reflink + 单次 find -exec.
  mkHicolorIcons = { pname, unpacked, aliases ? [ ] }:
    let
      aliasFinds = lib.concatStringsSep "\n" (map
        (alias: ''
          find "$out/share/icons/hicolor" -type f \( -name "${pname}.png" -o -name "${pname}.svg" -o -name "${pname}.xpm" \) -exec sh -c '
            src="$1"
            d=$(dirname "$src")
            b=$(basename "$src")
            suffix="''${b#${pname}}"
            dst="$d/${alias}$suffix"
            if [ ! -e "$dst" ]; then
              ln -sf "$src" "$dst" 2>/dev/null || true
            fi
          ' _ {} \;
        '')
        aliases);
      pixPng = lib.concatStringsSep "\n" (map
        (alias: ''
          if [ -f "$out/share/pixmaps/${pname}.png" ] && [ ! -e "$out/share/pixmaps/${alias}.png" ]; then
            ln -sf "$out/share/pixmaps/${pname}.png" "$out/share/pixmaps/${alias}.png"
          fi
        '')
        aliases);
      pixSvg = lib.concatStringsSep "\n" (map
        (alias: ''
          if [ -f "$out/share/pixmaps/${pname}.svg" ] && [ ! -e "$out/share/pixmaps/${alias}.svg" ]; then
            ln -sf "$out/share/pixmaps/${pname}.svg" "$out/share/pixmaps/${alias}.svg"
          fi
        '')
        aliases);
      pixXpm = lib.concatStringsSep "\n" (map
        (alias: ''
          if [ -f "$out/share/pixmaps/${pname}.xpm" ] && [ ! -e "$out/share/pixmaps/${alias}.xpm" ]; then
            ln -sf "$out/share/pixmaps/${pname}.xpm" "$out/share/pixmaps/${alias}.xpm"
          fi
        '')
        aliases);
    in
    pkgs.runCommand "${pname}-icons" { } ''
      mkdir -p $out/share
      if [ -d "${unpacked}/share/icons" ]; then
        mkdir -p $out/share/icons
        cp -a --reflink=auto "${unpacked}/share/icons/"* $out/share/icons/ 2>/dev/null \
          || cp -a "${unpacked}/share/icons/"* $out/share/icons/
        chmod -R u+w $out/share/icons
      fi
      if [ -d "${unpacked}/share/pixmaps" ]; then
        mkdir -p $out/share/pixmaps
        cp -a --reflink=auto "${unpacked}/share/pixmaps/"* $out/share/pixmaps/ 2>/dev/null \
          || cp -a "${unpacked}/share/pixmaps/"* $out/share/pixmaps/
        chmod -R u+w $out/share/pixmaps
      fi

      # HiDPI 回退: 256x256@2 → 256x256
      if [ -d "$out/share/icons/hicolor/256x256@2/apps" ]; then
        mkdir -p "$out/share/icons/hicolor/256x256/apps"
        find "$out/share/icons/hicolor/256x256@2/apps" -type f -exec ln -sf -t "$out/share/icons/hicolor/256x256/apps" {} +
      fi

      ${lib.optionalString (aliases != [ ]) ''
        if [ -d "$out/share/icons/hicolor" ]; then
        ${aliasFinds}
        fi
        if [ -d "$out/share/pixmaps" ]; then
        ${pixPng}
        ${pixSvg}
        ${pixXpm}
        fi
      ''}
    '';

  # 别名: linkFarm 静态展开 (无 postBuild 循环).
  mkAliases = { pname, binaryName, aliases, wrapper }:
    if aliases == [ ] then null
    else
      pkgs.linkFarm "${pname}-aliases"
        (map (a: { name = "bin/${a}"; path = "${wrapper}/bin/${binaryName}"; }) aliases);

  mkFinalPackage =
    { pname
    , version
    , wrapper
    , desktopItem
    , iconsDrv ? null
    , aliasesDrv ? null
    , postBuildHooks ? [ ]
    , windowRules ? [ ]
    , unpacked
    , fhs
    , appMeta
    }:
    pkgs.symlinkJoin {
      name = "${pname}-${version}";
      paths =
        [ wrapper desktopItem ]
        ++ lib.optionals (iconsDrv != null) [ iconsDrv ]
        ++ lib.optionals (aliasesDrv != null) [ aliasesDrv ];
      postBuild = lib.concatStringsSep "\n" (map toString postBuildHooks);
      passthru = {
        inherit unpacked fhs windowRules appMeta;
      };
    };
}
