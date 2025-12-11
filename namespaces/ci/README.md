# CI Namespace - Docker Images for Symfony Projects

Docker images optimized for CI/CD pipelines running Symfony applications with modern JavaScript tooling (Node.js, pnpm) and end-to-end testing (Playwright).

## Available Images

### Quick Reference

```bash
# Latest stable (Ubuntu 24.04, Node 20, PHP 8.3, Playwright latest)
docker pull ghcr.io/username/ci:latest
docker pull ghcr.io/username/ci:symfony7

# Symfony 6.x LTS (Ubuntu 22.04, Node 20, PHP 8.2)
docker pull ghcr.io/username/ci:symfony6-lts

# Cutting edge (Ubuntu 24.04, Node 22, PHP 8.4)
docker pull ghcr.io/username/ci:edge

# Specific version tags
docker pull ghcr.io/username/ci:ubuntu24.04-node20-php8.3-playwright1.48.0
```

## Image Variants

| Tag | Ubuntu | Node.js | PHP | Playwright | Size | Description |
|-----|--------|---------|-----|------------|------|-------------|
| `latest`, `symfony7` | 24.04 | 20 LTS | 8.3 | latest | ~1GB | Modern Symfony 7.x stack |
| `edge` | 24.04 | 22 | 8.4 | latest | ~1GB | Bleeding edge versions |
| `symfony6-lts`, `lts` | 22.04 | 20 LTS | 8.2 | latest | ~950MB | Symfony 6.x LTS stable |
| `legacy` | 22.04 | 18 LTS | 8.1 | 1.40.0 | ~900MB | Legacy project support |
| `php8.4` | 24.04 | 20 LTS | 8.4 | latest | ~1GB | Latest PHP 8.4 |
| `node22` | 24.04 | 22 | 8.3 | latest | ~1GB | Latest Node.js 22 |

## Installed Software

### PHP

All images include PHP with the following extensions:

**Core Extensions:**
- cli, fpm, common, xml, curl, mbstring, intl, zip

**Database Drivers:**
- mysql, pgsql, sqlite3

**Performance & Caching:**
- opcache, apcu, redis

**Messaging:**
- amqp (RabbitMQ)

**Utilities:**
- bcmath, gd

**PHP Configuration (CI-optimized):**
- `memory_limit`: 512M
- `max_execution_time`: 300
- `opcache.enable`: 1
- `error_reporting`: E_ALL

### Node.js & Package Managers

- **Node.js**: 18.x, 20.x, or 22.x (depending on tag)
- **npm**: Bundled with Node.js
- **pnpm**: Latest stable version

### Symfony Tools

- **Composer**: Version 2.x (latest stable)
- **Symfony CLI**: Latest stable version

### Playwright

- **System dependencies**: Pre-installed (required for browser execution)
- **Browsers**: NOT pre-installed (install on-demand in your CI pipeline)

To install browsers in your CI pipeline:
```bash
pnpm exec playwright install chromium
# or
npx playwright install --with-deps
```

### Database Clients

- `mysql-client` - MySQL/MariaDB command-line client
- `postgresql-client` - PostgreSQL command-line client

### System Tools

- git
- unzip, zip
- curl, wget
- build-essential (gcc, g++, make)

## Usage Examples

### GitHub Actions

```yaml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/username/ci:symfony7
      
    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_ROOT_PASSWORD: root
          MYSQL_DATABASE: test_db
        options: >-
          --health-cmd="mysqladmin ping"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=3
          
    steps:
      - uses: actions/checkout@v4
      
      - name: Install dependencies
        run: |
          composer install --no-interaction --prefer-dist
          pnpm install --frozen-lockfile
      
      - name: Setup database
        run: |
          php bin/console doctrine:database:create --env=test
          php bin/console doctrine:migrations:migrate --no-interaction --env=test
      
      - name: Run PHP tests
        run: php bin/phpunit
      
      - name: Install Playwright browsers
        run: pnpm exec playwright install chromium
      
      - name: Run E2E tests
        run: pnpm test:e2e
```

### GitLab CI

```yaml
image: ghcr.io/username/ci:symfony7

variables:
  MYSQL_ROOT_PASSWORD: root
  MYSQL_DATABASE: test_db
  DATABASE_URL: "mysql://root:root@mysql:3306/test_db"

services:
  - mysql:8.0

stages:
  - build
  - test

install:
  stage: build
  script:
    - composer install --no-interaction
    - pnpm install --frozen-lockfile
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - vendor/
      - node_modules/

test:php:
  stage: test
  script:
    - php bin/phpunit
  dependencies:
    - install

test:e2e:
  stage: test
  script:
    - pnpm exec playwright install chromium
    - pnpm test:e2e
  dependencies:
    - install
```

### Docker Compose

```yaml
version: '3.8'

services:
  php:
    image: ghcr.io/username/ci:symfony7
    working_dir: /app
    volumes:
      - .:/app
    environment:
      DATABASE_URL: mysql://root:root@mysql:3306/app_db
    depends_on:
      - mysql
      
  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: app_db
    volumes:
      - mysql_data:/var/lib/mysql

volumes:
  mysql_data:
```

### Local Development

```bash
# Run commands in the container
docker run --rm -v $(pwd):/app -w /app ghcr.io/username/ci:symfony7 composer install

# Start an interactive shell
docker run --rm -it -v $(pwd):/app -w /app ghcr.io/username/ci:symfony7 bash

# Run tests
docker run --rm -v $(pwd):/app -w /app ghcr.io/username/ci:symfony7 php bin/phpunit
```

## Building Custom Images

### Build Locally

```bash
# Build default configuration
./build.sh --name symfony7-latest

# Build with custom options
docker build \
  --build-arg UBUNTU_VERSION=24.04 \
  --build-arg NODE_VERSION=20 \
  --build-arg PHP_VERSION=8.3 \
  --build-arg PLAYWRIGHT_VERSION=latest \
  -t my-custom-ci:latest \
  -f Dockerfile \
  .
```

### Customize Build Matrix

Edit `config.yml` to add new combinations:

```yaml
build_matrix:
  - name: "my-custom"
    ubuntu: "24.04"
    node: "20"
    php: "8.3"
    playwright: "latest"
    aliases:
      - "custom"
    description: "My custom CI image"
```

Then build:
```bash
./build.sh --name my-custom
```

## Configuration

### PHP Extensions

To add additional PHP extensions, edit the `Dockerfile`:

```dockerfile
RUN apt-get update && \
    apt-get install -y \
        php${PHP_VERSION}-mongodb \
        php${PHP_VERSION}-imagick \
    && rm -rf /var/lib/apt/lists/*
```

### Node.js Packages

To pre-install global Node packages, edit the `Dockerfile`:

```dockerfile
RUN pnpm add -g @symfony/webpack-encore
```

### System Packages

To add system tools, edit the `Dockerfile`:

```dockerfile
RUN apt-get update && \
    apt-get install -y \
        imagemagick \
        ffmpeg \
    && rm -rf /var/lib/apt/lists/*
```

## Optimization Tips

### Reduce Build Time

1. **Use build cache**: Enable BuildKit caching
   ```bash
   DOCKER_BUILDKIT=1 docker build --cache-from ghcr.io/username/ci:latest .
   ```

2. **Pre-install dependencies**: Create a custom image with your app dependencies
   ```dockerfile
   FROM ghcr.io/username/ci:symfony7
   COPY composer.json composer.lock ./
   RUN composer install --no-scripts
   COPY package.json pnpm-lock.yaml ./
   RUN pnpm install --frozen-lockfile
   ```

### Reduce Image Size

1. **Don't pre-install Playwright browsers**: Set in `config.yml`:
   ```yaml
   playwright:
     install_browsers: false
   ```

2. **Use multi-stage builds**: For production images, copy only necessary artifacts

3. **Clean up**: The images already clean APT cache, but you can add more cleanup steps

## Troubleshooting

### Playwright Browser Issues

**Problem**: Playwright can't find browsers

**Solution**: Install browsers in your CI pipeline:
```bash
pnpm exec playwright install chromium --with-deps
```

### Permission Issues

**Problem**: Permission denied errors

**Solution**: The image creates a non-root user `appuser`. Use it:
```dockerfile
USER appuser
```

Or run as root:
```bash
docker run --rm -u root ...
```

### Memory Issues

**Problem**: Out of memory during builds

**Solution**: The PHP memory limit is set to 512M. Increase if needed:
```bash
docker run --rm -e PHP_MEMORY_LIMIT=1G ...
```

Or edit `/etc/php/{VERSION}/cli/conf.d/99-ci.ini` in a custom image.

### Database Connection Issues

**Problem**: Can't connect to database service

**Solution**: Ensure database service is healthy:
```yaml
services:
  mysql:
    image: mysql:8.0
    options: >-
      --health-cmd="mysqladmin ping"
      --health-interval=10s
```

## Version Support

### PHP Versions

| Version | Active Support Until | Security Support Until |
|---------|---------------------|------------------------|
| 8.1 | Ended | 2025-11-25 |
| 8.2 | 2025-12-08 | 2026-12-08 |
| 8.3 | 2025-11-23 | 2026-11-23 |
| 8.4 | 2026-11-21 | 2027-11-21 |

### Node.js Versions

| Version | LTS Name | Active Until | Maintenance Until |
|---------|----------|--------------|-------------------|
| 18.x | Hydrogen | 2023-10-18 | 2025-04-30 |
| 20.x | Iron | 2024-10-22 | 2026-04-30 |
| 22.x | - | Current | 2027-04-30 |

### Ubuntu Versions

| Version | Codename | Support Until |
|---------|----------|---------------|
| 22.04 | Jammy Jellyfish | 2027-04 |
| 24.04 | Noble Numbat | 2029-04 |

## Support

For issues specific to these images:
- Check the main [README](../../README.md)
- Open an issue on GitHub
- Review build logs in GitHub Actions

## Changelog

See the main repository [CHANGELOG.md](../../CHANGELOG.md) for version history.
