{ lib }:

{ attrs }:

let
  inherit (lib)
    attrNames
    concatMapStrings
    filter
    optionalString
    sort
    ;

  toLua = lib.generators.toLua { };
  renderLuaArgs =
    value:
    if lib.isAttrs value && value ? _args then
      lib.concatMapStringsSep ", " toLua value._args
    else
      toLua value;

  isLuaLocal = value: lib.isAttrs value && value ? _var;
  luaLocalName = name: value: value.name or name;

  names = sort lib.lessThan (attrNames attrs);
  luaLocalNames = filter (name: isLuaLocal attrs.${name}) names;
  settingNames = filter (name: !(builtins.elem name luaLocalNames)) names;

  renderLocal =
    name:
    let
      value = attrs.${name};
    in
    "local ${luaLocalName name value} = ${renderLuaArgs value._var}\n";

  renderCall = name: value: "hl.${name}(${renderLuaArgs value})\n";
  renderCalls =
    name: value: concatMapStrings (renderCall name) (if lib.isList value then value else [ value ]);
in
optionalString (luaLocalNames != [ ]) (
  "-- locals\n"
  + concatMapStrings renderLocal luaLocalNames
  + "\n"
)
+ concatMapStrings (
  name:
  "-- ${name}\n"
  + renderCalls name attrs.${name}
  + "\n"
) settingNames
