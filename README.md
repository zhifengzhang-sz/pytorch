# pytorch

A single reproducible GPU dev environment for all my PyTorch projects.

This repo holds only the environment: the Docker image, compose service,
Makefile wrappers, and shared lint/test config. The actual projects are
separate GitHub repositories, cloned side by side into `projects/<name>/`,
where they share the container, the Python venv, and the tooling. Nothing
under `projects/` is committed here.

```
pytorch/                 this repo  (github.com/zhifengzhang-sz/pytorch)
└── projects/
    ├── project1/        its own repo, cloned here
    └── project2/        its own repo, cloned here
```

Targets NVIDIA Blackwell GPUs (sm_120, e.g. RTX 5090) with CUDA 12.8.

## Requirements

- Docker with the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
- An NVIDIA driver that supports CUDA 12.8 or newer (on WSL2 this is the
  Windows driver; see [GPU driver on WSL2](#gpu-driver-on-wsl2))
- Optionally VS Code with the Dev Containers extension

## Quick start

```bash
git clone git@github.com:zhifengzhang-sz/pytorch.git
cd pytorch
cp .env.example .env   # set UID/GID to `id -u` / `id -g` if not 1000
make build             # one-time, downloads several GB
make gpu               # prints torch version and GPU name
make shell             # bash inside the container, repo mounted at /workspace
```

Or open the folder in VS Code and choose **Reopen in Container**.

Then clone your projects into `projects/` (see below). On a new machine that
is the whole setup: clone this repo, clone the projects, `make build`.

## Everyday commands

| Command | What it does |
| --- | --- |
| `make test` | run all tests (`make test T=projects/foo/test_x.py::test_y` for one) |
| `make lint` / `make fmt` | ruff check / ruff format |
| `make jupyter` | JupyterLab on <http://localhost:8888> |
| `make down` | stop the container; caches in named volumes persist |

## Working on a project

Each project is its own git repository, cloned into `projects/<name>/`. That
directory is gitignored here, so a project's code and history live only in its
own remote; this repo tracks just the environment. A project's visibility on
GitHub is independent of this repo's.

```bash
cd projects
git clone git@github.com:<you>/project1.git
git clone git@github.com:<you>/project2.git
```

Inside the container the clones appear at `/workspace/projects/<name>`.
Commit and push each project from its own folder as usual. `make test` and
`make lint` pick up every project automatically; a project should not carry
its own Dockerfile or ruff/pytest config. A per-project `pyproject.toml` is
fine if the project needs to be pip-installable.

## GPU driver on WSL2

The GPU stack is split across three layers, and only one of them is in the
image:

| Layer | Lives in | Updated by |
| --- | --- | --- |
| NVIDIA driver (kernel + `libcuda`) | **Windows** | GeForce/Studio driver installer on Windows |
| Driver stubs `/usr/lib/wsl/lib/libcuda.so*` | WSL, generated from the Windows driver | automatically by WSL |
| CUDA toolkit 12.8, cuDNN, nvcc, torch | **the Docker image** | `make build` |

WSL2 does **not** run its own GPU driver. Never install `nvidia-driver-*`
packages inside Ubuntu; they would shadow the WSL stubs and break CUDA. The
NVIDIA Container Toolkit mounts the WSL stubs into the container when it
starts, so the image carries the toolkit but no driver. `nvidia-smi` inside
WSL or the container reports the Windows driver.

The one compatibility rule: the driver's supported CUDA version (top right of
`nvidia-smi`) must be **at least** the toolkit version in the image (12.8).
Newer drivers are backward compatible, so a driver that reports CUDA 13.x is
fine.

### When to rebuild the image

Rebuild (`make build`) only when the image contents change:

- `Dockerfile` edited, e.g. a new CUDA base image or pinned `TORCH_VERSION`
- `requirements.txt` edited
- `.env` `UID`/`GID` changed (they are baked in at build time)

Do **not** rebuild for:

- a Windows NVIDIA driver update
- a WSL or Windows update
- a Docker Engine or Container Toolkit update

After any of those, restart the container so the fresh driver stubs get
mounted: `make down && make up`. If `nvidia-smi` in WSL itself looks stale
after a driver update, run `wsl --shutdown` from Windows and reopen the distro.

A driver update becomes *necessary* only when you want a newer CUDA toolkit in
the image than the current driver supports. Update the Windows driver first,
confirm `nvidia-smi` reports the required CUDA version, then bump the base
image in `Dockerfile` and `make build`.

### If `make gpu` fails

1. `nvidia-smi` in WSL fails → the problem is on the Windows/WSL side: driver
   not installed, WSL out of date, or WSL needs `wsl --shutdown`.
2. `nvidia-smi` works in WSL but not in the container → restart the container;
   if it still fails, check `docker info | grep -i nvidia` shows the `nvidia`
   runtime and reinstall the Container Toolkit.
3. Both work but torch reports no CUDA → the image was built from the wrong
   wheel index or a wrong `TORCH_VERSION`; check `Dockerfile` and rebuild.

## Adding dependencies

Edit `requirements.txt` and run `make build`. Dependencies are shared by every
project, since all of them run in the same venv. Common ML libraries are listed
there commented-out. The venv inside the image is intentionally read-only for
the dev user; use `sudo pip install` only for throwaway experiments.

## Layout

```
projects/<name>/     one clone per project (gitignored; each has its own remote)
data/ checkpoints/   gitignored; keep large artifacts here
requirements.txt     shared Python deps
pyproject.toml       shared ruff + pytest config
```
