# Use the same base image
FROM php:8.4-fpm-alpine

# Install system dependencies, as before
RUN apk add --no-cache \
    postgresql-dev \
    libzip-dev \
    zip \
    unzip

# Install PHP extensions, as before
RUN docker-php-ext-install \
    pdo_pgsql \
    pgsql \
    bcmath \
    zip

# Install Composer, as before
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Declare arguments that will be passed from docker-compose.yml
# Set default values to 1000 if they are not passed
ARG UID=1000
ARG GID=1000

# Create a group with the required GID
RUN addgroup -g ${GID} -S appgroup
# Create a user with the required UID and add them to the created group
RUN adduser -u ${UID} -G appgroup -S appuser

# Switch to the newly created user.
# All subsequent commands in this Dockerfile and the default process
# will be executed as this user.
USER appuser

# Set the working directory, as before
WORKDIR /var/www/html