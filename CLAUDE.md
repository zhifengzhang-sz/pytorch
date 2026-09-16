# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

A shared GPU dev container for PyTorch work. Each project is a separate git repository cloned into `projects/<name>/`; that directory is gitignored, so project code and history live in the project's own remote and this repo tracks only the environment and tooling. There is no application code at the root.

## Hard constraints

- **Target GPU is NVIDIA Blackwell (sm_120).** PyTorch must be installed from the cu128 wheel index, never plain PyPI. Do not change the base image's CUDA major/minor without checking sm_120 support.
- **Nothing runs on the host.** All Python, tests, and linting run inside the container. Host Python is not the project interpreter.
- **Keep the repo portable.** No usernames, home paths, or host-specific values in tracked files. The container user is the generic `dev`; UID/GID come from `.env` (gitignored, see `.env.example`) or default to 1000.
- **Caches live at `/cache/*`** (`HF_HOME`, `TORCH_HOME`, `PIP_CACHE_DIR`), backed by named volumes. Do not point them at a home directory.
- **Projects are not committed here.** Never `git add` anything under `projects/`. Commit and push a project from inside its own clone. Projects must not carry their own Dockerfile or ruff/pytest config; the root owns those.
- **Large artifacts never get committed.** `data/`, `checkpoints/`, `runs/`, `outputs/`, and weight files are gitignored and dockerignored.

## Commands

All wrappers run inside the container via `docker compose exec dev`; `make help` lists them.

```bash
make build                                   # rebuild image (after editing requirements.txt)
make shell                                   # bash in container
make gpu                                     # torch + CUDA sanity check
make test                                    # pytest over projects/
make test T=projects/foo/test_x.py::test_y   # single test
make lint / make fmt                         # ruff check / ruff format
```

## Environment layout

- Python venv is `/opt/venv`, on `PATH`, root-owned. Add packages by editing `requirements.txt` and rebuilding, not by pip-installing into a running container (that is lost on rebuild).
- Optional ML libraries (`transformers`, `datasets`, `accelerate`, `tensorboard`, `wandb`) are already listed commented-out in `requirements.txt`; uncomment rather than duplicate.
- `pyproject.toml` at the root holds shared ruff and pytest config (line length 100, Python 3.12, pytest `testpaths = projects`). A project may add its own `pyproject.toml` only if it needs to be an installable package.
- `.devcontainer/devcontainer.json` reuses `docker-compose.yml`; VS Code remaps the container UID to the local user on Linux automatically.
- Ports 8888 (JupyterLab) and 6006 (TensorBoard) are published.
