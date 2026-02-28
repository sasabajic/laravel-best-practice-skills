````skill
---
name: laravel-deployment
description: Laravel deployment best practices including Docker configuration, CI/CD pipelines with GitHub Actions, environment configuration, production optimization, zero-downtime deployment, monitoring, logging, and infrastructure setup.
---

# Laravel Deployment Best Practices

Follow these conventions for deploying, configuring, and monitoring Laravel applications.

## Docker Setup

### Dockerfile (Production)

```dockerfile
FROM php:8.3-fpm-alpine AS base

# Install system dependencies
RUN apk add --no-cache \
    nginx \
    supervisor \
    libpng-dev \
    libzip-dev \
    icu-dev \
    oniguruma-dev \
    && docker-php-ext-install \
    pdo_mysql \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    zip \
    intl \
    opcache

# Install Redis extension
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del .build-deps

# PHP production config
COPY docker/php/php.ini /usr/local/etc/php/conf.d/99-production.ini
COPY docker/php/opcache.ini /usr/local/etc/php/conf.d/opcache.ini

# ------- Build stage -------
FROM base AS build

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Install dependencies first (better Docker cache)
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist

# Copy application
COPY . .

# Finish composer install
RUN composer dump-autoload --optimize --no-dev

# Build frontend assets
RUN apk add --no-cache nodejs npm \
    && npm ci \
    && npm run build \
    && rm -rf node_modules

# ------- Production stage -------
FROM base AS production

WORKDIR /var/www/html

# Copy built application
COPY --from=build /var/www/html /var/www/html

# Copy configs
COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf
COPY docker/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Set permissions
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
```

### Docker Compose (Development)

```yaml
# docker-compose.yml
services:
  app:
    build:
      context: .
      dockerfile: docker/Dockerfile
      target: base
    volumes:
      - .:/var/www/html
      - /var/www/html/vendor # Don't sync vendor from host
    ports:
      - "8000:80"
    depends_on:
      - mysql
      - redis
    environment:
      - APP_ENV=local
      - DB_HOST=mysql
      - REDIS_HOST=redis
      - CACHE_DRIVER=redis
      - SESSION_DRIVER=redis
      - QUEUE_CONNECTION=redis

  mysql:
    image: mysql:8.0
    environment:
      MYSQL_DATABASE: ${DB_DATABASE:-laravel}
      MYSQL_ROOT_PASSWORD: ${DB_PASSWORD:-secret}
    volumes:
      - mysql_data:/var/lib/mysql
    ports:
      - "3306:3306"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  queue:
    build:
      context: .
      dockerfile: docker/Dockerfile
      target: base
    volumes:
      - .:/var/www/html
    command: php artisan queue:work --tries=3 --timeout=90
    depends_on:
      - mysql
      - redis

  scheduler:
    build:
      context: .
      dockerfile: docker/Dockerfile
      target: base
    volumes:
      - .:/var/www/html
    command: >
      sh -c "while true; do php artisan schedule:run --verbose; sleep 60; done"
    depends_on:
      - mysql
      - redis

volumes:
  mysql_data:
```

## GitHub Actions CI/CD

```yaml
# .github/workflows/deploy.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  # ---- Quality checks ----
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
          extensions: mbstring, dom, fileinfo, mysql, redis
          coverage: xdebug

      - name: Install dependencies
        run: composer install --prefer-dist --no-progress

      - name: Code style (Pint)
        run: ./vendor/bin/pint --test

      - name: Static analysis (PHPStan)
        run: ./vendor/bin/phpstan analyse --memory-limit=512M

  # ---- Tests ----
  test:
    runs-on: ubuntu-latest
    needs: quality
    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_ROOT_PASSWORD: password
          MYSQL_DATABASE: testing
        ports:
          - 3306:3306
        options: >-
          --health-cmd="mysqladmin ping"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=3

      redis:
        image: redis:7
        ports:
          - 6379:6379

    steps:
      - uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
          extensions: mbstring, dom, fileinfo, mysql, redis

      - name: Install dependencies
        run: composer install --prefer-dist --no-progress

      - name: Prepare environment
        run: |
          cp .env.ci .env
          php artisan key:generate

      - name: Run tests
        run: php artisan test --parallel --coverage-clover=coverage.xml
        env:
          DB_HOST: 127.0.0.1
          DB_DATABASE: testing
          DB_USERNAME: root
          DB_PASSWORD: password
          REDIS_HOST: 127.0.0.1

  # ---- Deploy ----
  deploy:
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    steps:
      - uses: actions/checkout@v4

      - name: Deploy to production
        # Use your deployment method: Forge, Envoyer, Docker, etc.
        run: echo "Deploy step — configure for your infrastructure"
```

## Environment Configuration

### .env Structure

```env
# Application
APP_NAME="My App"
APP_ENV=production
APP_KEY=base64:...
APP_DEBUG=false
APP_URL=https://myapp.com

# Database
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=myapp
DB_USERNAME=myapp_user
DB_PASSWORD=strong-password-here

# Cache & Session
CACHE_STORE=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

# Redis
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

# Mail
MAIL_MAILER=smtp
MAIL_HOST=smtp.mailgun.org
MAIL_PORT=587
MAIL_USERNAME=
MAIL_PASSWORD=
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS="noreply@myapp.com"
MAIL_FROM_NAME="${APP_NAME}"

# Logging
LOG_CHANNEL=stack
LOG_LEVEL=warning

# AWS / Storage (if applicable)
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=
```

### Environment Rules

- **NEVER commit `.env`** to version control
- Use `.env.example` as a template with placeholder values
- Use `.env.ci` for CI/CD with test values
- All values accessed via `config()` — never `env()` directly
- Use strong, unique passwords for each environment
- Different credentials for local/staging/production

## Production Optimization Checklist

Run these during deployment:

```bash
# Cache everything
php artisan config:cache       # Combine all config into one cached file
php artisan route:cache        # Cache route registrations
php artisan view:cache         # Pre-compile all Blade templates
php artisan event:cache        # Cache event discovery

# Optimize autoloader
composer install --optimize-autoloader --no-dev

# Run migrations
php artisan migrate --force    # --force required in production

# Clear old caches before re-caching
php artisan optimize:clear
php artisan optimize
```

### PHP OPcache Configuration

```ini
; docker/php/opcache.ini
opcache.enable=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=32
opcache.max_accelerated_files=20000
opcache.validate_timestamps=0      ; Disable in production (restart PHP to pick up changes)
opcache.save_comments=1
opcache.jit=1255
opcache.jit_buffer_size=128M
```

## Logging Strategy

```php
// config/logging.php — production stack
'channels' => [
    'stack' => [
        'driver' => 'stack',
        'channels' => ['daily', 'slack'],
        'ignore_exceptions' => false,
    ],

    'daily' => [
        'driver' => 'daily',
        'path' => storage_path('logs/laravel.log'),
        'level' => 'warning',
        'days' => 14,
    ],

    'slack' => [
        'driver' => 'slack',
        'url' => env('LOG_SLACK_WEBHOOK_URL'),
        'level' => 'critical',
    ],
],
```

### Logging Rules

- **Production log level: `warning`** — don't log info/debug in production
- Use `daily` driver with retention (14 days)
- Send `critical` and `emergency` to Slack/PagerDuty
- Always log with context:

```php
Log::error('Payment failed', [
    'order_id' => $order->id,
    'user_id' => $user->id,
    'amount' => $amount,
    'gateway_response' => $response,
]);
```

## Health Checks

```php
// routes/web.php
Route::get('/health', function () {
    try {
        DB::connection()->getPdo();
        Cache::store()->get('health-check');

        return response()->json(['status' => 'ok'], 200);
    } catch (\Exception $e) {
        return response()->json(['status' => 'error', 'message' => $e->getMessage()], 503);
    }
})->name('health');
```

## Monitoring Recommendations

- **Laravel Telescope** — development debugging (queries, requests, jobs, etc.)
- **Laravel Horizon** — Redis queue monitoring dashboard
- **Laravel Pulse** — real-time application performance monitoring
- **Sentry** or **Bugsnag** — error tracking in production
- **Oh Dear** or **UptimeRobot** — uptime monitoring
- Set up **database slow query logging**
- Monitor **queue sizes** — alert if jobs are backing up

## Deployment Script Example

```bash
#!/bin/bash
set -e

echo "🚀 Deploying..."

# Pull latest code
git pull origin main

# Install dependencies
composer install --no-interaction --prefer-dist --optimize-autoloader --no-dev

# Run migrations
php artisan migrate --force

# Clear and rebuild caches
php artisan optimize:clear
php artisan optimize
php artisan view:cache

# Build frontend
npm ci
npm run build

# Restart queue workers
php artisan queue:restart

# Restart PHP-FPM
sudo systemctl reload php8.3-fpm

echo "✅ Deployment complete"
```

````
