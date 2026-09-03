[
  {
    match._props = {
      title = "^(Picture-in-Picture|画中画)$";
    };
    open-floating = true;
  }
  {
    match._props = {
      app-id = "^(firefox|firefox-developer-edition|firefox-devedition)$";
      title = "^(Library|Opening.*|About Mozilla Firefox|关于 Mozilla Firefox)$";
    };
    open-floating = true;
  }
]
