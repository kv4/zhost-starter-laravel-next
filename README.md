# Z-Host: Full-Stack Development Environment (Laravel + Next.js on Docker)

[![CI Pipeline](https://github.com/kv4/zhost-starter-laravel-next/actions/workflows/ci.yml/badge.svg)](https://github.com/kv4/zhost-starter-laravel-next/actions/workflows/ci.yml)

This is a boilerplate for rapidly deploying a full-featured and isolated local development environment for full-stack
applications using **Laravel (backend)** and **Next.js (frontend)**.

### What problem does this project solve?

This project eliminates the need to locally install and configure PHP, Node.js, Composer, Nginx, or PostgreSQL on a
developer's machine. It provides a single, reproducible toolset that ensures every team member works in an absolutely
identical environment.

**Core philosophy:** Your host machine remains clean. All dependencies and tools run inside Docker containers.

## Technology Stack

| Service        | Technology                      | Version |
|----------------|---------------------------------|---------|
| **Backend**    | PHP                             | 8.4     |
|                | Laravel                         | 12.x    |
| **Frontend**   | Node.js                         | 22.x    |
|                | Next.js                         | 15.x    |
|                | React                           | 19.x    |
|                | TypeScript                      | 5.x     |
| **Database**   | PostgreSQL                      | 17      |
| **Web Server** | Nginx                           | 1.25    |
| **Tooling**    | Docker Compose                  | v2      |
|                | NPM (with Workspaces)           | 11.x    |
|                | Composer                        | latest  |
|                | Husky + lint-staged             | latest  |
|                | Pint, PHPStan, ESLint, Prettier | latest  |

## Getting Started

### Prerequisites

To work with this project, you only need the following installed on your local machine:

1. **Git**
2. **Docker** and **Docker Compose v2**

You do not need to install PHP, Node.js, Composer, or any other tools globally.

### Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/kv4/zhost-starter-laravel-next.git
   cd zhost-starter-laravel-next
   ```

2. **Run the initial setup:**
   This command automatically performs all necessary steps: it creates a `.env` file, builds the Docker images, installs
   all Composer and NPM dependencies, starts the containers, and runs database migrations.
   ```bash
   make setup
   ```

3. **Done!** After the setup is complete, the services will be available at the following addresses:
    * **Backend API (Laravel):** [http://localhost:8000](http://localhost:8000)
    * **Frontend App (Next.js):** [http://localhost:3000](http://localhost:3000)

## Daily Usage (Core Commands)

The environment is managed using a `Makefile`, which provides a simple interface to Docker Compose and other tools.

| Command             | Des cription                                                                                                | Example Usage                                          |
|---------------------|-------------------------------------------------------------------------------------------------------------|--------------------------------------------------------|
| `make up`           | S tarts all c         ontainers in the background.                                                          | `make up`                                              |
| `make down`         | Stops and re        moves all containers.                                                                   | `make down`                                            |
| `make build`        | Rebuilds Doc      ker images if you have changed a `Dockerfile`.                                            | `make build`                                           |
| `make clean`        | **(DANGEROUS      !)** Completely cleans the project: removes containers, DB volumes, and all dependencies. | `make clean`                                           |
| `backend-shel l`    | Opens a comm   and line inside the `app` container (PHP/Laravel).                                           | `make backend-shell`                                   |
| `backend-arti san`  | Executes a L aravel Artisan command.                                                                        | `make backend-artisan ARGS="route:list"`               |
| `backend-comp oser` | Executes a C omposer command for the backend.                                                               | `make backend-composer ARGS="require laravel/sanctum"` |
| `backend-test `     | Runs PHPUnit     tests for Laravel.                                                                         | `make backend-test`                                    |
| `frontend-she ll`   | Opens a comm  and line inside the `node` container (Next.js).                                               | `make frontend-shell`                                  |
| `frontend-npm `     | Executes an     NPM command for the frontend.                                                               | `make frontend-npm ARGS="install axios"`               |
| `root-shell`        | Opens a comm      and line inside the `tools` container.                                                    | `make root-shell`                                      |
| `root-npm`          | Executes an         NPM command in the project root (for dev dependencies).                                 | `make root-npm ARGS="install -D typescript"`           |

## Architecture and Concept

#### Service Roles

* `app`: The PHP-FPM process for executing Laravel code.
* `web`: The Nginx web server, which proxies requests to `app` and serves static assets.
* `db`: The PostgreSQL database server.
* `node`: The Next.js development server with Fast Refresh support.
* `tools`: A utility container with all necessary CLI tools (PHP, Node, Composer, Git). **All `make` commands are
  executed through it.**

#### Live Reload and `volumes`

For a seamless development experience, your project's source code is mounted directly into the containers using Docker
`volumes`. This means that any changes you make to the code on your host machine are instantly reflected inside the
containers, enabling live reloading.

#### NPM Workspaces and `node_modules`

The project uses NPM Workspaces to manage dependencies in the monorepo. Running `npm install` from the root installs all
dependencies into a single `node_modules` folder in the project root. This folder is then mounted into the `node`
service, giving it access to all required packages.

## Automation and Code Quality

The project is configured to maintain high code quality through automated tools.

* **Tooling:**
    * **Pint** and **PHPStan** for formatting and static analysis of PHP code.
    * **ESLint** for static analysis of TypeScript/JavaScript code.
    * **Prettier** for formatting all code across the project.

* **Pre-commit Hook:** A pre-commit hook is set up using **Husky** and **lint-staged**. Before each commit, all staged
  files are automatically checked and formatted. This ensures that only code conforming to standards enters the
  repository.

* **CI Pipeline:** The `.github/workflows/ci.yml` file defines a GitHub Actions pipeline that runs the same code quality
  checks on the server with every push or pull request.

* **Local CI Testing:** You can run a full simulation of the CI pipeline locally using the script:
  ```bash
  ./scripts/local-test.sh
  ```

## From Development to Production

It is important to understand what this project is **not**.

* **This is not a production-ready deployment solution.**

The current Docker configuration is optimized for **local development** (using `volumes`, running dev servers).
Deploying to production will require creating separate, optimized `Dockerfile.prod` files for each service (`frontend`
and `app`) that will:

1. Use multi-stage builds to reduce the final image sizes.
2. **`COPY`** the source code and build artifacts into the image, rather than mounting them with `volumes`.
3. Run the applications in production mode (`npm start` instead of `npm run dev`).

However, the project structure is fully prepared for developers to add such configurations for their own needs.