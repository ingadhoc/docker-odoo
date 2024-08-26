FROM python:3.8-slim-bullseye

EXPOSE 8069 8072

# Enable Odoo user and filestore
RUN useradd -md /home/odoo -s /bin/false odoo \
    && mkdir -p /var/lib/odoo \
    && chown -R odoo:odoo /var/lib/odoo \
    && sync

# System environment variables
ENV GIT_AUTHOR_NAME=docker-odoo \
    GIT_COMMITTER_NAME=docker-odoo \
    EMAIL=docker-odoo@example.com \
    LC_ALL=C.UTF-8 \
    NODE_PATH=/usr/local/lib/node_modules:/usr/lib/node_modules \
    PATH="/home/odoo/.local/bin:$PATH" \
    PIP_NO_CACHE_DIR=0 \
    PYTHONOPTIMIZE=1

# Default values of env variables used by scripts
ENV ODOO_SERVER=odoo \
    UNACCENT=True \
    PROXY_MODE=True \
    WITHOUT_DEMO=True \
    WAIT_PG=true \
    PGUSER=odoo \
    PGPASSWORD=odoo \
    PGHOST=db \
    PGPORT=5432 \
    ADMIN_PASSWORD=admin

# Other requirements and recommendations to run Odoo
# See https://github.com/$ODOO_SOURCE/blob/$ODOO_VERSION/debian/control
ARG WKHTMLTOPDF_VERSION=0.12.5
ARG WKHTMLTOPDF_CHECKSUM='1140b0ab02aa6e17346af2f14ed0de807376de475ba90e1db3975f112fbd20bb'
RUN apt-get -qq update \
    && apt-get install -yqq --no-install-recommends \
        curl \
    && curl -SLo wkhtmltox.deb https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/${WKHTMLTOPDF_VERSION}/wkhtmltox_${WKHTMLTOPDF_VERSION}-1.stretch_amd64.deb \
    && echo "${WKHTMLTOPDF_CHECKSUM}  wkhtmltox.deb" | sha256sum -c - \
    && apt-get install -yqq --no-install-recommends \
        ./wkhtmltox.deb \
        chromium \
        ffmpeg \
        fonts-liberation2 \
        gettext-base \
        git \
        gnupg2 \
        locales-all \
        nano \
        npm \
        wget \
        openssh-client \
        telnet \
        vim \
        sudo \
    && echo 'deb http://apt.postgresql.org/pub/repos/apt/ bullseye-pgdg main' >> /etc/apt/sources.list.d/postgresql.list \
    && curl -SL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
    && apt-get update \
    && apt-get install -yqq --no-install-recommends postgresql-client-13 \
    && apt-get autopurge -yqq \
    && rm -Rf wkhtmltox.deb /var/lib/apt/lists/* /tmp/* \
    && sync

ARG ODOO_VERSION=15.0
ARG ODOO_SOURCE=odoo/odoo
ENV ODOO_VERSION="$ODOO_VERSION"
ENV ODOO_SOURCE="$ODOO_SOURCE"

# Install Odoo hard & soft dependencies, and Doodba utilities
RUN build_deps=" \
        build-essential \
        libfreetype6-dev \
        libfribidi-dev \
        libghc-zlib-dev \
        libharfbuzz-dev \
        libjpeg-dev \
        liblcms2-dev \
        libldap2-dev \
        libopenjp2-7-dev \
        libpq-dev \
        libsasl2-dev \
        libtiff5-dev \
        libwebp-dev \
        tcl-dev \
        tk-dev \
        zlib1g-dev \
    " \
    && apt-get update \
    && apt-get install -yqq --no-install-recommends $build_deps \
    && pip install --no-cache-dir \
        -r https://raw.githubusercontent.com/$ODOO_SOURCE/$ODOO_VERSION/requirements.txt \
        git-aggregator==2.1.0 \
        ipython==8.7.0 \
        pdfminer.six==20220319 \
        pysnooper==1.1.1 \
        ipdb==0.13.9 \
        # Gestión de paquetes pip desde odoo project (#42696)
        # git+https://github.com/OCA/openupgradelib.git \
        click-odoo-contrib==1.16.1 \
        pg-activity==3.0.1 \
        phonenumbers==8.13.1 \
    && (python3 -m compileall -q /usr/local/lib/python3.8/ || true) \
    && apt-get purge -yqq $build_deps \
    && apt-get autopurge -yqq \
    && rm -Rf /var/lib/apt/lists/* /tmp/*

# Metadata
ARG VCS_REF
ARG BUILD_DATE
ARG VERSION
LABEL org.label-schema.schema-version="$VERSION" \
      org.label-schema.vendor=Adhoc \
      org.label-schema.license=Apache-2.0 \
      org.label-schema.build-date="$BUILD_DATE" \
      org.label-schema.vcs-ref="$VCS_REF" \
      org.label-schema.vcs-url="https://github.com/ingadhoc/docker-odoo"

# Create directory structure
ENV SOURCES /home/odoo/src
ENV CUSTOM /home/odoo/custom
ENV RESOURCES /home/odoo/.resources
ENV CONFIG_DIR /home/odoo/.config
ENV DATA_DIR /home/odoo/data

ENV OPENERP_SERVER=$CONFIG_DIR/odoo.conf
ENV ODOO_RC=$OPENERP_SERVER

RUN mkdir -p $SOURCES/repositories && \
    mkdir -p $CUSTOM/repositories && \
    mkdir -p $DATA_DIR && \
    mkdir -p $CONFIG_DIR && \
    mkdir -p $RESOURCES/GeoIP && \
    chown -R odoo.odoo /home/odoo && \
    sync

# Usefull aliases
RUN echo "alias odoo-shell='odoo shell --shell-interface ipython --no-http --limit-memory-hard=0 --limit-memory-soft=0'" >> /home/odoo/.bashrc
RUN echo "alias odoo-fix='odoo fixdb --workers=0 --no-xmlrpc'" >> /home/odoo/.bashrc

# Image building scripts
COPY bin/* /usr/local/bin/
COPY build.d $RESOURCES/build.d
COPY conf.d $RESOURCES/conf.d
COPY entrypoint.d $RESOURCES/entrypoint.d
COPY entrypoint.sh $RESOURCES/entrypoint.sh
COPY resources/* $RESOURCES/
RUN    ln /usr/local/bin/direxec $RESOURCES/entrypoint \
    && ln /usr/local/bin/direxec $RESOURCES/build \
    && chown -R odoo.odoo $RESOURCES \
    && chmod -R a+rx $RESOURCES/entrypoint* $RESOURCES/build* /usr/local/bin \
    && sync

# Run build scripts
RUN $RESOURCES/build && sync

# Custom packages
RUN apt-get update \
    && apt-get install -y \
        build-essential \
        ca-certificates \
        libcups2-dev \
        libcurl4-openssl-dev \
        parallel \
        python3-dev \
        libevent-dev \
        libjpeg-dev \
        libldap2-dev \
        libsasl2-dev \
        libssl-dev \
        libxml2-dev \
        libxslt1-dev \
        swig \
        # install rsync for odoo upgrade scripts
        rsync \
        # para ayudar en debugging (no requerido)
        iputils-ping \
    # upgrade pip
    && pip install --upgrade pip \
    # pip dependencies that require build deps
    && pip install --no-cache-dir \
        # por problema con cryptography y pyOpenSSL replicamos lo que teniamos
        pyOpenSSL==19.0.0 \
        cryptography==35.0.0 \
        ## cloud platform, odoo y odoo saas
        redis==2.10.5 \
        google-api-python-client==2.66.0 \
        # Gestión de paquetes pip desde odoo project (#42696)
        # Odooly==2.1.9 \
        PyGithub==1.57 \
        git-aggregator==2.1.0 \
        # TODO revisar si sigue siendo necesario
        firebase-admin==6.0.1 \
        transifex-python==3.0.3 \
        dnspython3==1.15.0 \
        google-cloud-storage==2.6.0 \
        git+https://github.com/rancher/client-python.git@master \
        boto3==1.9.102 \
        # for pg_activity
        psycopg2-binary \
        ## ingadhoc/website
        html2text==2020.1.16 \
        ## ingadhoc/odoo-uruguay
        python-stdnum>=1.16 \
        ## ingadhoc/odoo-argentina
        # forzamos version httplib2==0.20.4 porque con lanzamiento de 0.21 (https://pypi.org/project/httplib2/#history) empezo a dar error de ticket 56946
        httplib2==0.20.4 \
        git+https://github.com/pysimplesoap/pysimplesoap@a330d9c4af1b007fe1436f979ff0b9f66613136e \
        git+https://github.com/ingadhoc/pyafipws@py3k \
        ## ingadhoc/aeroo
        # use this genshi version to fix error when, for eg, you send arguments like "date=True" check this  \https://genshi.edgewall.org/ticket/600
        genshi==0.7.7 \
        git+https://github.com/adhoc-dev/aeroolib@master-fix-ods \
        git+https://github.com/aeroo/currency2text.git \
        # mergebot requirements
        Markdown==3.4.1 \
        sentry-sdk==1.9.0 \
        # requirement de base_report_to_printer
        pycups==2.0.1 \
        # varios
        algoliasearch==2.6.2 \
        pycurl==7.45.1 \
        email-validator==1.3.0 \
        unrar==0.4 \
        mercadopago==2.2.0 \
        # Fix xlrd con lógica de odoo (sistemas-contabilidad)
        xlrd==1.2.0 \
        # external dependency for mail_autosubscribe (también necesaria para ejecutar casos de test)
        odoo_test_helper==2.0.2 \
        # geoip
        geoip2==4.6.0 \
        # l10n_cl_edi y probablemente otros (la version la tomamos de runbot data)
        pdf417gen==0.7.1 \
    # unrar para saas_provider_adhoc y unrar de agip
    cd && wget https://www.rarlab.com/rar/unrarsrc-5.6.8.tar.gz \
    && tar -xf unrarsrc-5.6.8.tar.gz \
    && cd unrar \
    && apt-get -y install make python-dev \
    && make lib \
    && make install-lib \
    && rm -rf unrarsrc-5.6.8.tar.gz \
    && rm -rf unrar \
    # purge
    && apt-get purge -yqq build-essential '*-dev' make || true \
    && apt-get -yqq autoremove \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# GEOIP (key generada con user devops@adhoc.com.ar, en Bitwarden > Infraestructura)
# Si falla la descarga (Build failed en dockerhub, generar un nuevo token en https://www.maxmind.com/ y reemplazar en variables de dockerhub)
ARG MAXMIND_LICENSE_KEY=default
ENV MAXMIND_LICENSE_KEY=$MAXMIND_LICENSE_KEY
RUN cd $RESOURCES/GeoIP \
    && curl -L -u 1011117:${MAXMIND_LICENSE_KEY} "https://download.maxmind.com/geoip/databases/GeoLite2-City/download?suffix=tar.gz" -o $RESOURCES/GeoIP/GeoLite2-City.tar.gz \
    && tar -xzf $RESOURCES/GeoIP/GeoLite2-City.tar.gz -C $RESOURCES/GeoIP \
    && find $RESOURCES/GeoIP/GeoLite2-City_* | grep "GeoLite2-City.mmdb" | xargs -I{} mv {} $RESOURCES/GeoIP \
    && rm $RESOURCES/GeoIP/GeoLite2-City.tar.gz

# UNRAR para padron agip
RUN echo "export UNRAR_LIB_PATH='/usr/lib/libunrar.so'" >> /home/odoo/.bashrc

USER odoo

# Entrypoint
WORKDIR "/home/odoo"
ENTRYPOINT ["/home/odoo/.resources/entrypoint.sh"]
CMD ["odoo"]
USER odoo

# HACK Special case for Werkzeug
RUN pip install --user Werkzeug==0.14.1
