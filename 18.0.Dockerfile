FROM python:3.10-slim-bookworm

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
RUN apt-get -qq update \
    && apt-get install -yqq --no-install-recommends \
    # Dependencias WKHTMLTOPDF_VERSION
    curl \
    && curl -SLo libjpeg-turbo8.deb http://mirrors.kernel.org/ubuntu/pool/main/libj/libjpeg-turbo/libjpeg-turbo8_2.1.2-0ubuntu1_amd64.deb \
    && curl -SLo wkhtmltox.deb https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb \
    && apt-get install -yqq --no-install-recommends \
        ./libjpeg-turbo8.deb \
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
    && echo 'deb http://apt.postgresql.org/pub/repos/apt/ bookworm-pgdg main' > /etc/apt/sources.list.d/postgresql.list \
    && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg \
    && apt-get update \
    && apt-get install -yqq --no-install-recommends postgresql-client-15 \
    && apt-get autopurge -yqq \
    && rm -Rf wkhtmltox.deb /var/lib/apt/lists/* /tmp/* \
    && git config --global pull.rebase true \
    && git config --global init.defaultBranch main \
    && sync

ARG ODOO_VERSION=18.0
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
    && apt-get -qq update \
    && apt-get install -yqq --no-install-recommends $build_deps \
    && wget https://raw.githubusercontent.com/$ODOO_SOURCE/$ODOO_VERSION/requirements.txt \
    # Issue: https://github.com/odoo/odoo/issues/187021
    && sed -i "s/gevent==21\.8\.0 ; sys_platform != 'win32' and python_version == '3\.10'  # (Jammy)/gevent==21.12.0 ; sys_platform != 'win32' and python_version == '3.10'  # (Jammy)/" requirements.txt \
    && sed -i "s/geoip2==2\.9\.0/geoip2==4.6.0/" requirements.txt \
    # End Issue
    && pip install --no-cache-dir --prefer-binary \
        -r requirements.txt \
        git-aggregator==2.1.0 \
        ipython==8.7.0 \
        pdfminer.six==20220319 \
        pysnooper==1.1.1 \
        ipdb==0.13.9 \
        # Gestión de paquetes pip desde odoo project (#42696)
        # git+https://github.com/adhoc-cicd/oca-openupgradelib.git@master \
        click-odoo-contrib==1.16.1 \
        pg-activity==3.0.1 \
        phonenumbers==8.13.1 \
    && (python3 -m compileall -q /usr/local/lib/python3.10/ || true) \
    && rm requirements.txt \
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
ENV SOURCES=/home/odoo/src
ENV CUSTOM=/home/odoo/custom
ENV RESOURCES=/home/odoo/.resources
ENV CONFIG_DIR=/home/odoo/.config
ENV DATA_DIR=/home/odoo/data

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
RUN echo "alias odoo-restart='kill -HUP 1'" >> /home/odoo/.bashrc

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
    && pip install --no-cache-dir --prefer-binary \
        ## cloud platform, odoo y odoo saas
        nltk==3.8.1 \
        redis==5.2.1 \
        google-api-python-client==2.157.0 \
        # Gestión de paquetes pip desde odoo project (#42696)
        # Odooly==2.1.9 \
        PyGithub==1.57 \
        # TODO revisar si sigue siendo necesario
        firebase-admin==6.0.1 \
        transifex-python==3.0.3 \
        dnspython3==1.15.0 \
        google-cloud-storage==2.6.0 \
        # Used by adhoc provider (saas_k8s)
        google-cloud-compute==1.25.0 \
        git+https://github.com/rancher/client-python.git@master \
        boto3==1.26.7 \
        # for pg_activity
        psycopg2-binary \
        ## ingadhoc/website
        html2text==2020.1.16 \
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
        # date_range
        odoo-test-helper==2.0.2 \
        # varios
        algoliasearch==2.6.2 \
        pycurl==7.45.1 \
        email-validator==1.3.0 \
        unrar==0.4 \
        mercadopago==2.2.0 \
        # geoip
        # odoo utiliza geoip2==2.9.0 pero como nosotros ya venimos con la 4.6 preferimos mantener
        geoip2==4.6.0 \
        # l10n_cl_edi y probablemente otros (la version la tomamos de runbot data)
        pdf417gen==0.7.1 \
        # Gestión de paquetes pip desde odoo project (#42696)
        # git+https://github.com/adhoc-cicd/oca-odoo-module-migrator/@master \
        # 20230907 dib: requirement de shopify para sba (update version)
        ShopifyApi==12.7.0 \
        # requirements dashboard_ninja, ver dependencias tzdata, python-dateutil, numpy (#33029)
        pandas==2.1.2 \
        openpyxl==3.1.2 \
        # requirement para test tours
        websocket-client==1.8.0 \
        # required by saas_k8s
        kubernetes==31.0.0 \
        # Requerimiento IA: 4 - Integrar el modelo en Odoo (#45793)
        scikit-learn==1.5.2 \
        # Requerido por módulo oca - logging_json
        python-json-logger==3.2.1 \
        # MPV agentes de IA en odoo (#49259)
        openai==1.65.4 \
    # unrar para saas_provider_adhoc y unrar de agip
    && cd && wget https://www.rarlab.com/rar/unrarsrc-5.6.8.tar.gz \
    && tar -xf unrarsrc-5.6.8.tar.gz \
    && cd unrar \
    && make lib \
    && make install-lib \
    && rm -rf /root/unrarsrc-5.6.8.tar.gz \
    && rm -rf /root/unrar \
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
