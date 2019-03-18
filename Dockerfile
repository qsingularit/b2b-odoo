FROM debian:stretch

RUN set -x; \
    apt-get update \
    && apt-get install -y --no-install-recommends curl git libsasl2-dev python3-dev libldap2-dev build-essential autoconf\
      ca-certificates \
    	node-less \
      fonts-noto-cjk \
    	gnupg \
      libssl1.0-dev \
    	node-less \
      xz-utils dirmngr \
      python3-pip \
      python3-pyldap \
      python3-qrcode \
      python3-renderpm \
      python3-setuptools \
      python3-vobject \
      python3-watchdog \
	&& curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.stretch_amd64.deb \
  && echo '7e35a63f9db14f93ec7feeb0fce76b30c08f2057 wkhtmltox.deb' | sha1sum -c - \
  && dpkg --force-depends -i wkhtmltox.deb\
  && apt-get -y install -f --no-install-recommends \
  && rm -rf /var/lib/apt/lists/* wkhtmltox.deb

RUN set -x; \
  echo 'deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main' > etc/apt/sources.list.d/pgdg.list \
  && export GNUPGHOME="$(mktemp -d)" \
  && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
  && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
  && gpg --armor --export "${repokey}" | apt-key add - \
  && gpgconf --kill all \
  && rm -rf "$GNUPGHOME" \
  && apt-get update  \
  && apt-get install -y --no-install-recommends postgresql-client \
  && rm -rf /var/lib/apt/lists/*

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
  && rm -rf /var/lib/apt/lists/*

RUN set -x; \
  curl -sO https://raw.githubusercontent.com/odoo/odoo/12.0/requirements.txt \
  && pip3 install -r requirements.txt \
  && pip3 install gdata python3-openid paramiko psycogreen pysftp pyyaml simplejson tz unittest2 nameparser xlwt

# Install Odoo
ENV ODOO_VERSION 12.0
RUN set -x; \
    mkdir -p /opt/odoo/odoo-server /var/log/odoo /opt/odoo/custom/addons /opt/odoo/b2b/addons\
    && adduser --system --quiet --shell=/bin/bash --home=/opt/odoo --gecos 'ODOO' --group odoo \
    && chown -R odoo:odoo /opt/odoo /var/log/odoo \
    && git clone --depth 1 --branch ${ODOO_VERSION} https://www.github.com/odoo/odoo /opt/odoo/odoo-server

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
