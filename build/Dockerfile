FROM ubuntu:17.04


RUN apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y gcc curl xz-utils libcurl4-gnutls-dev libevent-dev libssl-dev \
 && apt-get clean \
 && rm -rf /var/cache/apt /var/lib/apt/lists/*

RUN curl -fsS https://dlang.org/install.sh -o /tmp/install.sh \
 && bash /tmp/install.sh -p /opt/dlang install dmd \
 && find /opt/dlang -type d -exec chmod 755 {} \; \
 && rm /tmp/install.sh

RUN useradd -u 1000 -d /home/1000 -m 1000

ENV PATH="/opt/dlang/dub:/opt/dlang/dmd-2.077.0/linux/bin64:${PATH:-}" \
    LIBRARY_PATH="/opt/dlang/dmd-2.077.0/linux/lib64:${LIBRARY_PATH:-}" \
    LD_LIBRARY_PATH="/opt/dlang/dmd-2.077.0/linux/lib64:${LD_LIBRARY_PATH:-}" \
    DMD=dmd \
    DC=dmd