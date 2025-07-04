# This file has been generated by Niv.

let

  #
  # The fetchers. fetch_<type> fetches specs of type <type>.
  #

  fetch_file =
    pkgs: spec:
    if spec.builtin or true then
      builtins_fetchurl { inherit (spec) url sha256; }
    else
      pkgs.fetchurl { inherit (spec) url sha256; };

  fetch_tarball =
    pkgs: name: spec:
    let
      ok = str: !builtins.isNull (builtins.match "[a-zA-Z0-9+-._?=]" str);
      # sanitize the name, though nix will still fail if name starts with period
      name' = stringAsChars (x: if !ok x then "-" else x) "${name}-src";
    in
    if spec.builtin or true then
      builtins_fetchTarball {
        name = name';
        inherit (spec) url sha256;
      }
    else
      pkgs.fetchzip {
        name = name';
        inherit (spec) url sha256;
      };

  fetch_git =
    spec:
    builtins.fetchGit {
      url = spec.repo;
      inherit (spec) rev ref;
    };

  fetch_local = spec: spec.path;

  fetch_builtin-tarball =
    name:
    throw ''
      [${name}] The niv type "builtin-tarball" is deprecated. You should instead use `builtin = true`.
              $ niv modify ${name} -a type=tarball -a builtin=true'';

  fetch_builtin-url =
    name:
    throw ''
      [${name}] The niv type "builtin-url" will soon be deprecated. You should instead use `builtin = true`.
              $ niv modify ${name} -a type=file -a builtin=true'';

  #
  # Various helpers
  #

  # The set of packages used when specs are fetched using non-builtins.
  mkPkgs =
    sources:
    let
      sourcesNixpkgs = import (builtins_fetchTarball { inherit (sources.nixpkgs) url sha256; }) { };
      hasNixpkgsPath = builtins.any (x: x.prefix == "nixpkgs") builtins.nixPath;
      hasThisAsNixpkgsPath = <nixpkgs> == ./.;
    in
    if builtins.hasAttr "nixpkgs" sources then
      sourcesNixpkgs
    else if hasNixpkgsPath && !hasThisAsNixpkgsPath then
      import <nixpkgs> { }
    else
      abort ''
        Please specify either <nixpkgs> (through -I or NIX_PATH=nixpkgs=...) or
        add a package called "nixpkgs" to your sources.json.
      '';

  # The actual fetching function.
  fetch =
    pkgs: name: spec:

    if !builtins.hasAttr "type" spec then
      abort "ERROR: niv spec ${name} does not have a 'type' attribute"
    else if spec.type == "file" then
      fetch_file pkgs spec
    else if spec.type == "tarball" then
      fetch_tarball pkgs name spec
    else if spec.type == "git" then
      fetch_git spec
    else if spec.type == "local" then
      fetch_local spec
    else if spec.type == "builtin-tarball" then
      fetch_builtin-tarball name
    else if spec.type == "builtin-url" then
      fetch_builtin-url name
    else
      abort "ERROR: niv spec ${name} has unknown type ${builtins.toJSON spec.type}";

  # Ports of functions for older nix versions

  # a Nix version of mapAttrs if the built-in doesn't exist
  mapAttrs =
    builtins.mapAttrs or (
      f: set:
      with builtins;
      listToAttrs (
        map (attr: {
          name = attr;
          value = f attr set.${attr};
        }) (attrNames set)
      )
    );

  # https://github.com/NixOS/nixpkgs/blob/0258808f5744ca980b9a1f24fe0b1e6f0fecee9c/lib/lists.nix#L295
  range =
    first: last: if first > last then [ ] else builtins.genList (n: first + n) (last - first + 1);

  # https://github.com/NixOS/nixpkgs/blob/0258808f5744ca980b9a1f24fe0b1e6f0fecee9c/lib/strings.nix#L257
  stringToCharacters = s: map (p: builtins.substring p 1 s) (range 0 (builtins.stringLength s - 1));

  # https://github.com/NixOS/nixpkgs/blob/0258808f5744ca980b9a1f24fe0b1e6f0fecee9c/lib/strings.nix#L269
  stringAsChars = f: s: concatStrings (map f (stringToCharacters s));
  concatStrings = builtins.concatStringsSep "";

  # fetchTarball version that is compatible between all the versions of Nix
  builtins_fetchTarball =
    {
      url,
      name,
      sha256,
    }@attrs:
    let
      inherit (builtins) lessThan nixVersion fetchTarball;
    in
    if lessThan nixVersion "1.12" then fetchTarball { inherit name url; } else fetchTarball attrs;

  # fetchurl version that is compatible between all the versions of Nix
  builtins_fetchurl =
    { url, sha256 }@attrs:
    let
      inherit (builtins) lessThan nixVersion fetchurl;
    in
    if lessThan nixVersion "1.12" then fetchurl { inherit url; } else fetchurl attrs;

  # Create the final "sources" from the config
  mkSources =
    config:
    mapAttrs (
      name: spec:
      if builtins.hasAttr "outPath" spec then
        abort "The values in sources.json should not have an 'outPath' attribute"
      else
        spec // { outPath = fetch config.pkgs name spec; }
    ) config.sources;

  # The "config" used by the fetchers
  mkConfig =
    {
      sourcesFile ? ./sources.json,
      sources ? builtins.fromJSON (builtins.readFile sourcesFile),
      pkgs ? mkPkgs sources,
    }:
    rec {
      # The sources, i.e. the attribute set of spec name to spec
      inherit sources;

      # The "pkgs" (evaluated nixpkgs) to use for e.g. non-builtin fetchers
      inherit pkgs;
    };
in
mkSources (mkConfig { }) // { __functor = _: settings: mkSources (mkConfig settings); }
