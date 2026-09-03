[
  # 常见 Qt / KDE / Polkit 框架应用与系统对话框微调
  {
    match._props = { app-id = "^(org\\.fcitx\\.fcitx5-config-qt)$"; };
    open-floating = true;
    default-column-width = { fixed = 850; };
    default-window-height = { fixed = 600; };
  }
  {
    match._props = { app-id = "^(qt5ct|qt6ct|kvantummanager)$"; };
    open-floating = true;
    default-column-width = { fixed = 850; };
    default-window-height = { fixed = 650; };
  }
  {
    match._props = { app-id = "^(pavucontrol|org\\.pulseaudio\\.pavucontrol)$"; };
    open-floating = true;
    default-column-width = { fixed = 800; };
    default-window-height = { fixed = 600; };
  }
  {
    match._props = { app-id = "^(nm-connection-editor|nm-applet)$"; };
    open-floating = true;
    default-column-width = { fixed = 750; };
    default-window-height = { fixed = 550; };
  }
  {
    match._props = { app-id = "^(blueman-manager)$"; };
    open-floating = true;
    default-column-width = { fixed = 750; };
    default-window-height = { fixed = 550; };
  }
  {
    match._props = { app-id = "^(pinentry-.*|pinentry)$"; };
    open-floating = true;
    open-focused = true;
  }
  {
    match._props = { app-id = "^(polkit-.*|org\\.kde\\.polkit-kde-authentication-agent-1|lxqt-policykit)$"; };
    open-floating = true;
    open-focused = true;
  }
  {
    match._props = { app-id = "^(kdialog)$"; };
    open-floating = true;
  }

  # 常见跨框架文件选择、保存与进度对话框
  {
    match._props = { title = "^(Open File|Select a File|Choose Files|Open Folder|Save As|Save File|All Files|另存为|打开文件|选择文件|打开文件夹|保存文件)$"; };
    open-floating = true;
    default-column-width = { fixed = 900; };
    default-window-height = { fixed = 600; };
  }
  {
    match._props = { title = "^(File Upload|Upload Files|文件上传)$"; };
    open-floating = true;
  }
  {
    match._props = { title = "^(Confirm to replace files|File Operation Progress|文件操作进度|替换文件)$"; };
    open-floating = true;
  }

  # 终端文件选择器 (xdg-desktop-portal-termfilechooser) 与终端文件管理器 (yazi)
  {
    match._props = { app-id = "^(termfilechooser)$"; };
    open-floating = true;
    open-focused = true;
    default-column-width = { fixed = 1100; };
    default-window-height = { fixed = 700; };
  }
  {
    match._props = { title = "^(termfilechooser|yazi-filechooser)$"; };
    open-floating = true;
    default-column-width = { fixed = 1100; };
    default-window-height = { fixed = 700; };
  }
  {
    match._props = { app-id = "^(yazi)$"; };
    default-column-width = { fixed = 1200; };
    default-window-height = { fixed = 750; };
  }
]
