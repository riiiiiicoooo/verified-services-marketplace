{ pkgs }: {
  deps = [
    # Python environment
    pkgs.python311
    pkgs.python311Packages.pip
    pkgs.python311Packages.venv
    pkgs.python311Packages.poetry

    # Node.js and npm
    pkgs.nodejs_20
    pkgs.nodePackages.npm
    pkgs.nodePackages.yarn

    # PostgreSQL and PostGIS
    pkgs.postgresql_15
    pkgs.postgis
    pkgs.libpq

    # Build tools
    pkgs.gcc
    pkgs.gnumake
    pkgs.pkg-config

    # CLI tools
    pkgs.curl
    pkgs.wget
    pkgs.git
    pkgs.vim
    pkgs.htop

    # Development utilities
    pkgs.direnv
    pkgs.zsh
  ];

  env = {
    PYTHONPATH = "/root/.local/lib/python3.11/site-packages:/workspace";
    PYTHONUNBUFFERED = "1";
    LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath [pkgs.postgresql_15 pkgs.postgis]}";
    PKG_CONFIG_PATH = "${pkgs.postgresql_15}/lib/pkgconfig:${pkgs.postgis}/lib/pkgconfig";
  };
}
