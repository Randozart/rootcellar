# PLAN — Docker on the custom kernel: pin the bridge/iptables stack

Status: approved · 2026-09-17

## Problem

After `cellar deploy` enabled the native Docker daemon, dockerd fails:

    Failed to create bridge docker0 via netlink: operation not supported
    Error initializing network controller: error creating default
    "bridge" network: operation not supported

The running BORE kernel ships the bridge/iptables stack as **modules**
(`CONFIG_BRIDGE=m`, `IP_NF_IPTABLES=m`, `IP6_NF_IPTABLES=m`, `IP_NF_NAT=m`,
`NETFILTER_XT_TARGET_MASQUERADE=m`, `NETFILTER_XT_MATCH_ADDRTYPE=m`, …)
and a custom kernel has no loadable modules. Stock WSL2 works only
because distros ship matching `.ko` files for the stock kernel. This is
the exact ISO9660 pattern: any `=m` feature is dead on the custom kernel.

Overlay2, containerd, VETH, NF_CONNTRACK, NFT_NAT are already `=y`, so
the daemon boots and only the network controller dies.

## Fix

1. `kernel/bore.fragment` — pin the dockerd networking set to `=y`:
   bridge (`BRIDGE`, `BRIDGE_NETFILTER`), the iptables family
   (`IP_NF_*`, `IP6_NF_*`), xtables nat/match/target bits dockerd
   probes (`XT_NAT`, `XT_MATCH_ADDRTYPE/CONNTRACK/COMMENT/MARK/STATE`,
   `XT_TARGET_LOG/MARK/MASQUERADE`), `NF_CT_NETLINK`, `NFT_FIB`,
   `NFT_REDIR`, and the misc netdevs (`MACVLAN`, `TUN`, `DUMMY`).
2. `kernel/build-kernel.sh` — extend the verify list (merged config +
   built bzImage) with `CONFIG_BRIDGE` and the iptables/NAT set so a
   regression is caught before install.
3. `cellar docker-doctor` — report `CONFIG_BRIDGE` built-in.
4. Docs — `BORE-SCHEDULER.md` compatibility contract + `TROUBLESHOOTING.md`.

## One rebuild, three fixes

The running kernel (built 2026-09-03) also predates the btrfs and
ISO9660 fragment additions, so this same `build-kernel.sh` run +
`wsl --shutdown` resolves Docker Desktop, btrfs, and Docker Engine.

## Validation

`bash -n` + `shellcheck` on build-kernel.sh and cellar · check-function
logic test · docs re-read. The kernel rebuild itself is the user's step
(needs the devshell and a disruptive `wsl --shutdown`).

## Commit

`kernel(docker): pin bridge/iptables built-in for the custom kernel`