#!/bin/sh
set -e

# Wait for PostgreSQL
echo "Waiting for PostgreSQL..."
until nc -z -v -w30 "$DB_HOST" "$DB_PORT"; do
  echo "Waiting for database connection..."
  sleep 1
done
echo "PostgreSQL is ready!"

# Install dependencies if vendor is missing
if [ ! -d "vendor" ]; then
    composer install
fi

# Ensure storage directories exist and have correct permissions
mkdir -p storage/logs storage/framework/cache storage/framework/views storage/framework/sessions
chmod -R 775 storage bootstrap/cache

# Run migrations
php artisan migrate --force

# Create storage link
php artisan storage:link

# Start Octane
exec php artisan octane:frankenphp --host=0.0.0.0 --port=8000
