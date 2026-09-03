{ pkgs, lib ? pkgs.lib }:

let
  sources = if builtins.pathExists ./npins then import ./npins else import ../npins;
  source = sources.default or sources.wallpapers;

  rawVersion = source.version;
  version = lib.removePrefix "v" (lib.removePrefix "default/" rawVersion);
  encodedVersion = lib.replaceStrings [ "/" ] [ "%2F" ] rawVersion;

  # 获取 release 资产元数据 JSON 文件
  releaseJson = builtins.fetchurl {
    url = "https://api.github.com/repos/shaogme/wallpapers/releases/tags/${encodedVersion}";
    name = "wallpapers-release-${version}.json";
  };

  releaseData = builtins.fromJSON (builtins.readFile releaseJson);

  # 自动检测 release 中所有的图片资产
  isImage = name:
    let
      lower = lib.toLower name;
    in
      lib.hasSuffix ".jpg" lower
      || lib.hasSuffix ".jpeg" lower
      || lib.hasSuffix ".png" lower
      || lib.hasSuffix ".webp" lower
      || lib.hasSuffix ".avif" lower
      || lib.hasSuffix ".svg" lower;

  imageAssets = builtins.filter (a: isImage a.name) (releaseData.assets or [ ]);

  wallpaperFiles = map (a: a.name) imageAssets;

  fetchedWallpapers = map (asset: {
    inherit (asset) name;
    path = builtins.fetchurl asset.browser_download_url;
  }) imageAssets;

  package = pkgs.runCommandLocal "wallpapers-default-${version}" {
    meta = with lib; {
      description = "Default high-resolution wallpaper collection from shaogme/wallpapers";
      homepage = "https://github.com/shaogme/wallpapers";
      platforms = platforms.all;
    };
    passthru = {
      inherit version wallpaperFiles;
    };
  } (
    "mkdir -p $out/share/wallpapers\n"
    + lib.concatMapStringsSep "\n" (item: "cp \"${item.path}\" \"$out/share/wallpapers/${item.name}\"") fetchedWallpapers
  );

  defaultWallpaper =
    if wallpaperFiles != [ ] then
      "${package}/share/wallpapers/${builtins.head wallpaperFiles}"
    else
      null;
in
{
  inherit
    version
    package
    wallpaperFiles
    defaultWallpaper
    ;
  wallpaperDir = "${package}/share/wallpapers";
}
