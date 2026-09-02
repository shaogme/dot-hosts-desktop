{ cfg, lib }:

let
  binds = import ./binds.nix { inherit cfg lib; };
in
{
  monitor = [
    {
      output = "";
      mode = "preferred";
      position = "auto";
      scale = "auto";
    }
  ];

  config = {
    general = {
      gaps_in = 5;
      gaps_out = 10;
      border_size = 2;
      layout = "dwindle";
    };

    decoration = {
      rounding = 8;
      blur = {
        enabled = true;
        size = 5;
        passes = 2;
        new_optimizations = true;
        ignore_opacity = true;
      };
    };

    animations = {
      enabled = true;
    };

    xwayland = {
      force_zero_scaling = cfg.xwayland.forceZeroScaling;
      use_nearest_neighbor = cfg.xwayland.useNearestNeighbor;
    };
  };

  bind = binds;
}
