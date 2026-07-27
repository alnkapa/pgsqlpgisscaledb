# syntax = docker/dockerfile:1.4.0
FROM debian:trixie-slim AS builder
ARG DEBIAN_FRONTEND=noninteractive
ARG PG_VERSION=${PG_VERSION:-18.4}
ARG TSDB=${TSDB:-2.28.1}
ARG GIDB=${GIDB:-3.6.4}
ARG GEOS=${GEOS:-3.14.1}
ARG PROJ=${PROJ:-9.8.1}
ARG JSON=${JSON:-3.12.0}
ARG CURL_VERSION=${CURL_VERSION:-8.21.0}
ARG OPENSSL_VERSION=${OPENSSL_VERSION:-4.0.1}
ARG PROTO_BUF=${PROTO_BUF:-30.2}
ARG PROTO_C=${PROTO_C:-1.5.2}
ARG LIBXML2_VERSION=${LIBXML2_VERSION:-2.15.3}
ARG TIMESCALEDB_VERSION=2.28.2
ARG LIBTIFF_VERSION=4.7.2

# Пути
ENV PATH="/app/bin:${PATH}"
ENV MANPATH="/app/share/man:${MANPATH}"
ENV PKG_CONFIG_PATH="/app/lib/pkgconfig:/app/lib64/pkgconfig:${PKG_CONFIG_PATH}"
ENV LD_LIBRARY_PATH="/app/lib:/app/lib/x86_64-linux-gnu:/app/lib64:${LD_LIBRARY_PATH}"

RUN echo "/app/lib" > /etc/ld.so.conf.d/app.conf && \
    echo "/app/lib64" >> /etc/ld.so.conf.d/app.conf && \
    echo "/app/lib/x86_64-linux-gnu" >> /etc/ld.so.conf.d/app.conf && \
    ldconfig

# Базовые зависимости //		cmake \ 		libxml2-dev \
RUN  \
	set -ex; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		meson \
		wget \
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
		ninja-build \
		autoconf \
		automake \
		libtool \
	; \
	rm -rf /var/lib/apt/lists/*

# ==================== DOWNLOAD ALL SOURCES ====================
# Скачиваем все исходники в одном слое для лучшего кеширования
RUN   \    
    set -ex; \
    mkdir -p /tmp/sources && cd /tmp/sources && \
    wget -r --tries=10 https://download.gnome.org/sources/libxml2/${LIBXML2_VERSION%.*}/libxml2-${LIBXML2_VERSION}.tar.xz -O libxml2-${LIBXML2_VERSION}.tar.xz  && \
    wget -r --tries=10 https://github.com/Kitware/CMake/archive/refs/tags/v4.3.3.tar.gz -O CMake-4.3.3.tar.gz && \
    wget -r --tries=10 https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz -O openssl-${OPENSSL_VERSION}.tar.gz && \
    wget -r --tries=10 https://curl.se/download/curl-${CURL_VERSION}.tar.gz -O curl-${CURL_VERSION}.tar.gz && \
    wget -r --tries=10 https://github.com/nlohmann/json/archive/refs/tags/v${JSON}.tar.gz -O json-${JSON}.tar.gz && \
    wget -r --tries=10 https://a1.sqlite.org/2026/sqlite-autoconf-3530300.tar.gz -O sqlite-autoconf-3530300.tar.gz && \
    wget -r --tries=10 https://github.com/libgeos/geos/releases/download/${GEOS}/geos-${GEOS}.tar.bz2 -O geos-${GEOS}.tar.bz2 && \
    wget -r --tries=10 https://download.osgeo.org/proj/proj-${PROJ}.tar.gz -O proj-${PROJ}.tar.gz && \
    wget -r --tries=10 https://ftp.postgresql.org/pub/source/v${PG_VERSION}/postgresql-${PG_VERSION}.tar.gz -O postgresql-${PG_VERSION}.tar.gz && \
    wget -r --tries=10 https://github.com/OSGeo/gdal/archive/refs/tags/v3.13.1.tar.gz -O gdal-3.13.1.tar.gz && \
    wget -r --tries=10 https://github.com/abseil/abseil-cpp/archive/refs/tags/20260526.0.tar.gz -O abseil-cpp-20260526.0.tar.gz && \
    wget -r --tries=10 https://github.com/protocolbuffers/protobuf/archive/refs/tags/v${PROTO_BUF}.tar.gz -O protobuf-${PROTO_BUF}.tar.gz && \
    wget -r --tries=10 https://github.com/protobuf-c/protobuf-c/archive/refs/tags/v${PROTO_C}.tar.gz -O protobuf-c-${PROTO_C}.tar.gz && \
    wget -r --tries=10 https://download.osgeo.org/postgis/source/postgis-${GIDB}.tar.gz -O postgis-${GIDB}.tar.gz && \
    wget -r --tries=10 https://github.com/timescale/timescaledb/archive/refs/tags/${TIMESCALEDB_VERSION}.tar.gz -O timescaledb-${TIMESCALEDB_VERSION}.tar.gz && \
    wget -r --tries=10 https://download.osgeo.org/libtiff/tiff-${LIBTIFF_VERSION}.tar.gz -O tiff-${LIBTIFF_VERSION}.tar.gz && \
    wget -r --tries=10 https://www.kernel.org/pub/linux/utils/util-linux/v2.42/util-linux-2.42.tar.gz -O util-linux-2.42.tar.gz && \
    echo "All sources downloaded"

# ==================== LIBTIFF ====================
RUN   \
	cd /tmp/sources && \
    tar -xzf  tiff-${LIBTIFF_VERSION}.tar.gz && \
    cd  tiff-${LIBTIFF_VERSION} && \
    ./configure --prefix=/app \
                --disable-tests \
                --disable-docs \
                && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/sources/tiff-${LIBTIFF_VERSION}*

# ==================== OPENSSL ====================
RUN   \
	cd /tmp/sources && \
    tar -xzf openssl-${OPENSSL_VERSION}.tar.gz && \
    cd openssl-${OPENSSL_VERSION} && \
    ./Configure --prefix=/app \
                --release \
                --openssldir=/app \
                no-tests \
                '-Wl,--enable-new-dtags,-rpath,$(LIBRPATH)' && \
    make -j$(nproc) && \
    make install_sw && \
    cd / && rm -rf /tmp/sources/openssl-${OPENSSL_VERSION}*

# ==================== CURL ====================
RUN   \
	cd /tmp/sources && \
    tar -xzf curl-${CURL_VERSION}.tar.gz && \
    cd curl-${CURL_VERSION} && \
    ./configure --prefix=/app \
                --with-openssl=/app \
                --enable-static \
                --without-libpsl \
                --without-brotli \
                --without-zstd && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/sources/curl-${CURL_VERSION}*

# ==================== CMAKE ====================
RUN   \
	cd /tmp/sources && \
    tar -xzf CMake-4.3.3.tar.gz && \
    cd CMake-4.3.3 && \
    OPENSSL_ROOT_DIR="/app" ./bootstrap && make -j$(nproc) && make install && \
    cd / && rm -rf /tmp/sources/CMake-4.3.3*

# ==================== LIBXML2 ====================
RUN cd /tmp/sources && \    
    tar -xJf libxml2-${LIBXML2_VERSION}.tar.xz && \
    cd libxml2-${LIBXML2_VERSION} && \
    mkdir build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=/app \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_SHARED_LIBS=ON \
          -DLIBXML2_WITH_PYTHON=OFF \
          -DLIBXML2_WITH_LZMA=OFF \
          -DLIBXML2_WITH_ICU=OFF \
          .. && \
    make -j$(nproc) && \
    make install && \
    # Очистка после сборки (опционально, для экономии места)
    cd / && rm -rf /tmp/sources/libxml2-${LIBXML2_VERSION}*

# ==================== JSON ====================
RUN   \
	cd /tmp/sources && \
    tar -xzf json-${JSON}.tar.gz && \
    cd json-${JSON} && \
    mkdir -p build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=/app \
          -DJSON_BuildTests=OFF \
          -DCMAKE_BUILD_TYPE=Release .. && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/sources/json-${JSON}*

# ==================== SQLITE3 ====================
RUN   \
	cd /tmp/sources && \
    tar -xzf sqlite-autoconf-3530300.tar.gz && \
    cd sqlite-autoconf-3530300 && \
    ./configure --prefix=/app --enable-static --enable-rtree && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/sources/sqlite-autoconf-3530300*

# ==================== GEOS ====================
RUN   \
	cd /tmp/sources && \
    tar -xjf geos-${GEOS}.tar.bz2 && \
    cd geos-${GEOS} && \
    mkdir -p build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=/app \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_TESTING=OFF .. && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/sources/geos-${GEOS}*

# ==================== PROJ ====================
RUN   \
	cd /tmp/sources && \
    tar -xzf proj-${PROJ}.tar.gz && \
    cd proj-${PROJ} && \
    mkdir -p build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=/app \
          -DENABLE_TIFF=ON \
          -DENABLE_CURL=ON \
          -DBUILD_TESTING=OFF \
          -DBUILD_SHARED_LIBS=ON \
          -DCMAKE_BUILD_TYPE=Release .. && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/sources/proj-${PROJ}*

# ==================== UTIL-LINUX ====================
RUN   \
	cd /tmp/sources && \
    tar -xzf  util-linux-2.42.tar.gz && \
    cd  util-linux-2.42 && \
    ./configure --prefix=/app \
            --disable-all-programs \
            --disable-poman \
            --disable-asciidoc \
            --enable-libuuid \
            && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/sources/util-linux-2.42*

# ==================== POSTGRESQL ====================
RUN   \
	cd /tmp/sources && \
    tar -xzf postgresql-${PG_VERSION}.tar.gz && \
    cd postgresql-${PG_VERSION} && \
    meson setup build \
    --buildtype=release \
    --prefix=/app \
    -Dssl=openssl \
    -Dlibcurl=enabled \
    -Dlibxml=enabled \
    -Duuid=e2fs \
    -Dextra_include_dirs=/app/include \
    -Dextra_lib_dirs=/app/lib \
    && \
    cd build && ninja -j$(nproc) && ninja install && \
    cd / && rm -rf /tmp/sources/postgresql-${PG_VERSION}*

# ==================== GDAL ====================
RUN   \
	cd /tmp/sources && \
    tar -xzf gdal-3.13.1.tar.gz && \
    cd gdal-3.13.1 && \
    mkdir -p build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=/app \
          -DBUILD_TESTING=OFF \
          -DBUILD_SHARED_LIBS=ON \
          -DCMAKE_BUILD_TYPE=Release .. && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/sources/gdal-3.13.1*

# ==================== ABSEIL ====================
RUN   \
	cd /tmp/sources && \
    tar -xzf abseil-cpp-20260526.0.tar.gz && \
    cd abseil-cpp-20260526.0 && \
    mkdir -p build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=/app \
          -DABSL_BUILD_TESTING=OFF \
          -DCMAKE_BUILD_TYPE=Release .. && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/sources/abseil-cpp-20260526.0*

# ==================== PROTOBUF ====================
RUN   \
	cd /tmp/sources && \
    tar -xzf protobuf-${PROTO_BUF}.tar.gz && \
    cd protobuf-${PROTO_BUF} && \
    mkdir -p build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=/app \
          -Dprotobuf_BUILD_TESTS=OFF \
          -DCMAKE_BUILD_TYPE=Release .. && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/sources/protobuf-${PROTO_BUF}*

# ==================== PROTOBUF-C ====================
RUN   \
	cd /tmp/sources && \
    tar -xzf protobuf-c-${PROTO_C}.tar.gz && \
    cd protobuf-c-${PROTO_C} && \
    ./autogen.sh && \
    ./configure --prefix=/app && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/sources/protobuf-c-${PROTO_C}*

# ==================== POSTGIS ====================
RUN   \
	cd /tmp/sources && \
    tar -xzf postgis-${GIDB}.tar.gz && \
    cd postgis-${GIDB} && \
    ./configure --prefix=/app \
                --with-geosconfig=/app/bin/geos-config \
                --with-projdir=/app && \
    make -j$(nproc) && \
    make install && \
   cd / && rm -rf /tmp/sources/postgis-${GIDB}*

# ==================== TIMESCALEDB ====================
RUN \
    cd /tmp/sources && \
    tar -xzf timescaledb-${TIMESCALEDB_VERSION}.tar.gz && \
    cd timescaledb-${TIMESCALEDB_VERSION} && \
    CFLAGS="-I/app/include ${CFLAGS}" ./bootstrap -DCMAKE_BUILD_TYPE=Release \
                -DCMAKE_INSTALL_PREFIX=/app \
                -DREGRESS_CHECKS=OFF \
                -DTAP_CHECKS=OFF \
                -DWARNINGS_AS_ERRORS=OFF \
                -DSEND_TELEMETRY_DEFAULT=OFF && \
    cd build && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/sources/timescaledb-${TIMESCALEDB_VERSION}

# ==================== RUNTIME ====================
FROM debian:trixie-slim AS runtime

COPY --from=builder /app /app

RUN echo "/app/lib" > /etc/ld.so.conf.d/app.conf && \
    echo "/app/lib64" >> /etc/ld.so.conf.d/app.conf && \
    echo "/app/lib/x86_64-linux-gnu" >> /etc/ld.so.conf.d/app.conf && \
    ldconfig

RUN echo '#!/bin/bash' > /etc/profile.d/app-paths.sh && \
    echo 'export PATH="/app/bin:${PATH}"' >> /etc/profile.d/app-paths.sh && \
    echo 'export MANPATH="/app/share/man:${MANPATH}"' >> /etc/profile.d/app-paths.sh && \
    echo 'export PKG_CONFIG_PATH="/app/lib/pkgconfig:/app/lib64/pkgconfig:${PKG_CONFIG_PATH}"' >> /etc/profile.d/app-paths.sh && \
    chmod +x /etc/profile.d/app-paths.sh

ENV PATH="/app/bin:${PATH}"
ENV MANPATH="/app/share/man:${MANPATH}"
ENV PKG_CONFIG_PATH="/app/lib/pkgconfig:${PKG_CONFIG_PATH}"
ENV LD_LIBRARY_PATH="/app/lib:/app/lib/x86_64-linux-gnu:/app/lib64:${LD_LIBRARY_PATH}"

ENV PG_VERSION=${PG_VERSION:-18.4}
ENV PGDATA /var/lib/postgresql/${PG_VERSION}/data
ENV PG_PASSWORD=${PG_PASSWORD:-1Qwerty2}
ENV PG_MAX_CONNECTIONS="${PG_MAX_CONNECTIONS:-100}"
ENV PG_SHARED_BUFFERS="${PG_SHARED_BUFFERS:-}"
ENV PG_EFFECTIVE_CACHE_SIZE="${PG_EFFECTIVE_CACHE_SIZE:-}"
ENV PG_WORK_MEM="${PG_WORK_MEM:-}"
ENV PG_MAINTENANCE_WORK_MEM="${PG_MAINTENANCE_WORK_MEM:-}"

RUN set -eux; \
    groupadd -r postgres --gid=999; \
    useradd -r -g postgres --uid=999 --home-dir=/var/lib/postgresql --shell=/bin/bash postgres; \
    install --verbose --directory --owner postgres --group postgres --mode 1777 /var/lib/postgresql

COPY docker-entrypoint.sh docker-cmd.sh /app/bin/
RUN chmod +x /app/bin/docker-entrypoint.sh && \
    chmod +x /app/bin/docker-cmd.sh

WORKDIR /app

VOLUME /var/lib/postgresql
EXPOSE 5432
STOPSIGNAL SIGINT
ENTRYPOINT ["/app/bin/docker-entrypoint.sh"]

CMD ["/app/bin/docker-cmd.sh"]