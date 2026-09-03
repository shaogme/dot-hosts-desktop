{ lib }:

let
  inherit (lib)
    isAttrs
    isList
    isBool
    isInt
    isFloat
    isString
    concatStringsSep
    mapAttrsToList
    filterAttrs
    replaceStrings
    typeOf
    ;

  sanitizeString = s:
    replaceStrings
      [ "\\" "\"" "\n" "\r" "\t" ]
      [ "\\\\" "\\\"" "\\n" "\\r" "\\t" ]
      s;

  indentStrings = str:
    concatStringsSep "\n" (map (x: if x == "" then "" else "    " + x) (lib.splitString "\n" str));

  literalValueToString = val:
    if val == null then
      "null"
    else if isBool val then
      (if val then "true" else "false")
    else if isInt val then
      toString val
    else if isFloat val then
      toString val
    else if isString val then
      "\"" + sanitizeString val + "\""
    else
      throw "toKdl: unsupported scalar type ${typeOf val}";

  renderProp = k: v:
    "${k}=${literalValueToString v}";

  isFlatList = l:
    lib.all (x: !isAttrs x && !isList x) l;

  convertNode = name: value:
    if value == null then
      ""
    else if isBool value then
      "${name} ${literalValueToString value}"
    else if isInt value || isFloat value || isString value then
      "${name} ${literalValueToString value}"
    else if isList value then
      if name == "_children" then
        concatStringsSep "\n" (map renderChildItem value)
      else if isFlatList value then
        "${name} ${concatStringsSep " " (map literalValueToString value)}"
      else
        concatStringsSep "\n" (map (item: convertNode name item) value)
    else if isAttrs value then
      if value ? _raw then
        value._raw
      else
        let
          args = map literalValueToString (value._args or [ ]);
          props = mapAttrsToList renderProp (value._props or { });
          orderedChildren = map renderChildItem (value._children or [ ]);
          remainingAttrs = filterAttrs (k: _: !(builtins.elem k [ "_args" "_props" "_children" "_raw" ])) value;
          unorderedChildren = mapAttrsToList convertNode remainingAttrs;
          allChildren = orderedChildren ++ unorderedChildren;
          filteredChildren = lib.filter (c: c != "") allChildren;
          prefix = concatStringsSep " " ([ name ] ++ args ++ props);
        in
        if filteredChildren == [ ] then
          prefix
        else
          "${prefix} {\n${indentStrings (concatStringsSep "\n" filteredChildren)}\n}"
    else
      throw "toKdl: unsupported value type for node ${name}: ${typeOf value}";

  renderChildItem = item:
    if isAttrs item then
      if item ? _raw then
        item._raw
      else
        concatStringsSep "\n" (mapAttrsToList convertNode item)
    else if isString item then
      item
    else
      throw "toKdl: child item must be an attrset or string";

  gen = attrs:
    if isAttrs attrs then
      let
        lines = mapAttrsToList convertNode attrs;
        filtered = lib.filter (l: l != "") lines;
      in
      concatStringsSep "\n" filtered + "\n"
    else
      throw "toKdl: expected attrset at top level";
in
gen
