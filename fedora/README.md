# Fedora tools

`install-tools.sh` builds and installs the Fedora tools HyDE currently
consumes from upstream source: `hyq` (from HyDE-Project/hyprquery), and
`awww` plus `awww-daemon` (from LGFae/awww). Source revisions are pinned in the
script so the same inputs are used by local installs and CI.

Run it from a Fedora system with `dnf` and `sudo` available:

```bash
./fedora/install-tools.sh
```

The default install prefix is `/usr/local`. Set `PREFIX` to override it.
