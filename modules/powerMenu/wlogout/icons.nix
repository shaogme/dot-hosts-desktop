{ pkgs }:

pkgs.runCommandLocal "wlogout-modern-svg-icons" { } ''
  mkdir -p $out/icons

  # 1. 锁屏 (Lock)
  cat <<'SVG' > $out/icons/lock.svg
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="#89b4fa" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect>
  <path d="M7 11V7a5 5 0 0 1 10 0v4"></path>
  <circle cx="12" cy="16" r="1.2" fill="#89b4fa"></circle>
</svg>
SVG

  # 2. 注销 (Logout)
  cat <<'SVG' > $out/icons/logout.svg
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="#f9e2af" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"></path>
  <polyline points="16 17 21 12 16 7"></polyline>
  <line x1="21" y1="12" x2="9" y2="12"></line>
</svg>
SVG

  # 3. 睡眠 (Suspend)
  cat <<'SVG' > $out/icons/suspend.svg
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="#cba6f7" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>
  <path d="M14 4h3l-3 4h3" stroke-width="1.4"></path>
</svg>
SVG

  # 4. 休眠 (Hibernate)
  cat <<'SVG' > $out/icons/hibernate.svg
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="#94e2d5" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <line x1="12" y1="2" x2="12" y2="22"></line>
  <path d="M4.93 4.93l14.14 14.14"></path>
  <path d="M2 12h20"></path>
  <path d="M4.93 19.07l14.14-14.14"></path>
  <circle cx="12" cy="12" r="2.5" fill="#94e2d5" fill-opacity="0.3"></circle>
</svg>
SVG

  # 5. 重启 (Reboot)
  cat <<'SVG' > $out/icons/reboot.svg
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="#fab387" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <path d="M21.5 2v6h-6"></path>
  <path d="M21.34 15.57a9 9 0 1 1-2.07-8.82l6.23-0.75"></path>
</svg>
SVG

  # 6. 关机 (Shutdown)
  cat <<'SVG' > $out/icons/shutdown.svg
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="#f38ba8" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <path d="M18.36 6.64a9 9 0 1 1-12.73 0"></path>
  <line x1="12" y1="2" x2="12" y2="12"></line>
</svg>
SVG
''
