################################################################################
# Docker compose Drupal full dev stack.
#
# A single Docker compose file that try to simply and quickly setup a full
# Drupal development environment.
#
# Project page:
#   https://github.com/Mogtofu33/docker-compose-drupal
#
# Quick set-up:
#  Copy this file, rename to docker-compose.yml, comment or remove services
#  definition based on your needs.
#  Copy and rename default.env to .env
#  Launch:
#    docker-compose up
#
# You can check your config after editing this file with:
#   docker-compose config
#
# Services settings are in config folder, check and adapt to your needs.
#
# Windows limitations
#   If you run Docker Compose from Powershell, before launch run:
#   :COMPOSE_CONVERT_WINDOWS_PATHS=1
#
#   Ownership do not permit to use the dashboard and to share db directory for
#   MySQL/MariaDB or PgSQL. See comments below.
#
# For more information on docker compose file structure:
# @see https://docs.docker.com/compose/
#
################################################################################
version: '3'
volumes:
  sock:
services:
  apache:
    image: $APACHE_IMAGE
    ports:
      - "${APACHE_HOST_HTTP_PORT:-80}:80"
      - "${APACHE_HOST_HTTPS_PORT:-443}:443"
      # Web root access, optional but can help with multi sites.
      - 81:81
      # Used by dashboard.
      - "${APACHE_HOST_DASHBORAD_PORT:-8181}:8181"
    links:
      - php
    volumes:
      - ${HOST_WEB_ROOT:-./data/www}:/var/www/localhost
      # Apache configuration with SSL support.
      - ./config/apache/httpd.conf:/etc/apache2/httpd.conf
      - ./config/apache/vhost.conf:/etc/apache2/vhost.conf
      - ./config/apache/conf.d/:/etc/apache2/conf.d/
      - ./config/apache/ssl/:/etc/ssl/apache2/
      # Used by dashboard and tools.
      - ./build/dashboard/build:/var/www/dashboard
      - ./tools:/var/www/dashboard/tools
      # Php FPM socket
      - sock:/sock
      ## If PgSQL, ease drush pgsql access.
      - ./config/pgsql/.pg_pass:/home/apache/.pg_pass
    env_file: .env
    container_name: dcd-apache
    ## Remove to avoid starting on system reboot.
    restart: always
  php:
    image: $PHP_IMAGE:${PHP_VERSION:-7.1}
    volumes:
      - ${HOST_WEB_ROOT:-./data/www}:/var/www/localhost
      - ./config/php/${PHP_VERSION:-7.1}/php.ini:/etc/php${PHP_MAJOR_VERSION:-7}/php.ini
      - ./config/php/${PHP_VERSION:-7.1}/php-fpm.conf:/etc/php${PHP_MAJOR_VERSION:-7}/php-fpm.conf
      - ./config/php/${PHP_VERSION:-7.1}/conf.d/:/etc/php${PHP_MAJOR_VERSION:-7}/conf.d/
      - ./config/php/${PHP_VERSION:-7.1}/php-fpm.d/:/etc/php${PHP_MAJOR_VERSION:-7}/php-fpm.d/
      # Drush 9 alias and drushrc files (or any other config)
      - ./config/drush/d.alias.yml:/etc/drush/d.alias.yml
      - ./config/drush/drush.yml:/etc/drush/drush.yml
      # Used by dashboard and tools.
      - ./build/dashboard/build:/var/www/dashboard
      - ./tools:/var/www/dashboard/tools
      - /var/run/docker.sock:/var/run/docker.sock
      # Share db dump folder.
      - ${HOST_DATABASE_DUMP:-./data/dump}:/dump
      # Php FPM socket
      - sock:/sock
      ## If PgSQL, ease drush pgsql access.
      - ./config/pgsql/.pg_pass:/home/apache/.pg_pass
      ## If you have composer set locally, share cache to speed up.
      # - REPLACE_WITH_COMPOSER_HOME_PATH/.composer/cache:/composer/cache
    links:
      # Choose database, uncomment service concerned below.
      - mysql
      - pgsql
      # Choose optionnal services.
      - memcache
      - redis
      - solr
      - mailhog
      # - varnish
    env_file: .env
    container_name: dcd-php
    # Privileged is needed to access docker.sock
    ## Not supported on Windows system yet. Cannot provide Dashboard.
    privileged: true
    # Remove to avoid starting on system reboot.
    restart: always
  mysql:
    image: $MYSQL_IMAGE
    expose:
      - "3306"
    volumes:
      # Any .sql file will be imported in the MYSQL_DATABASE defined on your
      # .env (default: drupal).
      - ${HOST_DATABASE_DUMP:-./data/dump}:/docker-entrypoint-initdb.d
      ## Comment these two lines on Windows system, permissions issue.
      - ${HOST_DATABASE_MYSQL:-./data/database/mysql}:/var/lib/mysql
      - ./config/mysql:/etc/mysql
    env_file: .env
    ## Remove to avoid starting on system reboot.
    restart: always
  pgsql:
    image: $PGSQL_IMAGE
    expose:
      - "5432"
    ## Comment these two lines on Windows system, permissions issue.
    volumes:
      - ${HOST_DATABASE_DUMP:-./data/dump}:/dump
      - ${HOST_DATABASE_POSTGRES:-./data/database/pgsql}:/var/lib/postgresql/data
      # Add pg_pass to ease drush access.
      - ./config/pgsql/.pg_pass:/home/postgres/.pg_pass
    env_file: .env
    ## Remove to avoid starting on system reboot.
    restart: always
  mailhog:
    image: mailhog/mailhog:latest
    expose:
      - "1025"
    ports:
      - "8025:8025"
    ## Remove to avoid starting on system reboot.
    restart: always
  memcache:
    image: memcached:alpine
    expose:
      - "11211"
    ## Remove to avoid starting on system reboot.
    restart: always
  redis:
    image: redis:alpine
    expose:
      - "6379"
    ## Remove to avoid starting on system reboot.
    restart: always
  solr:
    build: ./build/solr-${SOLR_VERSION:-7}
    ports:
      - "8983:8983"
    environment:
      - EXTRA_ACCESS="/solr/drupal"
    ## Remove to avoid starting on system reboot.
    restart: always
  # varnish:
  #   build: ./build/varnish
  #   ports:
  #     - "${VARNISH_HOST_PORT:-8080}:80"
  #     - "6082:6082"
  #   links:
  #     - apache
  #   env_file: .env
  #   ## Remove to avoid starting on system reboot.
  #   restart: always
