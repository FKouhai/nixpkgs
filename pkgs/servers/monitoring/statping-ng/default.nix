{
  lib,
  buildGoModule,
  fetchFromGitHub,
  stdenv,
  python3,
  yarn,
  nodejs,
  removeReferencesTo,
  go-rice,
  nixosTests,
  testers,
  go,
  git,
  statping-ng,
  cacert,
  moreutils,
  jq,
  faketty,
  xcbuild,
  tzdata,
}:
buildGoModule rec {
  pname = "statping-ng";
  version = "v0.91.0";

  subPackages = [
    "cmd/"
  ];
  src = fetchFromGitHub {
    owner = "statping-ng";
    repo = pname;
    rev = version;
    hash = "sha256-1jfllhy6/1SED9SEqtVQFF0i/K2POwM+kRhI9ZMFjvo=";
  };
  env = {
    CYPRESS_INSTALL_BINARY = 0;
  };
  offlineCache = stdenv.mkDerivation {
    name = "${pname}-${version}-yarn-offline-cache";
    inherit src env;
    nativeBuildInputs =
      [
        yarn
        nodejs
        cacert
        moreutils
        jq
        python3
        faketty
        go
        git
      ]
      ++ lib.optionals stdenv.hostPlatform.isDarwin [xcbuild.xcbuild];
    buildPhase = ''
      runHook preBuild
      export HOME="$(mktemp -d)"
      cd frontend

      mkdir yarnCache
      yarn config set enableTelemetry 0
      yarn config set cacheFolder yarnCache
      yarn
      yarn --install --offline --cache-folder yarnCache
      yarn config set --json supportedArchitectures.os '[ "linux", "darwin" ]'
      yarn config set --json supportedArchitectures.cpu '["arm64", "x64"]'
      runHook postBuild
    '';
  installPhase = ''
    mkdir -p $out
    cp -r yarnCache/v6 $out
    cp -r node_modules $out
    '';
    dontConfigure = true;
    dontInstall = false;
    dontFixup = true;
    outputHashMode = "recursive";
    doCheck = false;
    outputHashAlgo = "sha256";
    outputHash =
      rec {
        x86_64-linux = "sha256-8EBYhJXHpOIh1AghUfXbFSdSyzUErE6ia4nu7BX0JOg=";
        #x86_64-linux = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
        aarch64-linux = x86_64-linux;
        #aarch64-darwin = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      }
      .${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
  };
  disallowedRequisites = [ offlineCache ];
  vendorHash = "sha256-ZcNOI5/Fs7/U8/re89YpJ3qlMaQStLrrNHXiHuBQwQk=";
  proxyVendor = true;
  nativeBuildInputs =
    [
      go-rice
      go
      git
      yarn
      nodejs
      removeReferencesTo
      faketty
      tzdata
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [xcbuild.xcbuild];
  postConfigure = ''
    # Help node-gyp find Node.js headers
    # (see https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/javascript.section.md#pitfalls-javascript-yarn2nix-pitfalls)
    export HOME="$(mktemp -d)"
    cp -r ${offlineCache}/node_modules frontend/
    mkdir -p $HOME/.node-gyp/${nodejs.version}
    echo 9 > $HOME/.node-gyp/${nodejs.version}/installVersion
    ln -sfv ${nodejs}/include $HOME/.node-gyp/${nodejs.version}
    export npm_config_nodedir=${nodejs}
    cd frontend
    yarn config set enableTelemetry 0
    yarn config set cacheFolder $offlineCache
    yarn install --immutable-cache
    export NODE_OPTIONS=--max_old_space_size=4096
    cd -
  '';
  postBuild = ''
    cd frontend
    export PATH=./node_modules/.bin/cross-env:$PATH
    yarn build
    cd -
    cp -r frontend/dist source
    cp -r frontend/src/assets/scss source/dist
    cp -r frontend/public/robots.txt source/dist
    cd source && rice embed-go && cd -
    #cp statping-ng $out/bin/
  '';
  postInstall = ''
    mkdir -p $out/bin
    '';
  ldflags = [
    "-s"
    "-w"
    "-X main.VERSION=${version}"
  ];
  preCheck = ''
    export ZONEINFO=${tzdata}/share/zoneinfo
    '';
  passthru.tests = {
    inherit (nixosTests) statping-ng;
    version = testers.testVersion {
      command = "statping version";
      package = statping-ng;
    };
  };
  postFixup = ''
    while read line; do
      remove-references-to -t $offlineCache "$line"
    done < <(find $out -type f -name '*.js.map' -or -name '*.js')
  '';
  meta = with lib; {
    description = "An updated drop-in for statping. A Status Page for monitoring your websites and applications with beautiful graphs, analytics, and plugins. Run on any type of environment.";
    homepage = "https://github.com/statping-ng/statping-ng";
    license = licenses.gpl3;
    maintainers = with maintainers; [
      FKouhai
    ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
    mainProgram = "statping-ng";
  };
}
