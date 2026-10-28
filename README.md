# Script to automate my Ubuntu Setup

* **Core Tools & Repositories**: Installs essential prerequisites.
* **ZRAM Swap**: Configures `zram-generator` (`/etc/systemd/zram-generator.conf`) using zstd compression mapped to 100% of RAM with high priority (`100`) to boost performance under heavy loads.
* **Keyd Remapping**: Sets up `/etc/keyd/default.conf` to remap **Caps Lock** to behave as **Escape** when tapped and **Control** when held down. Enables and starts the `keyd` service immediately.
* **Docker Engine**: Installs the official Docker repository, Docker Engine, CLI, Buildx, and Compose plugin. Adds the active user to the `docker` group for rootless container management.
* **Service Tweaks**: Disables unnecessary background system services (`NetworkManager-wait-online`, `ModemManager`, `cups`, and `switcheroo-control`).

## How to use:

```bash
chmod +x setup_system.sh
sudo ./setup.sh
```

