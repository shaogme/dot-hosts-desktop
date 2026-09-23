{ config, pkgs, lib, ... }:

let
  defaultTerminal = "rio";
  defaultEditor = "hx";
in
{
  # ==========================================
  # 终端与 Shell 环境 (Terminal & Nushell & Starship)
  # ==========================================
  desktop.terminal.${defaultTerminal} = {
    enable = lib.mkDefault true;
    editor.program = lib.mkDefault defaultEditor;
  };

  desktop.terminal.nushell = {
    enable = lib.mkDefault true;
  };

  desktop.terminal.starship = {
    enable = lib.mkDefault true;
  };
}
