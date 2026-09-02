{ pkgs }:

let
  builtinsWallpapers = pkgs.runCommandLocal "awww-builtin-wallpapers" { } ''
    mkdir -p $out/share/wallpapers

    # 1. Catppuccin Mocha - 4K 几何极光深色壁纸 (3840x2160)
    cat <<'SVG' > $out/share/wallpapers/catppuccin-mocha.svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 3840 2160" width="3840" height="2160">
  <defs>
    <linearGradient id="cm-bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#11111b" />
      <stop offset="50%" stop-color="#181825" />
      <stop offset="100%" stop-color="#1e1e2e" />
    </linearGradient>
    <radialGradient id="cm-glow1" cx="30%" cy="35%" r="45%">
      <stop offset="0%" stop-color="#cba6f7" stop-opacity="0.32" />
      <stop offset="50%" stop-color="#89b4fa" stop-opacity="0.12" />
      <stop offset="100%" stop-color="#181825" stop-opacity="0" />
    </radialGradient>
    <radialGradient id="cm-glow2" cx="75%" cy="65%" r="50%">
      <stop offset="0%" stop-color="#f5c2e7" stop-opacity="0.25" />
      <stop offset="45%" stop-color="#94e2d5" stop-opacity="0.15" />
      <stop offset="100%" stop-color="#1e1e2e" stop-opacity="0" />
    </radialGradient>
    <linearGradient id="cm-poly1" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#89b4fa" stop-opacity="0.18" />
      <stop offset="100%" stop-color="#cba6f7" stop-opacity="0.04" />
    </linearGradient>
    <linearGradient id="cm-poly2" x1="100%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#f5c2e7" stop-opacity="0.15" />
      <stop offset="100%" stop-color="#94e2d5" stop-opacity="0.03" />
    </linearGradient>
  </defs>

  <!-- 背景底色 -->
  <rect width="3840" height="2160" fill="url(#cm-bg)" />

  <!-- 柔和极光光晕 -->
  <circle cx="1152" cy="756" r="1400" fill="url(#cm-glow1)" />
  <circle cx="2880" cy="1404" r="1500" fill="url(#cm-glow2)" />

  <!-- 现代化极简几何多边形与光影面 -->
  <polygon points="400,2160 1200,600 2400,1600" fill="url(#cm-poly1)" stroke="#89b4fa" stroke-width="1.2" stroke-opacity="0.2" />
  <polygon points="1400,0 2800,800 2200,2160" fill="url(#cm-poly2)" stroke="#f5c2e7" stroke-width="1.2" stroke-opacity="0.2" />
  <polygon points="1920,400 3200,1800 1200,1900" fill="none" stroke="#cba6f7" stroke-width="1.5" stroke-opacity="0.25" stroke-dasharray="8 12" />

  <!-- 极简微光粒子与流线 -->
  <circle cx="1200" cy="600" r="6" fill="#89b4fa" opacity="0.8" />
  <circle cx="2800" cy="800" r="5" fill="#f5c2e7" opacity="0.8" />
  <circle cx="2400" cy="1600" r="7" fill="#94e2d5" opacity="0.8" />
  <circle cx="1920" cy="400" r="4" fill="#cba6f7" opacity="0.7" />
</svg>
SVG

    # 2. Tokyo Night - 4K 赛博霓虹夜景壁纸 (3840x2160)
    cat <<'SVG' > $out/share/wallpapers/tokyo-night.svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 3840 2160" width="3840" height="2160">
  <defs>
    <linearGradient id="tn-bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#0f0f14" />
      <stop offset="50%" stop-color="#16161e" />
      <stop offset="100%" stop-color="#1a1b26" />
    </linearGradient>
    <radialGradient id="tn-glow1" cx="20%" cy="80%" r="50%">
      <stop offset="0%" stop-color="#7aa2f7" stop-opacity="0.28" />
      <stop offset="60%" stop-color="#bb9af7" stop-opacity="0.08" />
      <stop offset="100%" stop-color="#16161e" stop-opacity="0" />
    </radialGradient>
    <radialGradient id="tn-glow2" cx="80%" cy="20%" r="45%">
      <stop offset="0%" stop-color="#ff9e64" stop-opacity="0.20" />
      <stop offset="50%" stop-color="#7dcfff" stop-opacity="0.10" />
      <stop offset="100%" stop-color="#1a1b26" stop-opacity="0" />
    </radialGradient>
    <linearGradient id="tn-line1" x1="0%" y1="100%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#7aa2f7" stop-opacity="0.4" />
      <stop offset="50%" stop-color="#bb9af7" stop-opacity="0.2" />
      <stop offset="100%" stop-color="#7dcfff" stop-opacity="0" />
    </linearGradient>
  </defs>

  <rect width="3840" height="2160" fill="url(#tn-bg)" />
  <circle cx="768" cy="1728" r="1300" fill="url(#tn-glow1)" />
  <circle cx="3072" cy="432" r="1400" fill="url(#tn-glow2)" />

  <!-- 赛博透视网格线条 -->
  <path d="M 0,1600 Q 1920,1200 3840,1600" fill="none" stroke="url(#tn-line1)" stroke-width="2" />
  <path d="M 0,1750 Q 1920,1350 3840,1750" fill="none" stroke="url(#tn-line1)" stroke-width="1.5" opacity="0.6" />
  <path d="M 0,1900 Q 1920,1500 3840,1900" fill="none" stroke="url(#tn-line1)" stroke-width="1.2" opacity="0.4" />
  <polygon points="1920,700 2560,1500 1280,1500" fill="#7aa2f7" fill-opacity="0.04" stroke="#7aa2f7" stroke-width="1" stroke-opacity="0.3" />
</svg>
SVG

    # 3. Nord - 4K 极地极简山峦壁纸 (3840x2160)
    cat <<'SVG' > $out/share/wallpapers/nord.svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 3840 2160" width="3840" height="2160">
  <defs>
    <linearGradient id="nord-sky" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#242933" />
      <stop offset="60%" stop-color="#2e3440" />
      <stop offset="100%" stop-color="#3b4252" />
    </linearGradient>
    <linearGradient id="nord-m1" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#434c5e" />
      <stop offset="100%" stop-color="#2e3440" />
    </linearGradient>
    <linearGradient id="nord-m2" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#4c566a" />
      <stop offset="100%" stop-color="#3b4252" />
    </linearGradient>
    <linearGradient id="nord-m3" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#88c0d0" stop-opacity="0.6" />
      <stop offset="100%" stop-color="#4c566a" />
    </linearGradient>
  </defs>

  <rect width="3840" height="2160" fill="url(#nord-sky)" />
  <circle cx="2800" cy="650" r="160" fill="#eceff4" opacity="0.15" />
  
  <!-- 远景山峦 -->
  <polygon points="0,2160 0,1400 800,900 1800,1500 2800,850 3840,1450 3840,2160" fill="url(#nord-m1)" opacity="0.7" />
  <!-- 中景山峦 -->
  <polygon points="0,2160 0,1650 600,1200 1500,1750 2400,1150 3400,1650 3840,1400 3840,2160" fill="url(#nord-m2)" opacity="0.85" />
  <!-- 近景峰峦 -->
  <polygon points="0,2160 0,1850 1100,1350 2100,1950 3100,1400 3840,1800 3840,2160" fill="url(#nord-m3)" />
</svg>
SVG
  '';
in
{
  package = builtinsWallpapers;
  defaultWallpaper = "${builtinsWallpapers}/share/wallpapers/catppuccin-mocha.svg";
  tokyoNight = "${builtinsWallpapers}/share/wallpapers/tokyo-night.svg";
  nord = "${builtinsWallpapers}/share/wallpapers/nord.svg";
}
