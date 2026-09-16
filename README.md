# pytorch

A single reproducible GPU dev environment for all my PyTorch projects.
Each project lives under `projects/<name>/` and shares the container, the
Python environment, and the tooling config in this repo.

Targets NVIDIA Blackwell GPUs (sm_120, e.g. RTX 5090) with CUDA 12.8.

## Requirements

- Docker with the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
- An NVIDIA driver that supports CUDA 12.8
- Optionally VS Code with the Dev Containers extension

## Quick start

```bash
cp .env.example .env   # set UID/GID to `id -u` / `id -g` if not 1000
make build             # one-time, downloads several GB
make gpu               # prints torch version and GPU name
make shell             # bash inside the container, repo mounted at /workspace
```

Or open the folder in VS Code and choose **Reopen in Container**.

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
own remote; this repo tracks just the environment.

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
