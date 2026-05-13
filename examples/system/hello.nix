# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

nixpkgs:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;

  service = builtins.toFile "hello.service" ''
    [Unit]
    WantedBy=multi-user.target

    [Service]
    ExecStart=${pkgs.lib.getExe pkgs.hello}
  '';
in
(pkgs.writeShellScriptBin "activate" ''
  mkdir -p $HOME/.config/systemd/user
  rm $HOME/.config/systemd/user/hello.service
  ln -s ${service} $HOME/.config/systemd/user/hello.service
  systemctl --user daemon-reload
  systemctl --user restart hello
'')
