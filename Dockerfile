
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
    bzip2 ccache clang cmake cpio curl device-tree-compiler flex gawk gcc-multilib g++-multilib gettext \
    genisoimage git gperf haveged help2man intltool libc6-dev-i386 libelf-dev libfuse-dev libglib2.0-dev \
    libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses5-dev libncursesw5-dev libpython3-dev \
    libreadline-dev libssl-dev libtool llvm lrzsz libnsl-dev ninja-build p7zip p7zip-full patch pkgconf \
    python3 python3-pyelftools python3-setuptools qemu-utils rsync scons squashfs-tools subversion \
    swig texinfo uglifyjs upx-ucl unzip vim wget xmlto xxd xz-utils zlib1g-dev jq ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Mike Farah yq
RUN wget -qO /usr/local/bin/yq \
    https://github.com/mikefarah/yq/releases/download/v4.47.2/yq_linux_amd64 && \
    chmod +x /usr/local/bin/yq

# Create build user and workspace
RUN useradd -m -s /bin/bash builder && \
    mkdir -p /home/builder/AutoBuild-OpenWrt && \
    chown -R builder:builder /home/builder

# Configure workspace
WORKDIR /home/builder/AutoBuild-OpenWrt

# Copy build scripts and configuration
COPY --chown=builder:builder . .

# Switch to non-root user
USER builder

# Keep container running
CMD ["sleep", "infinity"]
