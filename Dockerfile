# syntax = docker/dockerfile:1.4.0
FROM debian:trixie-slim AS builder
ARG DEBIAN_FRONTEND=noninteractive
ARG PG_VERSION=${PG_VERSION:-18.4}
ARG TSDB=${TSDB:-2.28.1}
ARG GIDB=${GIDB:-3.6.4}
RUN set -ex; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		curl \
		cmake \
		meson \
		ca-certificates \
		build-essential \
		gawk \
		make \
		gcc \
		flex \
		bison \
		perl \
		tar \
		bzip2 \
		gzip \
		pkg-config \
		libreadline-dev \
		zlib1g-dev \
		libicu-dev \
		libssl-dev \
		liblz4-dev \
		libzstd-dev \
		gettext \
		ninja-build \
		libxml2-dev \
		libgeos-dev \
		libproj-dev \
		libgdal-dev \
		libsfcgal-dev \
		protobuf-c-compiler \
		libprotobuf-c-dev \
		libgdal-dev \
		libjson-c-dev \
		git2cl \
		xsltproc \
		docbook-xsl \
		imagemagick \
		dblatex \
	; \
	rm -rf /var/lib/apt/lists/*

WORKDIR /app

ARG LD_LIBRARY_PATH=/app/lib
ARG PATH=/app/bin:$PATH
ARG MANPATH=/app/share/man:$MANPATH

# \ -Dssl=enabled \
#   -Dnls=disabled \
#   -Dicu=disabled \
#   -Dzlib=enabled \
#   -Dlz4=enabled \
#   -Dzstd=enabled \
#   -Dgssapi=disabled \
#   -Dldap=disabled \
#   -Dlibcurl=disabled \
#   -Dreadline=enabled \
#   -Dplperl=disabled \
#   -Dplpython=disabled \
#   -Dpltcl=disabled
RUN curl -L https://ftp.postgresql.org/pub/source/v${PG_VERSION}/postgresql-${PG_VERSION}.tar.gz | tar -xzv
RUN cd postgresql-${PG_VERSION}/ && meson setup build --buildtype=release --prefix=/app --default-library=static --default-both-libraries=static --prefer-static --auto-features=disabled  && cd build && ninja && ninja install
RUN rm -rf postgresql-${PG_VERSION}

RUN curl -L https://github.com/timescale/timescaledb/archive/refs/tags/${TSDB}.tar.gz | tar -xzv
RUN cd timescaledb-${TSDB}/ && ./bootstrap -DCMAKE_BUILD_TYPE="Release" -DUSE_OPENSSL=0 -DSEND_TELEMETRY_DEFAULT=OFF -DUSE_TELEMETRY=OFF && cd build && make && make install -j
RUN rm -rf timescaledb-${TSDB}

RUN curl -L https://download.osgeo.org/postgis/source/postgis-${GIDB}.tar.gz | tar -xzv
RUN cd postgis-${GIDB}/ && ./configure --prefix=/app --enable-static --disable-shared  && make -j && make install
RUN rm -rf postgis-${GIDB}

# -------- runtime --------
FROM debian:trixie-slim AS runtime

ENV PATH=/app/bin:$PATH
ENV PG_VERSION=${PG_VERSION:-18.4}
ENV PGDATA /var/lib/postgresql/${PG_VERSION}/data
ENV PG_PASSWORD=${PG_PASSWORD:-1Qwerty2}
ENV PG_MAX_CONNECTIONS="${PG_MAX_CONNECTIONS:-100}"
ENV PG_SHARED_BUFFERS="${PG_SHARED_BUFFERS:-}"
ENV PG_EFFECTIVE_CACHE_SIZE="${PG_EFFECTIVE_CACHE_SIZE:-}"
ENV PG_WORK_MEM="${PG_WORK_MEM:-}"
ENV PG_MAINTENANCE_WORK_MEM="${PG_MAINTENANCE_WORK_MEM:-}"

COPY --from=builder /app /app

RUN echo "/app/lib/x86_64-linux-gnu" > /etc/ld.so.conf.d/app-lib.conf \
 && echo "/app/lib" > /etc/ld.so.conf.d/app-lib-root.conf \
 && ldconfig

RUN set -eux; groupadd -r postgres --gid=999; \
	useradd -r -g postgres --uid=999 --home-dir=/var/lib/postgresql --shell=/bin/bash postgres; \
	install --verbose --directory --owner postgres --group postgres --mode 1777 /var/lib/postgresql

COPY docker-entrypoint.sh /app/bin/
VOLUME /var/lib/postgresql
EXPOSE 5432
STOPSIGNAL SIGINT
ENTRYPOINT ["/app/bin/docker-entrypoint.sh"]
CMD []
