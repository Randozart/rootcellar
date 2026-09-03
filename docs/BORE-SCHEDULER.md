# BORE Scheduler

BORE (Burst-Oriented Response Enhancer) modifies the EEVDF fair scheduler to
discriminate tasks by *burst time* — CPU time consumed since the task last
yielded, slept, or waited on I/O. Greedy tasks (compilers, batch jobs) lose
timeslice weight; modest tasks (your shell, editor, file manager) keep the
machine responsive under heavy load. It is the default scheduler on CachyOS,
and now in your cellar.

The implementation lives in the kernel: `kernel/patches/bore-6.6-cachy.patch`
applied to Microsoft's `linux-msft-wsl-6.18.y` tree by `kernel/build-kernel.sh`.

## Build & install

```bash
cd /path/to/rootcellar
kernel/build-kernel.sh            # or: nix develop .#kernel -c kernel/build-kernel.sh
```

Then in `.wslconfig`:

```ini
kernel=C:\\Users\\randy\\wsl-kernel\\bzImage
```

PowerShell: `wsl --shutdown`, relaunch, verify:

```
uname -r                  → 6.18.x-rootcellar-bore
sysctl kernel.sched_bore  → 1
```

## Keeping it fresh

```bash
kernel/check-upstream.sh              # report drift vs CachyOS upstream
kernel/check-upstream.sh --download   # re-vendor + update PATCH_VERSION
kernel/build-kernel.sh                # rebuild
```

Once pushed to GitHub, `.github/workflows/patch-watch.yml` checks daily.

## Tunables (`sysctl -w kernel.<name>=<value>`)

| Tunable | Default | Meaning |
|---------|---------|---------|
| `sched_bore` | 1 | Master switch (0 reverts to stock EEVDF, no reboot needed) |
| `sched_burst_penalty_offset` | 24 | Bits shaved off burst time before scoring. Higher = short bursts forgiven longer; extends the effective range |
| `sched_burst_penalty_scale` | 1536 | How aggressively score grows with burst time (1/1024 units). Higher = greedy tasks punished faster |
| `sched_burst_smoothness` | 1 | 0–3. Higher = burst score blends more history (smoother, slower to react) |
| `sched_burst_inherit_type` | 2 | 0 off, 1 parent→child, 2 hub/stub hierarchy. Type 2 protects interactive tasks from `make -j` fork storms |
| `sched_burst_cache_lifetime` | 75000000 | ns to cache on-fork child burst averages |

## Workload presets

```bash
# CachyOS desktop defaults (what the cellar ships):
# offset=24, scale=1536, smoothness=1, inherit=2

# Heavier throughput (build boxes): forgive greedy tasks more
sysctl -w kernel.sched_burst_penalty_scale=1024

# Maximum interactivity (gaming/multimedia on bare metal): punish greed faster
sysctl -w kernel.sched_burst_penalty_scale=2048
```

Persist overrides in Nix by adding a sysctl entry to `modules/sysctl.nix`.
