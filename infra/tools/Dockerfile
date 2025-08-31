# Use a lightweight base image that already includes Node.js, npm, and npx
FROM node:22-alpine

# Install system packages required to run the tools
# - git: Required for lint-staged and other git operations.
# - php and extensions: For running PHP tools like Composer and Pint.
# - unzip: Required for Composer.
RUN apk add --no-cache \
    git \
    php83 \
    php83-cli \
    php83-dom \
    php83-mbstring \
    php83-tokenizer \
    php83-xml \
    php83-pdo \
    php83-pdo_pgsql \
    php83-phar \
    php83-openssl \
    php83-session \
    php83-fileinfo \
    php83-iconv \
    php83-xmlwriter \
    unzip

RUN npm install -g npm@11.5.2

# Install Composer globally by copying it from the official image
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set the working directory. Commands will be executed from /app
WORKDIR /app

# Create a non-privileged user to run commands.
# We do not assign a specific UID/GID, as they will be passed when starting
# the container from the host machine to avoid file permission issues.
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Add the application directory to Git's list of safe directories
RUN git config --global --add safe.directory /app

# Switch to this user. All default commands
# will be executed as this user.
USER appuser