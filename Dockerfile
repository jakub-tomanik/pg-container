# Apache Age
# https://github.com/apache/age

FROM postgres:16 AS age

ARG age_release=1.5.0-rc0

ADD "https://github.com/apache/age/archive/refs/tags/PG16/v${age_release}.tar.gz" \
  /tmp/age.tar.gz

RUN set -eux; \
  tar -xvf /tmp/age.tar.gz -C /tmp; \
  rm -rf /tmp/age.tar.gz;

RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends --no-install-suggests \
  build-essential \
  postgresql-server-dev-16 \
  libreadline-dev \
  zlib1g-dev \
  bison \
  flex \
  ;

WORKDIR /tmp/age-PG16-v${age_release}
RUN make -j$(nproc) install

FROM postgres:16-bookworm

# Fix: initdb: error: invalid locale settings; check LANG and LC_* environment variables
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && locale-gen en_US.UTF-8

ENV DEBIAN_FRONTEND=noninteractive

RUN curl -s https://packagecloud.io/install/repositories/timescale/timescaledb/script.deb.sh | bash

RUN apt-get -q update && \
        apt-get -y upgrade && \
        apt-get install -y --no-install-recommends --no-install-suggests \
        gnupg apt-transport-https lsb-release curl \
## Timescaledb https://packagecloud.io/timescale/timescaledb
        timescaledb-2-postgresql-16 timescaledb-tools \
## Postgis https://trac.osgeo.org/postgis/wiki/UsersWikiPostGIS24UbuntuPGSQL10Apt
        postgresql-16-postgis-3 \
        postgresql-16-postgis-3-scripts \
        postgresql-16-pgrouting \
        postgresql-16-pgrouting-scripts \
## pg_cron https://github.com/citusdata/pg_cron
        postgresql-16-cron \
## Extension plpython3
        python3 postgresql-plpython3-16 python3-requests \
## Pgvector https://github.com/pgvector/pgvector
        postgresql-16-pgvector \
## MobilityDB https://github.com/MobilityDB/MobilityDB
        postgresql-16-mobilitydb && \
## Clean up
        apt-get -y autoremove --purge && \
        apt-get -y clean && \
        rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt

## Apache AGE
COPY --from=age /usr/lib/postgresql/16/lib/age.so /usr/lib/postgresql/16/lib/age.so
COPY --from=age /usr/lib/postgresql/16/lib/bitcode /usr/lib/postgresql/16/lib/bitcode
COPY --from=age /usr/share/postgresql/16/extension/age--1.5.0.sql /usr/share/postgresql/16/extension/age--1.5.0.sql
COPY --from=age /usr/share/postgresql/16/extension/age.control /usr/share/postgresql/16/extension/age.control

## Config
RUN echo "trusted = true" >> /usr/share/postgresql/16/extension/postgis.control
# extension timescaledb and others must be preloaded
RUN echo "shared_preload_libraries = 'age,timescaledb,pg_stat_statements,pg_cron'" >> /usr/share/postgresql/postgresql.conf.sample
# timescaledb telemetry off
RUN echo "timescaledb.telemetry_level=off" >> /usr/share/postgresql/postgresql.conf.sample