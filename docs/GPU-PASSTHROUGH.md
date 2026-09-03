# GPU Passthrough (NVIDIA CUDA)

WSL2 forwards the GPU through the **Windows** driver. Inside the cellar you
see the driver as read-only stubs (`/usr/lib/wsl/lib/libcuda.so`,
`nvidia-smi`). The one rule that prevents 90% of failures:

> **Install drivers on Windows only. Install the toolkit inside WSL only.**
> Never `apt/dnf install nvidia-driver-*` or `cuda-drivers` in WSL — it
> fights the passthrough and breaks everything.

## Requirements

- NVIDIA GeForce/RTX (Pascal or newer) with a current Windows driver
- `nvidia-smi` works in the cellar *before* installing anything:
  `/usr/lib/wsl/lib/nvidia-smi` (add `/usr/lib/wsl/lib` to PATH if bare
  `nvidia-smi` is not found)

## NixOS way (recommended)

In your flake override:

```nix
cellar.cuda.enable = true;              # modules/gpu.nix
# optional pin:
cellar.cuda.version = "12.8";
```

The module installs the CUDA toolkit from nixpkgs and wires
`LD_LIBRARY_PATH` in the correct order.

## The LD_LIBRARY_PATH ordering trap

The toolkit's runtime must come **before** the WSL stubs:

```bash
# Correct:
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:/usr/lib/wsl/lib:$LD_LIBRARY_PATH

# Wrong (libcuda.so version mismatch, "found no NVIDIA driver"):
export LD_LIBRARY_PATH=/usr/lib/wsl/lib:$CUDA_HOME/lib64:$LD_LIBRARY_PATH
```

`modules/gpu.nix` applies the correct order in `environment.shellInit`.

## Docker with GPUs

Docker containers need the NVIDIA Container Toolkit *inside* the distro —
not the driver, not a manual device mount:

```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
docker run --rm --gpus all nvidia/cuda:12.8.0-base-ubuntu24.04 nvidia-smi
```

## Verify end to end (PyTorch)

```bash
pip install torch --index-url https://download.pytorch.org/whl/cu128
python -c "import torch; print(torch.cuda.is_available(), torch.cuda.get_device_name(0))"
```

`True <your GPU>` means Windows driver → WSL stubs → toolkit → wheels are
all aligned.

## Quick triage

| Symptom | Cause | Fix |
|---------|-------|-----|
| `nvidia-smi: command not found` | Windows driver too old, or stubs not mounted | Update Windows driver → `wsl --update` → `wsl --shutdown` → check `ls /usr/lib/wsl/lib/` |
| Broke after an "upgrade" | A Linux driver package got installed | `purge` anything matching `nvidia-driver-*`/`cuda-drivers`, `wsl --shutdown` |
| `CUDA driver version is insufficient` | Toolkit newer than Windows driver | Downgrade the toolkit (pin `cellar.cuda.version`) or update the Windows driver |
| PyTorch sees no device | CPU-only wheel | Reinstall from the `cu1xx` index |
| Silent numeric garbage on RTX 50xx | Wrong wheel arch (needs sm_120 / cu128+) | Use `cu128` or newer wheels |
