self: super: {
  jdk = super.jdk23_headless;
  mvn2nix = self.callPackage ./derivation.nix { };
  mvn2nix-bootstrap = self.callPackage ./derivation.nix { bootstrap = true; };
  buildMavenRepository = (self.callPackage ./maven.nix { }).buildMavenRepository;
  buildMavenRepositoryFromLockFile =
    (self.callPackage ./maven.nix { }).buildMavenRepositoryFromLockFile;
}
