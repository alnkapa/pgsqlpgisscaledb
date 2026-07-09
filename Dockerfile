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

RUN set -ex; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		cmake \
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
	; \
	rm -rf /var/lib/apt/lists/*

		# libreadline-dev \
		# gettext \
		# zlib1g-dev \
		# libicu-dev \
		# liblz4-dev \
		# libzstd-dev \
		# libtiff-dev \
		# tcl-dev \
		# libxml2-dev \		
		# libproj-dev \
		# libgdal-dev \
		# libsfcgal-dev \
		# protobuf-c-compiler \
		# libprotobuf-c-dev \
		# libgdal-dev \
		# libjson-c-dev \
		# git2cl \
		# xsltproc \
		# docbook-xsl \
		# imagemagick \
		# dblatex \

WORKDIR /app
ARG PATH=/app/bin:$PATH
ARG MANPATH=/app/share/man:$MANPATH
ARG LD_LIBRARY_PATH

RUN echo "/app/lib" > /etc/ld.so.conf.d/app.conf && \
    echo "/app/lib64" >> /etc/ld.so.conf.d/app.conf && \
    ldconfig
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


# # Скачивание, сборка и установка OpenSSL no-shared \


RUN wget https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz && \
    tar -xzvf openssl-${OPENSSL_VERSION}.tar.gz && \
    cd openssl-${OPENSSL_VERSION} && \
    ./Configure --prefix=/app \
                --openssldir=/appl \
                no-tests \
                '-Wl,--enable-new-dtags,-rpath,$(LIBRPATH)' && \
    make -j $(nproc) && \
    make install_sw && \
    cd .. && \
    rm -rf openssl-${OPENSSL_VERSION} openssl-${OPENSSL_VERSION}.tar.gz	

ENV LD_LIBRARY_PATH=/app/lib64:/app/lib:${LD_LIBRARY_PATH}


# # Скачиваем и собираем CURL с помощью wget --disable-shared \
RUN wget https://curl.se/download/curl-${CURL_VERSION}.tar.gz && \
    tar -xzvf curl-${CURL_VERSION}.tar.gz && \
    cd curl-${CURL_VERSION} && \
    ./configure --prefix=/app \                
				--with-openssl=/app \
                --enable-static \
                --without-libpsl \
                --without-brotli \
                --without-zstd && \
    make -j8 && \
    make install && \
    cd .. && \
    rm -rf curl-${CURL_VERSION} curl-${CURL_VERSION}.tar.gz


RUN curl -L https://github.com/nlohmann/json/archive/refs/tags/v${JSON}.tar.gz | tar -xzv
RUN cd  json-${JSON}/ && mkdir build && cd build && cmake -DCMAKE_INSTALL_PREFIX=/app -DJSON_BuildTests=OFF -DCMAKE_BUILD_TYPE=Release .. && make -j8 && make install
RUN rm -rf  json-${JSON}


RUN curl -L https://a1.sqlite.org/2026/sqlite-autoconf-3530300.tar.gz | tar -xzv
RUN cd sqlite-autoconf-3530300 && \
    ./configure --prefix=/app --disable-shared --enable-static && \
    make -j8 && \
    make install
RUN rm -rf sqlite-autoconf-3530300

RUN curl -L https://github.com/libgeos/geos/releases/download/${GEOS}/geos-${GEOS}.tar.bz2 | tar -xjv
RUN cd geos-${GEOS}/ && mkdir build && cd build && cmake -DCMAKE_INSTALL_PREFIX=/app -DCMAKE_BUILD_TYPE=Release .. && make -j8 && make install
RUN rm -rf geos-${GEOS}

RUN set -ex; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libtiff-dev \		
	; \
	rm -rf /var/lib/apt/lists/*

RUN curl -L https://download.osgeo.org/proj/proj-${PROJ}.tar.gz | tar -xzv
RUN cd proj-${PROJ}/ && mkdir build && cd build && cmake -DCMAKE_INSTALL_PREFIX=/app -DENABLE_TIFF=OFF -DENABLE_CURL=ON -DBUILD_TESTING=OFF -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release .. && make -j8 && make install
RUN rm -rf proj-${PROJ}
# RUN projsync --system-directory --all






# # find / -name "geos"

# RUN curl -L https://download.osgeo.org/postgis/source/postgis-${GIDB}.tar.gz | tar -xzv
# RUN cd postgis-${GIDB}/ && ./configure --prefix=/app --enable-static  --with-geosconfig=/app/bin/geos-config --with-geosconfig=/app/bin/geos-config && make -j8 && make install
# RUN rm -rf postgis-${GIDB}



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

COPY docker-entrypoint.sh docker-cmd.sh /app/bin/
RUN  chmod +x /app/bin/docker-entrypoint.sh
RUN  chmod +x /app/bin/docker-cmd.sh
VOLUME /var/lib/postgresql
EXPOSE 5432
STOPSIGNAL SIGINT
# ENTRYPOINT ["/app/bin/docker-entrypoint.sh"]
# CMD ["/app/bin/docker-cmd.sh"]

CMD ["/bin/bash"]

# docker build -t my  .
# docker run -d --name my my


