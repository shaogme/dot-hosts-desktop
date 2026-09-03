let
  dialogRules = import ./dialogs.nix;
  mediaRules = import ./media.nix;
  xwaylandRules = import ./xwayland.nix;
in
dialogRules ++ mediaRules ++ xwaylandRules
