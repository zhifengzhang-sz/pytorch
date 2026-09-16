# PyTorch dev image targeting NVIDIA Blackwell (sm_120, e.g. RTX 5090).
# Base: CUDA 12.8 + cuDNN on Ubuntu 24.04. The "devel" variant ships nvcc so
# CUDA extensions (flash-attn, custom kernels) can be compiled. Swap to
# *-cudnn-runtime-ubuntu24.04 for a ~6 GB smaller image if you never compile.
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# --- system packages -------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 python3-venv python3-dev \
        build-essential git curl ca-certificates \
        sudo tini openssh-client less nano \
    && rm -rf /var/lib/apt/lists/*

# --- non-root user ---------------------------------------------------------
# The username is generic. Only UID/GID matter: they are set at build time
# (see docker-compose.yml / .env) to match the host user so files written to
# the bind-mounted workspace are not owned by root. Ubuntu 24.04 ships a
# default "ubuntu" user on UID 1000, which is removed first.
ARG USERNAME=dev
ARG UID=1000
ARG GID=1000
RUN (userdel -r ubuntu 2>/dev/null || true) \
    && (getent group "${GID}" >/dev/null || groupadd -g "${GID}" "${USERNAME}") \
    && useradd -m -u "${UID}" -g "${GID}" -s /bin/bash "${USERNAME}" \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}" \
    && chmod 0440 "/etc/sudoers.d/${USERNAME}"

# --- caches ----------------------------------------------------------------
# Fixed paths independent of the username. docker-compose mounts named
# volumes here so models/datasets/wheels survive image rebuilds. Created and
# chowned now so the volumes inherit the right ownership on first mount.
ENV HF_HOME=/cache/huggingface \
    TORCH_HOME=/cache/torch \
    PIP_CACHE_DIR=/cache/pip
RUN mkdir -p "${HF_HOME}" "${TORCH_HOME}" "${PIP_CACHE_DIR}" \
    && chown -R "${UID}:${GID}" /cache

# --- python venv -----------------------------------------------------------
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"
RUN python3 -m venv "${VIRTUAL_ENV}" \
    && pip install --no-cache-dir --upgrade pip wheel setuptools

# --- PyTorch ---------------------------------------------------------------
# Must come from the cu128 index; default PyPI wheels lack sm_120 kernels.
# Pin a version via --build-arg TORCH_VERSION=x.y.z for reproducible builds.
ARG TORCH_VERSION=
RUN pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cu128 \
        "torch${TORCH_VERSION:+==${TORCH_VERSION}}" torchvision torchaudio

# --- project dependencies --------------------------------------------------
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt && rm /tmp/requirements.txt

# venv is root-owned and read-only for the dev user; that is intentional.
# Add packages via requirements.txt + rebuild, or `sudo pip install` for
# throwaway experiments.

USER ${USERNAME}
WORKDIR /workspace

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["sleep", "infinity"]
