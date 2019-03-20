# DEV Debian packages stage ###########################################################################################
FROM python:3-stretch AS deb-build

RUN set -x; \
    apt-get update \
    && apt-get install -y --no-install-recommends git \
    curl \
    gpg \
    libsasl2-dev \
    python3-dev \
    libldap2-dev \
    build-essential \
    autoconf \
    ca-certificates \
    node-less \
    fonts-noto-cjk \
    gnupg \
    libssl1.0-dev \
    xz-utils dirmngr \
    python3-renderpm \
    xz-utils \
    libxslt1.1 \
    libldap-2.4-2 \
    libopenjp2-7 \
    libtiff5 \
    libicu57 \
    libxml2  \
    libgmp10 \
    libgnutls30 \
    libhogweed4 \
    libidn11 \
    libldap-common \
    libnettle6  \
    libp11-kit0 \
    libsasl2-2 \
    libsasl2-modules-db \
    libtasn1-6 \
    libjpeg62-turbo \


    && curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.stretch_amd64.deb \
    && echo '7e35a63f9db14f93ec7feeb0fce76b30c08f2057 wkhtmltox.deb' | sha1sum -c - \
    && dpkg --force-depends -i wkhtmltox.deb\
    && apt-get update \
    && apt-get -y install -f --no-install-recommends

RUN set -x; \
    echo 'deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main' > etc/apt/sources.list.d/pgdg.list \
    && export GNUPGHOME="$(mktemp -d)" \
    && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --armor --export "${repokey}" | apt-key add - \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get update  \
    && apt-get install -y postgresql-client

RUN set -x;\
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
  && rm -rf /var/lib/apt/lists/* \
  && rm -rf  /usr/share/doc/*

# Install Odoo
ENV ODOO_VERSION 12.0
RUN set -x; \
    mkdir -p /opt/odoo/odoo-server  /opt/odoo/custom/addons /opt/odoo/b2b/addons \
    && git clone --depth 1 --branch ${ODOO_VERSION} https://www.github.com/odoo/odoo /opt/odoo/odoo-server

COPY libraries.txt /libraries.txt

ONBUILD RUN tar -cvf libraries.tar $(cat libraries.txt)

# DEV Python build PIP modules ########################################################################################

FROM deb-build AS py-build

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
    python3-renderpm

RUN mkdir /pyhton-libs
WORKDIR /pyhton-libs

RUN set -x; \
    curl -sO https://raw.githubusercontent.com/odoo/odoo/12.0/requirements.txt

RUN set -x; \
    printf 'gdata\n python3-openid\n paramiko\n psycogreen\n pysftp\n pyyaml\n simplejson\n unittest2\n nameparser\n' >> requirements.txt \
    && pip3 install --install-option="--prefix=/pyhton-libs" -r requirements.txt



# FINAL stage #########################################################################################################
FROM python:3-slim

COPY --from=py-build /pyhton-libs /usr/local

COPY --from=py-build /libraries.tar /tmp/libraries.tar

RUN set -x; \

    tar -xvf /tmp/libraries.tar -C / \
    && adduser --system --quiet --shell=/bin/bash --home=/opt/odoo --gecos 'ODOO' --group odoo \
    && mkdir -p /var/log/odoo \
    && chown -R odoo:odoo /opt/odoo /var/log/odoo \
    && rm -rf /tmp/libraries.tar \
    && rm -rf /opt/odoo/odoo-server/.git \
    && rm -rf /opt/odoo/odoo-server/doc \
    && rm -rf /var/tmp/*

RUN set -x; \
    pip3 install tz;

# Copy entrypoint script and Odoo configuration file
COPY ./entrypoint.sh /
COPY ./odoo.conf /etc/odoo/odoo.conf
RUN chown odoo /etc/odoo/odoo.conf

VOLUME ["/opt/odoo/custom/addons","/opt/odoo/b2b/addons"]

# Expose Odoo services
EXPOSE 8069 8071

# Set the default config file
ENV ODOO_RC /etc/odoo/odoo.conf

# Set default user when running the container
USER odoo

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/opt/odoo/odoo-server/odoo-bin", "--config=/etc/odoo/odoo.conf", "--logfile=/var/log/odoo/odoo.log"]
