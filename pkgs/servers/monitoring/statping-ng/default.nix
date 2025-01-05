{
  lib,
  buildGoModule,
  fetchFromGitHub,
  stdenv,
  python3,
  yarn,
  nodejs_18,
  removeReferencesTo,
  go-rice,
  nixosTests,
  nix-update-script,
  cacert,
  moreutils,
  jq,
  faketty
}:
buildGoModule rec {
  pname = "statping-ng";
  version = "v0.91.0";

  src = fetchFromGitHub {
    owner = "statping-ng";
    repo = pname;
    rev = version;
    hash = "sha256-1jfllhy6/1SED9SEqtVQFF0i/K2POwM+kRhI9ZMFjvo=";
  };
  env = {
    CYPRESS_INSTALL_BINARY = 0;
  };
  vendorHash = "sha256-ZcNOI5/Fs7/U8/re89YpJ3qlMaQStLrrNHXiHuBQwQk=";
  offlineCache = stdenv.mkDerivation {
    inherit src env;
    name = "${pname}-${version}-yarn-offline-cache";
    nativeBuildInputs = [
      yarn
      nodejs_18
      cacert
      moreutils
      jq
      python3
    ];
    buildPhase = ''
      runHook preBuild
      export HOME="$(mktemp -d)"
      # Help node-gyp find Node.js headers
      # (see https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/javascript.section.md#pitfalls-javascript-yarn2nix-pitfalls)
      mkdir -p $HOME/.node-gyp/${nodejs_18.version}
      echo 9 > $HOME/.node-gyp/${nodejs_18.version}/installVersion
      ln -sfv ${nodejs_18}/include $HOME/.node-gyp/${nodejs_18.version}
      export npm_config_nodedir=${nodejs_18}
      cd frontend
      yarn config set enableTelemetry 0
      yarn config set cacheFolder $out
      yarn config set --json supportedArchitectures.os '[ "linux", "darwin" ]'
      yarn config set --json supportedArchitectures.cpu '["arm", "arm64","x64"]'
      yarn
      cd -
      runHook postBuild
    '';
    doDist = false;
    dontConfigure = true;
    dontInstall = true;
    dontFixup = true;
    outputHashMode = "recursive";
    outputHash = rec {
      x86_64-linux = "sha256-ZcNOI5/Fs7/U8/re89YpJ3qlMaQStLrrNHXiHuBQwQk=";
      aarch64-linux = x86_64-linux;
      #aarch64-darwin = "";
    }.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
  };
  disallowedRequisites = [offlineCache];
  proxyVendor = true;
  ldflags = [
    "-s"
    "-w"
    "-X main.VERSION=${version}"
  ];
  __darwinAllowLocalNetworking = true;
  nativeBuildInputs = [
    go-rice
    yarn
    nodejs_18
    removeReferencesTo
    faketty
  ];
  postConfigure = ''
      cd frontend
      yarn config set enableTelemetry 0
      yarn config set cacheFolder ${offlineCache}
      yarn config set --json supportedArchitectures.os '[ "linux", "darwin" ]'
      yarn config set --json supportedArchitectures.cpu '[ "arm64","x64" ]'
      yarn install --immutable-cache
      #yarn run build
      cd -
      cp -r frontend/dist source
      cp -r frontend/src/assets/scss source/dist
      cp -r frontend/public/robots.txt source/dist
      cd source && rice embed-go
      cd -
    '';
  postFixup = ''
    while read line; do
      remove-references-to -t ${offlineCache} "$line"
    done < <(find $out -type f -name '*.js.map' -or -name '*.js')
  '';
  meta = with lib; {
    description = "CHANGE";
    homepage = "https://github.com/statping-ng/statping-ng";
    license = licenses.gpl3;
    maintainers = with maintainers; [
      FKouhai
    ];
    platforms = [
      "x86_64-linux"
      "x86_64-darwin"
      "aarch64-linux"
      "aarch64-darwin"
    ];
    mainProgram = "statping-ng";
  };
}
