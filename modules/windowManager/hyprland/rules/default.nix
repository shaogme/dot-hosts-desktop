let
  xwaylandRules = import ./xwayland.nix;
  dialogRules = import ./dialogs.nix;
  mediaRules = import ./media.nix;
in
xwaylandRules ++ dialogRules ++ mediaRules
