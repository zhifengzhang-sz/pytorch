# Convenience wrappers around docker compose. Every target that runs code
# executes inside the container, so the host needs only Docker + the NVIDIA
# container toolkit.
.DEFAULT_GOAL := help
EXEC := docker compose exec dev

.PHONY: help build up down shell gpu test lint fmt check jupyter

help:            ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

build:           ## Build the image (rerun after editing requirements.txt)
	docker compose build

up:              ## Start the container in the background
	docker compose up -d

down:            ## Stop and remove the container (volumes are kept)
	docker compose down

shell: up        ## Open a bash shell inside the container
	$(EXEC) bash

gpu: up          ## Verify torch sees the GPU
	$(EXEC) python -c "import torch; print(torch.__version__, torch.cuda.is_available(), torch.cuda.get_device_name(0))"

test: up         ## Run the test suite (T=path::test to run one)
	$(EXEC) pytest $(T)

lint: up         ## Lint with ruff
	$(EXEC) ruff check .

fmt: up          ## Format with ruff
	$(EXEC) ruff format .

check: lint test ## Lint + test

jupyter: up      ## Launch JupyterLab on http://localhost:8888
	$(EXEC) jupyter lab --ip=0.0.0.0 --port=8888 --no-browser
