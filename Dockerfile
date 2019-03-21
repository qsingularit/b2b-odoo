######################### DEV Python build PIP modules ################################################################
FROM python:3-stretch AS build

RUN set -x; \
    apt-get update \
    && apt-get install -y --no-install-recommends git \
    curl \
    libsasl2-dev \
    python3-dev \
    libldap2-dev \
    build-essential \
    autoconf \
    ca-certificates \
    fonts-noto-cjk \
    gnupg \
    libssl1.0-dev \
    dirmngr \
    python3-renderpm \
    git

# Install Odoo
ENV ODOO_VERSION 12.0
RUN set -x; \
    mkdir -p /opt/odoo/odoo-server  /opt/odoo/custom/addons /opt/odoo/b2b/addons \
    && git clone --depth 1 --branch ${ODOO_VERSION} https://www.github.com/odoo/odoo /opt/odoo/odoo-server

RUN mkdir /pyhton-libs
WORKDIR /pyhton-libs

RUN set -x; \
    curl -sO https://raw.githubusercontent.com/odoo/odoo/12.0/requirements.txt \
    && printf 'gdata\n python3-openid\n paramiko\n psycogreen\n pysftp\n pyyaml\n simplejson\n unittest2\n nameparser\n' >> requirements.txt \
    && pip3 install --install-option="--prefix=/pyhton-libs" -r requirements.txt

RUN set -x; \
    curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.stretch_amd64.deb \
    && echo '7e35a63f9db14f93ec7feeb0fce76b30c08f2057 wkhtmltox.deb' | sha1sum -c - \
    && dpkg --force-depends -i wkhtmltox.deb\
    && apt-get update \
    && apt-get install -y -f --no-install-recommends


################################ FINAL stage ##########################################################################
FROM python:3-slim

COPY --from=build /pyhton-libs /usr/local

COPY --from=build /opt/odoo /opt/odoo

COPY --from=build /usr/local/lib/libwkhtmltox.* /usr/local/lib/

COPY --from=build /usr/local/bin/wkhtmlto* /usr/local/bin/

RUN set -x; \
    apt-get update \
    && apt-get install -y --no-install-recommends dirmngr gpg libjpeg62-turbo libopenjp2-7 libxslt1.1 libtiff5  \
    && echo 'deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main' > etc/apt/sources.list.d/pgdg.list \
    && export GNUPGHOME="$(mktemp -d)" \
    && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --armor --export "${repokey}" | apt-key add - \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get update  \
    && apt-get install -y --no-install-recommends postgresql-client \
    && adduser --system --quiet --shell=/bin/bash --home=/opt/odoo --gecos 'ODOO' --group odoo

RUN set -x; \
    echo "deb http://deb.nodesource.com/node_8.x stretch main" > /etc/apt/sources.list.d/nodesource.list \
    && export GNUPGHOME="$(mktemp -d)" \
    && repokey='9FD3B784BC1C6FC31A8A0A1C1655A0AB68576280' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --armor --export "${repokey}" | apt-key add - \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g rtlcss \
    && pip3 install tz \
    && adduser --system --quiet --shell=/bin/bash --home=/opt/odoo --gecos 'ODOO' --group odoo \
    && mkdir -p /var/log/odoo \
    && chown -R odoo:odoo /opt/odoo /var/log/odoo \
    && apt-get purge -y gpg dirmngr \
    && apt-get autoclean \
    && rm -rf /opt/odoo/odoo-server/.git \
    && rm -rf /opt/odoo/odoo-server/doc \
    && rm -rf /var/tmp/* \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf  /usr/share/doc/*


# Copy entrypoint script and Odoo configuration file
COPY ./entrypoint.sh /
COPY ./odoo.conf /etc/odoo/odoo.conf

RUN set -x; \
    chown -R odoo:odoo /etc/odoo/odoo.conf \
    && chmod -R 755 /etc/odoo/odoo.conf

VOLUME ["/opt/odoo/custom/addons","/opt/odoo/b2b/addons"]

# Expose Odoo services
EXPOSE 8069 8071

# Set the default config file
ENV ODOO_RC /etc/odoo/odoo.conf

# Set default user when running the container
USER root

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/opt/odoo/odoo-server/odoo-bin", "--config=/etc/odoo/odoo.conf", "--logfile=/var/log/odoo/odoo.log"]
