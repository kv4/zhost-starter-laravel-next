# Makefile for FlowDesk Project

# ==============================================================================
# CONFIGURATION
# ==============================================================================
UID := $(shell id -u)
GID := $(shell id -g)

# Variable for NON-INTERACTIVE runs (for scripts, CI, hooks)
# The -T flag disables pseudo-TTY allocation
COMPOSE_RUN_NO_TTY = docker compose run --rm -T --user=$(UID):$(GID)

# Variable for INTERACTIVE runs (for shell access)
# The -it flag enables interactive mode
COMPOSE_RUN_IT = docker compose run --rm -it --user=$(UID):$(GID)

# Variable for executing commands in running services
COMPOSE_EXEC = docker compose exec --user=$(UID):$(GID)

# Name of the marker file created after a successful setup
SETUP_MARKER = .setup-complete

# ==============================================================================
# CORE DEVELOPER COMMANDS
# ==============================================================================
.PHONY: setup up down build clean

setup: ## (Run once) Initializes the project if not already set up
	@if [ -f "$(SETUP_MARKER)" ]; then \
		echo "✅ Project is already set up and ready to go."; \
		echo "Backend API is available at: http://localhost:8000"; \
		echo "Frontend App is available at: http://localhost:3000"; \
	else \
		echo "🚀 Starting initial project setup..."; \
		$(MAKE) do-setup; \
	fi

up: check-setup ## Starts containers in the background
	@UID=$(UID) GID=$(GID) docker compose up -d

down: check-setup ## Stops and removes containers
	@docker compose down --remove-orphans

build: check-setup ## Rebuilds Docker images
	@UID=$(UID) GID=$(GID) docker compose build

clean: ## (DANGEROUS!) Stops containers, removes ALL DATA, dependencies, and resets state
	@echo "🚨 WARNING! This command will completely remove all project data (Docker volumes), dependencies, and reset the installation state."
	@read -p "To confirm, type 'yes': " confirm && [ "$$confirm" = "yes" ] || (echo "Canceled." && exit 1)
	@echo "--- Stopping containers and removing volumes... ---"
	@docker compose down -v --remove-orphans
	@echo "--- Removing local dependencies... ---"
	@sudo rm -rf node_modules frontend/node_modules backend/vendor
	@echo "--- Removing setup marker... ---"
	@rm -f $(SETUP_MARKER)
	@echo "✅ Cleanup complete. Run 'make setup' for a fresh installation."


# ==============================================================================
# INTERNAL TARGETS & CHECKS (not for direct use)
# ==============================================================================
.PHONY: do-setup check-env check-setup composer-install npm-install

do-setup: check-env
	@echo "\n--- [1/8] Creating .env file for the backend... ---"
	@if [ ! -f backend/.env ]; then \
		cp backend/.env.example backend/.env; \
		echo "✅ File 'backend/.env' created."; \
	else \
		echo "ℹ️ File 'backend/.env' already exists, skipping."; \
	fi
	@echo "\n--- [2/8] Creating and setting permissions for Laravel directories... ---"
	@mkdir -p backend/storage/framework/sessions
	@mkdir -p backend/storage/framework/views
	@mkdir -p backend/storage/framework/cache
	@mkdir -p backend/bootstrap/cache
	@echo "✅ Directory structure for 'storage' and 'bootstrap/cache' created."
	@echo "--- [3/8] Building Docker images... ---"
	@UID=$(UID) GID=$(GID) docker compose build
	@echo "--- [4/8] Installing project dependencies... ---"
	@$(MAKE) composer-install
	@$(MAKE) npm-install
	@echo "--- [5/8] Starting containers... ---"
	@UID=$(UID) GID=$(GID) docker compose up -d
	@echo "--- [6/8] Waiting for the database to be ready... ---"
	@until docker compose exec db pg_isready -U $${DB_USERNAME:-zhost_user} -d $${DB_DATABASE:-zhost} -q; do \
		echo "⏳ Waiting for PostgreSQL to start..."; \
		sleep 2; \
	done
	@echo "✅ Database is ready to accept connections."
	@echo "--- [7/8] Adjusting file permissions inside the container... ---"
	@docker compose exec -u root app chown -R appuser:appgroup /var/www/html/storage /var/www/html/bootstrap/cache
	@echo "✅ Owner of 'storage' and 'bootstrap/cache' directories changed to 'appuser'."
	@echo "--- [8/8] Generating Laravel application key and running migrations... ---"
	@if ! grep -q "APP_KEY=base64:.*" backend/.env; then \
		echo "🔑 Generating a new key..."; \
		$(COMPOSE_EXEC) app php artisan key:generate; \
	else \
		echo "ℹ️ APP_KEY already exists, skipping."; \
	fi
	@$(COMPOSE_EXEC) app php artisan migrate --force
	@echo "--- [9/9] Creating successful setup marker... ---"
	@touch $(SETUP_MARKER)
	@echo "\n🎉 Project successfully set up and started! 🎉"
	@echo "Backend API is available at: http://localhost:8000"
	@echo "Frontend App is available at: http://localhost:3000"

check-env:
	@echo "--- Checking system dependencies... ---"
	@for tool in git docker; do \
		if ! command -v $$tool >/dev/null 2>&1; then \
			echo "❌ Error: Utility '$$tool' not found. Please install it."; \
			exit 1; \
		fi \
	done
	@if ! docker compose version >/dev/null 2>&1; then \
		echo "❌ Error: 'docker compose' is not working. Ensure Docker and Docker Compose V2 are installed and running."; \
		exit 1; \
	fi
	@echo "✅ All system dependencies are in place."

check-setup:
	@if [ ! -f "$(SETUP_MARKER)" ]; then \
		echo "⚠️  Project has not been set up yet."; \
		echo "👉 Please run 'make setup' for initial setup."; \
		exit 1; \
	fi

composer-install:
	@echo "--- Installing PHP dependencies (Composer)... ---"
	@$(COMPOSE_RUN_NO_TTY) tools composer install -d ./backend --no-interaction --prefer-dist

npm-install:
	@echo "--- Installing Node.js dependencies (NPM Workspaces)... ---"
	@$(COMPOSE_RUN_NO_TTY) tools npm install --ignore-scripts --no-funding

# ==============================================================================
# DEVELOPER UTILITIES
# ==============================================================================
.PHONY: backend-shell backend-artisan backend-composer backend-test \
        frontend-shell frontend-npm \
        root-shell root-npm root-npx root-exec lint-staged

# --- Backend Utilities ---
backend-shell: check-setup ## Enter the command line of the `app` container (backend)
	@$(COMPOSE_EXEC) app sh

backend-artisan: check-setup ## Execute an Artisan command (Example: make backend-artisan ARGS="route:list")
	@$(COMPOSE_EXEC) app php artisan $(ARGS)

backend-composer: check-setup ## Execute a Composer command (Example: make backend-composer ARGS="require ...")
	@$(COMPOSE_RUN_NO_TTY) tools composer -d ./backend $(ARGS)

backend-test: check-setup ## Run Laravel tests
	@make backend-artisan ARGS="test"

# --- Frontend Utilities ---
frontend-shell: check-setup ## Enter the command line of the `node` container (frontend)
	@$(COMPOSE_EXEC) node sh

frontend-npm: check-setup ## Execute an npm command in the frontend (Example: make frontend-npm ARGS="install axios")
	@$(COMPOSE_EXEC) node npm $(ARGS)

# --- Project Root Utilities (via 'tools') ---
root-shell: check-setup ## Enter the INTERACTIVE command line of the `tools` container
	@$(COMPOSE_RUN_IT) tools sh

root-npm: check-setup ## Execute an npm command in the project root (Example: make root-npm ARGS="install husky")
	@$(COMPOSE_RUN_NO_TTY) tools npm $(ARGS)

root-npx: check-setup ## Execute an npx command in the project root (Example: make root-npx ARGS="husky init")
	@$(COMPOSE_RUN_NO_TTY) tools npx $(ARGS)

root-exec: check-setup ## Execute any shell command in the `tools` container
	@$(COMPOSE_RUN_NO_TTY) tools sh -c "$(ARGS)"

lint-staged: check-setup ## Runs lint-staged for the pre-commit hook
	@echo "--- Running lint-staged... ---"
	@make root-exec ARGS="npx lint-staged"