# Use the desired Node.js image
FROM node:22-alpine

# Declare arguments for UID/GID, just like for PHP
ARG UID=1000
ARG GID=1000

# Check if a group with GID exists, if not - create it.
# Check if a user with UID exists, if not - create and add them to the group.
RUN \
    if [ $(getent group ${GID}) ]; then \
        echo "Group with GID ${GID} already exists."; \
    else \
        addgroup -g ${GID} -S appgroup; \
    fi && \
    if [ $(getent passwd ${UID}) ]; then \
        echo "User with UID ${UID} already exists."; \
    else \
        adduser -u ${UID} -G $(getent group ${GID} | cut -d: -f1) -S appuser; \
    fi


# Create the working directory and immediately assign the correct owner
# Use numeric IDs, as names can differ
RUN mkdir -p /app && chown -R ${UID}:${GID} /app

# Switch to our user by UID
USER ${UID}

# Set the working directory
WORKDIR /app