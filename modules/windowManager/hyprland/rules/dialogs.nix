[
  # 常见 Qt / KDE / Polkit 框架应用与系统对话框微调
  {
    match = {
      class = "^(org.fcitx.fcitx5-config-qt)$";
    };
    float = true;
    center = true;
    size = "850 600";
  }
  {
    match = {
      class = "^(qt5ct|qt6ct|kvantummanager)$";
    };
    float = true;
    center = true;
    size = "850 650";
  }
  {
    match = {
      class = "^(pavucontrol|org.pulseaudio.pavucontrol)$";
    };
    float = true;
    center = true;
    size = "800 600";
  }
  {
    match = {
      class = "^(nm-connection-editor|nm-applet)$";
    };
    float = true;
    center = true;
    size = "750 550";
  }
  {
    match = {
      class = "^(blueman-manager)$";
    };
    float = true;
    center = true;
    size = "750 550";
  }
  {
    match = {
      class = "^(pinentry-.*|pinentry)$";
    };
    float = true;
    center = true;
    pin = true;
    stay_focused = true;
  }
  {
    match = {
      class = "^(polkit-.*|org.kde.polkit-kde-authentication-agent-1|lxqt-policykit)$";
    };
    float = true;
    center = true;
    stay_focused = true;
  }
  {
    match = {
      class = "^(kdialog)$";
      title = "^(.*)$";
    };
    float = true;
  }

  # 常见跨框架文件选择、保存与进度对话框
  {
    match = {
      title = "^(Open File|Select a File|Choose Files|Open Folder|Save As|Save File|All Files|另存为|打开文件|选择文件|打开文件夹|保存文件)$";
    };
    float = true;
    center = true;
    size = "900 600";
  }
  {
    match = {
      title = "^(File Upload|Upload Files|文件上传)$";
    };
    float = true;
  }
  {
    match = {
      title = "^(Confirm to replace files|File Operation Progress|文件操作进度|替换文件)$";
    };
    float = true;
  }
]
