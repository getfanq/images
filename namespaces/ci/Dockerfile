# CI Docker Image for Symfony Projects
# Includes: Ubuntu, Node.js, PHP, Playwright dependencies, pnpm, Composer, Symfony CLI
#
# All software is always installed. Build arguments control versions:
# - UBUNTU_VERSION: Ubuntu base image version
# - NODE_VERSION: Node.js version to install
# - PHP_VERSION: PHP version to install
#
# Fixed components (always latest):
# - pnpm: Always installs latest version
# - Playwright: Only system dependencies via npx playwright install-deps
# - Composer: Always version 2
# - Symfony CLI: Always latest

# Build arguments - these are the only configurable versions
ARG UBUNTU_VERSION=24.04
ARG NODE_VERSION=24
ARG PHP_VERSION=8.2

# Base image
FROM ubuntu:${UBUNTU_VERSION}

# Re-declare ARGs after FROM to make them available in build stages
ARG NODE_VERSION
ARG PHP_VERSION
ARG UBUNTU_VERSION

# Metadata labels (OpenContainer standard)
LABEL org.opencontainers.image.title="CI Image for Symfony Projects"
LABEL org.opencontainers.image.description="CI/CD image with Ubuntu ${UBUNTU_VERSION}, Node.js ${NODE_VERSION}, PHP ${PHP_VERSION}"
LABEL org.opencontainers.image.vendor="fanq"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.source="https://github.com/USERNAME/images"
LABEL maintainer="your-email@example.com"

# Version labels for runtime inspection
LABEL version.ubuntu="${UBUNTU_VERSION}"
LABEL version.node="${NODE_VERSION}"
LABEL version.php="${PHP_VERSION}"

# Environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    NODE_VERSION=${NODE_VERSION} \
    PHP_VERSION=${PHP_VERSION} \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/usr/local/composer \
    PNPM_HOME=/usr/local/bin \
    PATH="/usr/local/bin:${PATH}" \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Create non-root user for running applications (optional but recommended)
# Try to use UID/GID 1000, but if taken, use any available ID
RUN if getent group appuser >/dev/null 2>&1; then \
        echo "Group appuser already exists"; \
    elif getent group 1000 >/dev/null 2>&1; then \
        groupadd appuser; \
    else \
        groupadd -g 1000 appuser; \
    fi && \
    if getent passwd appuser >/dev/null 2>&1; then \
        echo "User appuser already exists"; \
    elif getent passwd 1000 >/dev/null 2>&1; then \
        useradd -m -s /bin/bash -g appuser appuser; \
    else \
        useradd -u 1000 -g appuser -m -s /bin/bash appuser; \
    fi

# Install system dependencies and utilities
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        gnupg \
        lsb-release \
        software-properties-common \
        apt-transport-https \
        git \
        unzip \
        zip \
        build-essential \
        libssl-dev \
        zlib1g-dev \
        libbz2-dev \
        libreadline-dev \
        libsqlite3-dev \
        libxml2-dev \
        libxslt1-dev \
        libffi-dev \
        libyaml-dev \
        mysql-client \
        postgresql-client \
        && rm -rf /var/lib/apt/lists/*

# Install PHP from ondrej/php PPA
RUN add-apt-repository ppa:ondrej/php -y && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        php${PHP_VERSION}-cli \
        php${PHP_VERSION}-fpm \
        php${PHP_VERSION}-common \
        php${PHP_VERSION}-mysql \
        php${PHP_VERSION}-pgsql \
        php${PHP_VERSION}-sqlite3 \
        php${PHP_VERSION}-xml \
        php${PHP_VERSION}-curl \
        php${PHP_VERSION}-mbstring \
        php${PHP_VERSION}-intl \
        php${PHP_VERSION}-zip \
        php${PHP_VERSION}-bcmath \
        php${PHP_VERSION}-gd \
        php${PHP_VERSION}-redis \
        php${PHP_VERSION}-opcache \
        php${PHP_VERSION}-apcu \
        php${PHP_VERSION}-amqp \
        && rm -rf /var/lib/apt/lists/*

# Configure PHP for CI environment
RUN echo "memory_limit = 512M" > /etc/php/${PHP_VERSION}/cli/conf.d/99-ci.ini && \
    echo "max_execution_time = 300" >> /etc/php/${PHP_VERSION}/cli/conf.d/99-ci.ini && \
    echo "error_reporting = E_ALL" >> /etc/php/${PHP_VERSION}/cli/conf.d/99-ci.ini && \
    echo "display_errors = On" >> /etc/php/${PHP_VERSION}/cli/conf.d/99-ci.ini && \
    echo "opcache.enable = 1" >> /etc/php/${PHP_VERSION}/cli/conf.d/99-ci.ini && \
    echo "opcache.enable_cli = 1" >> /etc/php/${PHP_VERSION}/cli/conf.d/99-ci.ini && \
    echo "date.timezone = UTC" >> /etc/php/${PHP_VERSION}/cli/conf.d/99-ci.ini

# Create symlink for default PHP version
RUN update-alternatives --set php /usr/bin/php${PHP_VERSION}

# Install Composer (always version 2)
RUN curl -sS https://getcomposer.org/installer | php -- \
    --install-dir=/usr/local/bin \
    --filename=composer && \
    chmod +x /usr/local/bin/composer && \
    mkdir -p ${COMPOSER_HOME} && \
    chown -R appuser:appuser ${COMPOSER_HOME}

# Install Node.js from NodeSource and pnpm
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/* && \
    node --version && \
    npm --version && \
    npm install -g pnpm && \
    npm cache clean --force

# Install Playwright system dependencies (no specific version)
# Note: This only installs OS dependencies, not the browsers themselves
# Browsers will be installed in CI when running `pnpm exec playwright install`
RUN npx -y playwright install-deps

# Install Symfony CLI
RUN curl -1sLf 'https://dl.cloudsmith.io/public/symfony/stable/setup.deb.sh' | bash && \
    apt-get update && \
    apt-get install -y symfony-cli && \
    rm -rf /var/lib/apt/lists/*

# Clean up APT cache and temporary files to reduce image size
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* /usr/share/man/*

# Verify installations and print versions
RUN echo "=== Installed Versions ===" && \
    echo "Ubuntu: $(lsb_release -d | cut -f2)" && \
    echo "PHP: $(php --version | head -n 1)" && \
    echo "Composer: $(composer --version)" && \
    echo "Node.js: $(node --version)" && \
    echo "npm: $(npm --version)" && \
    echo "pnpm: $(pnpm --version)" && \
    echo "Symfony CLI: $(symfony version)" && \
    echo "Git: $(git --version)" && \
    echo "========================="

# Set working directory
WORKDIR /app

# Change ownership of /app to appuser
RUN chown -R appuser:appuser /app

# Switch to non-root user for better security (optional, can be overridden)
# Uncomment the next line if you want to run as non-root by default
# USER appuser

# Default command
CMD ["/bin/bash"]

# Health check (optional)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD php --version && node --version && symfony version || exit 1
