# Dockerfile for building zeroperl - Perl compiled to WebAssembly
#
# Usage:
#   docker build -t zeroperl .
#   docker run --rm -v $(pwd)/output:/output zeroperl cp -r /artifacts/. /output/
#
# Quick iteration on zeroperl.c/stubs (uses cached wasi-perl stage):
#   docker build --target final -t zeroperl .

FROM debian:trixie-slim AS base

ARG TARGETPLATFORM
ARG WASI_SDK_VERSION=27
ARG BINARYEN_VERSION=124

ENV WASI_SDK_VERSION=${WASI_SDK_VERSION} \
    WASI_SDK_PATH=/opt/wasi-sdk

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl xz-utils zlib1g-dev libbz2-dev ca-certificates \
    clang llvm lld nodejs patch perl python3 \
    && rm -rf /var/lib/apt/lists/*

RUN ARCH=$(uname -m) && \
    case "${TARGETPLATFORM:-linux/$ARCH}" in \
        linux/arm64*|linux/aarch64*) WASI_ARCH="arm64"; BIN_ARCH="aarch64" ;; \
        *) WASI_ARCH="x86_64"; BIN_ARCH="x86_64" ;; \
    esac && \
    mkdir -p /opt/wasi-sdk /opt/binaryen && \
    curl -fsSL "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-${WASI_SDK_VERSION}/wasi-sdk-${WASI_SDK_VERSION}.0-${WASI_ARCH}-linux.tar.gz" \
        | tar -xzf - --strip-components=1 -C /opt/wasi-sdk && \
    curl -fsSL "https://github.com/WebAssembly/binaryen/releases/download/version_${BINARYEN_VERSION}/binaryen-version_${BINARYEN_VERSION}-${BIN_ARCH}-linux.tar.gz" \
        | tar -xzf - --strip-components=1 -C /opt/binaryen && \
    find /opt/wasi-sdk/share/wasi-sysroot/ -name "setjmp.h" -delete

ENV PATH="/opt/binaryen/bin:${PATH}"

COPY pipeline/build-wasi-libs.sh /build/repo/pipeline/
RUN chmod +x /build/repo/pipeline/build-wasi-libs.sh && /build/repo/pipeline/build-wasi-libs.sh

RUN mkdir -p /zeroperl && chmod 777 /zeroperl


FROM base AS native-perl

ARG PERL_VERSION=5.42.0

ENV PERL_VERSION=${PERL_VERSION} \
    NATIVE_DIR=/build/native \
    REPO_DIR=/build/repo

COPY pipeline/build-native-perl.sh /build/repo/pipeline/
RUN chmod +x /build/repo/pipeline/build-native-perl.sh

RUN /build/repo/pipeline/build-native-perl.sh

ARG BUILD_EXIFTOOL=true
ARG EXIFTOOL_SHA256=c8e3c42576f46d862e4cd9c192989776e7363931e890c95056bcd6293e83ea36
ARG EXIFTOOL_VERSION=13.60

ENV BUILD_EXIFTOOL=${BUILD_EXIFTOOL} \
    EXIFTOOL_SHA256=${EXIFTOOL_SHA256} \
    EXIFTOOL_VERSION=${EXIFTOOL_VERSION}

COPY pipeline/build-exiftool.sh /build/repo/pipeline/
RUN chmod +x /build/repo/pipeline/build-exiftool.sh && \
    if [ "${BUILD_EXIFTOOL}" = "true" ]; then \
        /build/repo/pipeline/build-exiftool.sh; \
    elif [ "${BUILD_EXIFTOOL}" != "false" ]; then \
        echo "BUILD_EXIFTOOL must be true or false" >&2; exit 1; \
    fi


FROM native-perl AS wasi-perl

ARG PERL_VERSION=5.42.0
ARG BUILD_EXIFTOOL=true
ARG TRIM=true

ENV PERL_VERSION=${PERL_VERSION} \
    BUILD_EXIFTOOL=${BUILD_EXIFTOOL} \
    TRIM=${TRIM} \
    WASM_DIR=/build/wasm

COPY wasi-bin/ /build/repo/wasi-bin/
COPY pipeline/ /build/repo/pipeline/
COPY patches/ /build/repo/patches/
COPY stubs/ /build/repo/stubs/
COPY tools/ /build/repo/tools/
RUN chmod +x /build/repo/wasi-bin/* /build/repo/pipeline/*.sh && mkdir -p /build/repo/gen

RUN mv /opt/binaryen/bin/wasm-opt /opt/binaryen/bin/wasm-opt-real && \
    cp /build/repo/tools/wasm-opt /opt/binaryen/bin/wasm-opt && \
    chmod +x /opt/binaryen/bin/wasm-opt && \
    /build/repo/pipeline/build-wasi-perl.sh && \
    mv /opt/binaryen/bin/wasm-opt-real /opt/binaryen/bin/wasm-opt

RUN /build/repo/pipeline/prepare-prefix.sh


FROM wasi-perl AS final

ARG STACK_SIZE=8388608
ARG INITIAL_MEMORY=33554432
ARG ASYNCIFY=true
ARG WASM_OPT_FLAGS=""

ENV STACK_SIZE=${STACK_SIZE} \
    INITIAL_MEMORY=${INITIAL_MEMORY} \
    ASYNCIFY=${ASYNCIFY} \
    WASM_OPT_FLAGS=${WASM_OPT_FLAGS}

COPY stubs/ /build/repo/stubs/

RUN /build/repo/pipeline/build-wasm.sh

RUN mkdir -p /artifacts && \
    test -s /build/wasm/config.h && \
    test -s /build/wasm/zeroperl.wasm && \
    test -s /build/wasm/zeroperl_reactor.wasm && \
    cp /build/wasm/config.h /build/wasm/zeroperl.wasm /build/wasm/zeroperl_reactor.wasm /artifacts/ && \
    cp -r /zeroperl /artifacts/perl-wasi-prefix

RUN if [ "${BUILD_EXIFTOOL}" = "true" ]; then \
        test -s /build/repo/exiftool.min.pl && \
        cp /build/repo/exiftool.min.pl /artifacts/; \
    fi


FROM debian:trixie-slim
COPY --from=final /artifacts /artifacts
CMD ["sh", "-c", "ls -la /artifacts"]
