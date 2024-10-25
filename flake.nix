{
  description = "Phoenix Framework project with Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
    in
    flake-utils.lib.eachSystem systems (system:
      let
        pkgs = import nixpkgs { inherit system; };

        initScript = pkgs.writeText "init.nu" ''
          # Environment setup
          mkdir ".nix-mix"
          mkdir ".nix-hex"
          
          $env.MIX_HOME = ($env.PWD | path join ".nix-mix")
          $env.HEX_HOME = ($env.PWD | path join ".nix-hex")
  
          # Properly construct PATH using nushell list operations
          let mix_bin = ($env.MIX_HOME | path join "bin")
          let hex_bin = ($env.HEX_HOME | path join "bin")
          $env.PATH = ([$mix_bin $hex_bin] | append ($env.PATH | split row (char esep)) | uniq | str join (char esep))
  
          $env.LANG = "en_US.UTF-8"
          $env.LC_ALL = "en_US.UTF-8"
          $env.ERL_AFLAGS = "-kernel shell_history enabled"
          $env.PGDATA = ($env.PWD | path join "postgres_data")
          $env.PGHOST = ($env.PWD | path join "postgres")
          $env.LOG_PATH = ($env.PGHOST | path join "LOG")

          $env.PGUSER = "postgres"
          $env.PGPASSWORD = "postgres"
          $env.PGDATABASE = "postgres"
          $env.PGPORT = "5432"
          $env.DATABASE_URL = "postgresql://postgres:postgres@localhost:5432/postgres"

          # Set up Julia environment
          $env.JULIA_DIR = "${pkgs.julia}"

          # Create postgres directory if it doesn't exist
          if not ($env.PGHOST | path exists) {
            mkdir $env.PGHOST
          }

          # PostgreSQL initialization
          if not ($env.PGDATA | path exists) {
            print 'Initializing postgresql database...'
            let os = (uname | str trim)
            if $os == "Darwin" {
              initdb --auth=trust -U postgres $env.PGDATA --encoding=UTF8 --locale=en_US.UTF-8
            } else {
              initdb $env.PGDATA --username postgres -A trust --encoding=UTF8 --locale=en_US.UTF-8
            }
    
            # Configure PostgreSQL
            let conf_file = ($env.PGDATA | path join "postgresql.conf")
            let conf_contents = [
              "# Added by development environment"
              "listen_addresses = '*'"
              $"unix_socket_directories = '($env.PWD)/postgres'"
              "unix_socket_permissions = 0700"
              "port = 5432"
              ""  # Empty line at end
            ]
            $conf_contents | str join "\n" | save --append $conf_file
          }

          # Print helpful information
          print "To run the services configured here, you can run the `overmind start -D` command"
          print $"To connect to PostgreSQL, use: psql -h ($env.PGHOST) -p ($env.PGPORT) -U ($env.PGUSER) -d ($env.PGDATABASE)"
        '';

        startupScript = pkgs.writeScript "startup.sh" ''
          #!${pkgs.bash}/bin/bash
          mkdir -p "$PWD/.nushell"

          # Create minimal configs
          cat > "$PWD/.nushell/env.nu" << 'EOF'
          $env.config = {
            show_banner: false
          }
          
          source ${initScript}
          EOF

          cat > "$PWD/.nushell/config.nu" << 'EOF'
          $env.config = {
            show_banner: false
          }
          EOF

          # Start nushell interactively
          exec ${pkgs.nushell}/bin/nu --interactive --env-config "$PWD/.nushell/env.nu" --config "$PWD/.nushell/config.nu"
        '';

        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            nixpkgs-fmt
            bat
            erlang_25
            elixir_1_17
            docker-compose
            entr
            gnumake
            overmind
            jq
            mix2nix
            postgresql_16
            graphviz
            imagemagick
            python3
            glibcLocales
            nushell
            rustc
            cargo
            julia
          ] ++ lib.optionals stdenv.isLinux [
            inotify-tools
            unixtools.netstat
          ] ++ lib.optionals stdenv.isDarwin [
            terminal-notifier
            darwin.apple_sdk.frameworks.CoreFoundation
            darwin.apple_sdk.frameworks.CoreServices
          ];

          shellHook = ''
            exec ${startupScript}
          '';

          LOCALE_ARCHIVE = if pkgs.stdenv.isLinux then "${pkgs.glibcLocales}/lib/locale/locale-archive" else "";
        };

      in
      {
        devShells.default = devShell;
      }
    );
}
