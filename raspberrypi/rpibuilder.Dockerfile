FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

# Install deps for debos
RUN apt-get update && apt-get install -y \
    debos \
    qemu-user-static \
    bmap-tools \
    ca-certificates \
    wget \
    sudo \
    xz-utils \
    kmod \
    parted \
    dosfstools \
    udev \
    libguestfs-tools \
    && apt-get clean

# Create workspace
WORKDIR /workspace

CMD ["bash"]
