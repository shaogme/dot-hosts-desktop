[
  {
    match = {
      title = "^(Picture-in-Picture|画中画)$";
    };
    float = true;
    pin = true;
    keep_aspect_ratio = true;
  }
  {
    match = {
      class = "^(firefox|firefox-developer-edition|firefox-devedition)$";
      title = "^(Library|Opening.*|About Mozilla Firefox|关于 Mozilla Firefox)$";
    };
    float = true;
    center = true;
  }
]
