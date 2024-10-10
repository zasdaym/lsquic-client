FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND noninteractive

WORKDIR /app

RUN apt-get update && \
    apt-get install -y build-essential cmake git libevent-dev libunwind-dev ninja-build pkg-config zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --depth=1 https://boringssl.googlesource.com/boringssl.git && \
    cd boringssl && \
    cmake -GNinja -B build -DCMAKE_BUILD_TYPE=Release && \
    ninja -C build

RUN cd /app && \
    git clone --depth=1 --branch=v4.0.9 https://github.com/litespeedtech/lsquic.git && \
    cd lsquic && \
    git submodule update --init && \
    echo 'SET(LIBS "-lstdc++")' | cat - CMakeLists.txt > temp && mv temp CMakeLists.txt && \
    sed -i 's/PROJECT(lsquic C)/PROJECT(lsquic C CXX)/' CMakeLists.txt && \
    mkdir build && \
    cd build && \
    cmake -DBORINGSSL_DIR=/app/boringssl -DBORINGSSL_LIB_crypto=/app/boringssl/build/crypto/libcrypto.a -DBORINGSSL_LIB_ssl=/app/boringssl/build/ssl/libssl.a .. && \
    make -j $(nproc) http_client http_server

FROM ubuntu:24.04
COPY --from=builder /app/lsquic/build/bin/http_client /usr/local/bin/http_client
COPY --from=builder /app/lsquic/build/bin/http_server /usr/local/bin/http_server
ENTRYPOINT [ "/usr/local/bin/http_client" ]
