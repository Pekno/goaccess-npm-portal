FROM alpine:latest AS builder

ARG GOACCESS_VERSION=1.10.1

RUN apk add --no-cache \
        build-base \
        libmaxminddb-dev \
        ncurses-dev \
        musl-locales \
        gettext-dev

# download goaccess
WORKDIR /goaccess-temp
RUN wget -O goaccess.tar.gz "https://tar.goaccess.io/goaccess-${GOACCESS_VERSION}.tar.gz"

# set up goacess-debug
WORKDIR /goaccess-debug
RUN cp /goaccess-temp/goaccess.tar.gz .
RUN tar --strip-components=1  -xzvf goaccess.tar.gz
RUN ./configure --enable-utf8 --enable-geoip=mmdb --with-getline --enable-debug
RUN make
RUN make install

# set up goacess
WORKDIR /goaccess
RUN cp /goaccess-temp/goaccess.tar.gz .
RUN tar --strip-components=1  -xzvf goaccess.tar.gz
RUN sed -i "s/GWSocket<\/a>/GWSocket<\/a> ( <a href='https:\/\/tiny.one\/xgoan'>GOAN<\/a> <span>v1.1.31<\/span> )/" /goaccess/resources/tpls.html
RUN sed -i "s/bottom: 190px/bottom: 260px/" /goaccess/resources/css/app.css
RUN ./configure --enable-utf8 --enable-geoip=mmdb --with-getline
RUN make
RUN make install

FROM alpine:latest
RUN apk add --no-cache \
        bash \
        nginx \
        tini \
        wget \
        curl \
        apache2-utils\
        libmaxminddb \
        tzdata \        
        gettext \
        musl-locales \
        ncurses && \
        rm -rf /var/lib/apt/lists/* && \
        rm /etc/nginx/nginx.conf

COPY --from=builder /goaccess-debug /goaccess-debug
COPY --from=builder /goaccess /goaccess
COPY --from=builder /usr/local/share/locale /usr/local/share/locale

COPY /resources/goaccess/goaccess.conf /goaccess-config/goaccess.conf.bak
COPY /assests/maxmind/GeoLite2-City.mmdb /goaccess-config/GeoLite2-City.mmdb
COPY /assests/maxmind/GeoLite2-ASN.mmdb /goaccess-config/GeoLite2-ASN.mmdb
COPY /assests/maxmind/GeoLite2-Country.mmdb /goaccess-config/GeoLite2-Country.mmdb

# set up nginx
COPY /resources/nginx/header.html /var/www/html/header.html
COPY /resources/nginx/nginx.conf /etc/nginx/nginx.conf
ADD /resources/nginx/.htpasswd /opt/auth/.htpasswd

# favicons
COPY /assests/favicons/favicon.ico /var/www/html/favicon.ico
COPY /assests/favicons/favicon-16x16.png /var/www/html/favicon-16x16.png
COPY /assests/favicons/favicon-32x32.png /var/www/html/favicon-32x32.png
COPY /assests/favicons/apple-touch-icon.png /var/www/html/apple-touch-icon.png
COPY /assests/favicons/android-chrome-192x192.png /var/www/html/android-chrome-192x192.png
COPY /assests/favicons/android-chrome-512x512.png /var/www/html/android-chrome-512x512.png
COPY /assests/favicons/site.webmanifest /var/www/html/site.webmanifest

# goaccess logs
WORKDIR /goaccess-logs

WORKDIR /goan
ADD /resources/scripts/funcs funcs
ADD /resources/scripts/logs logs
COPY /resources/scripts/start.sh start.sh
RUN find /goan -name "*.sh" -exec sed -i 's/\r$//' {} + && chmod +x start.sh

# store archives
RUN mkdir -p /goaccess-logs/archives

# Default port for the main Nginx web UI.
# This can be overridden at runtime by the WEBUI_PORT environment variable.
ARG DEFAULT_WEBUI_PORT=7880

VOLUME ["/opt/log"]
EXPOSE ${DEFAULT_WEBUI_PORT}
#CMD ["bash", "/goan/start.sh"]
ENTRYPOINT ["tini", "--", "/goan/start.sh"]