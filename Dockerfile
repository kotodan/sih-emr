FROM alpine:3.17

# source https://github.com/openemr/openemr-devops/blob/master/docker/openemr/7.0.1/Dockerfile
#Install dependencies and fix issue in apache
RUN apk --no-cache upgrade
RUN apk add --no-cache \
    apache2 apache2-ssl apache2-utils git php81 php81-tokenizer php81-ctype php81-session php81-apache2 \
    php81-json php81-pdo php81-pdo_mysql php81-curl php81-ldap php81-openssl php81-iconv \
    php81-xml php81-xsl php81-gd php81-zip php81-soap php81-mbstring php81-zlib \
    php81-mysqli php81-sockets php81-xmlreader php81-redis php81-simplexml php81-xmlwriter php81-phar php81-fileinfo \
    php81-sodium php81-calendar php81-intl \
    perl mysql-client tar curl imagemagick nodejs npm \
    python3 openssl py-pip openssl-dev dcron \
    rsync shadow ncurses \
    && sed -i 's/^Listen 80$/Listen 0.0.0.0:80/' /etc/apache2/httpd.conf
# Needed to ensure permissions work across shared volumes with openemr, nginx, and php-fpm dockers
RUN usermod -u 1000 apache

#BELOW LINE NEEDED TO SUPPORT PHP8 ON ALPINE 3.13+; SHOULD BE ABLE TO REMOVE THIS IN FUTURE ALPINE VERSIONS
RUN cp /usr/bin/php81 /usr/bin/php
# Install composer for openemr package building
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

RUN apk add --no-cache git build-base libffi-dev python3-dev cargo \
    && git clone https://github.com/openemr/openemr.git --branch rel-701 --depth 1 \
    && rm -rf openemr/.git \
    && cd openemr \
    && composer install --no-dev \
    && npm install --unsafe-perm \
    && npm run build \
    && cd ccdaservice \
    && npm install --unsafe-perm \
    && cd ../ \
    && composer global require phing/phing \
    && /root/.composer/vendor/bin/phing vendor-clean \
    && /root/.composer/vendor/bin/phing assets-clean \
    && composer global remove phing/phing \
    && composer dump-autoload -o \
    && composer clearcache \
    && npm cache clear --force \
    && rm -fr node_modules \
    && cd ../ \
    && chmod 666 openemr/sites/default/sqlconf.php \
    && chown -R apache openemr/ \
    && mv openemr /var/www/localhost/htdocs/ \
    && git clone https://github.com/letsencrypt/letsencrypt --depth 1 /opt/certbot \
    && pip install --upgrade pip \
    && pip install -e /opt/certbot/acme -e /opt/certbot/certbot \
    && mkdir -p /etc/ssl/certs /etc/ssl/private \
    && apk del --no-cache git build-base libffi-dev python3-dev cargo \
    && sed -i 's/^ *CustomLog/#CustomLog/' /etc/apache2/httpd.conf \
    && sed -i 's/^ *ErrorLog/#ErrorLog/' /etc/apache2/httpd.conf \
    && sed -i 's/^ *CustomLog/#CustomLog/' /etc/apache2/conf.d/ssl.conf \
    && sed -i 's/^ *TransferLog/#TransferLog/' /etc/apache2/conf.d/ssl.conf
WORKDIR /var/www/localhost/htdocs/openemr
VOLUME [ "/etc/letsencrypt/", "/etc/ssl" ]
