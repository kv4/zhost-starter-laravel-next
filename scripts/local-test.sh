#!/bin/bash

# ==============================================================================
#
#   Script for full local environment testing
#
#   Concept:
#   - The host machine only has `git`, `docker`, and `make`.
#   - All dependencies (PHP, Node.js, Composer, NPM, linters)
#     run strictly inside Docker containers.
#   - Git operations are performed on the host for hooks to work correctly.
#
# ==============================================================================

# --- Configuration and Utility Functions ---

# Exit immediately if a command exits with a non-zero status.
set -e
set -o pipefail

# Color definitions for output.
readonly NC='\033[0m'
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'

# Logging functions.
log_header() {
  echo -e "\n${BLUE}======================================================================${NC}"
  echo -e "${BLUE}▶ $1${NC}"
  echo -e "${BLUE}======================================================================${NC}"
}

log_info() {
  echo -e "${YELLOW}INFO: $1${NC}"
}

log_success() {
  echo -e "${GREEN}SUCCESS: $1${NC}"
}

log_error() {
  echo -e "${RED}ERROR: $1${NC}" >&2
  exit 1
}


# --- Core Test Functions ---

cleanup() {
  log_header "Step 1: Full Environment Cleanup"

  log_info "Stopping and removing Docker containers and volumes..."
  make down > /dev/null 2>&1 || log_info "Docker environment was already stopped."
  log_success "Docker environment cleaned up."

  log_info "Removing local dependencies (node_modules, vendor)..."
  sudo rm -rf node_modules
  sudo rm -rf frontend/node_modules
  sudo rm -rf backend/vendor
  log_success "Local dependencies removed."
}

setup_dependencies() {
  log_header "Step 2: Installing Dependencies"

  log_info "Rebuilding Docker images, including 'tools'..."
  make build
  log_success "Docker images built successfully."

  log_info "Installing Node.js dependencies (inside Docker)..."
  make root-npm ARGS="install"
  log_success "Node.js dependencies installed successfully."

  log_info "Installing PHP dependencies (inside Docker)..."
  make composer-install
  log_success "PHP dependencies installed successfully."
}

test_ci_simulation() {
  log_header "Step 3: Simulating CI Pipeline Execution (all commands in Docker)"

  log_info "Checking PHP code quality (Pint & PHPStan)..."
  docker compose run --rm --user=root tools sh -c "./backend/vendor/bin/pint --test && ./backend/vendor/bin/phpstan analyse -c ./backend/phpstan.neon --memory-limit=2G"
  log_success "PHP code meets quality standards."

  log_info "Checking formatting (Prettier)..."
  docker compose run --rm --user=root tools npx prettier --check .
  log_success "Code formatting meets Prettier standards."

  log_info "Checking Frontend code quality (ESLint)..."
  docker compose run --rm --user=root tools npm run lint -w frontend
  log_success "Frontend code meets ESLint standards."
}

test_git_hook() {
  log_header "Step 4: Testing pre-commit hook (on the host)"

  local readonly TARGET_FILE="frontend/src/app/page.tsx"
  if [ ! -f "$TARGET_FILE" ]; then
    log_error "Test file '$TARGET_FILE' not found."
  fi

  # 1. Ensure a clean state before the test.
  # `git restore` will revert any uncommitted changes in the file.
  git restore "$TARGET_FILE"

  log_info "Introducing incorrect formatting into '$TARGET_FILE'..."
  echo "" >> "$TARGET_FILE"

  # 2. Add the modified file to the index so lint-staged can see it.
  git add "$TARGET_FILE"

  log_info "Running lint-staged directly to simulate the hook..."
  # This is the cleanest approach. We don't make fake commits, but simply
  # run the tool that is called by the hook. We expect it to fix the file
  # and exit successfully.
  set +e # Temporarily disable exit on error
  make lint-staged
  LINT_STAGED_STATUS=$?
  set -e


  # 3. Check the working directory status.
  # `git diff --quiet` will return 0 (success) if there are no changes.
  if git diff --quiet; then
    log_success "lint-staged ran, and the file was fixed (no changes). The hook is working!"
  else
    # If `git diff` finds changes, it means the formatter did not fix the file.
    git restore "$TARGET_FILE"
    log_error "File remained modified after running lint-staged. The hook is NOT working."
  fi

  # 4. Verify that lint-staged did not fail due to a configuration error.
  if [ $LINT_STAGED_STATUS -ne 0 ]; then
      git restore "$TARGET_FILE"
      log_error "lint-staged exited with an error. Check the configuration."
  fi

  # 5. Final cleanup.
  git restore "$TARGET_FILE"
}

# --- Script Entrypoint ---

main() {
  cleanup
  setup_dependencies
  test_ci_simulation
  test_git_hook

  log_header "Final Report"
  log_success "All local tests passed successfully!"
  echo -e "${GREEN}The environment is fully configured and ready for work.${NC}"
}

# Run the main function.
main