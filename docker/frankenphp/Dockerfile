FROM dunglas/frankenphp:php8.4

ARG WWWUSER=1000
ARG WWWGROUP=1000

RUN install-php-extensions \
    pdo_pgsql \
    redis \
    intl \
    zip \
    gd \
    opcache \
    pcntl \
    bcmath

# Install Node.js and npm
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs netcat-openbsd

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /app

# Set timezone
ENV TZ=Europe/Rome
RUN ln -snf /usr/share/zoneinfo/Europe/Rome /etc/localtime && echo "Europe/Rome" > /etc/timezone

# Remove ENTRYPOINT - it will be set in docker-compose.yml
CMD ["php-fpm"]
