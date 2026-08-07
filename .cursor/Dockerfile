FROM ubuntu:24.04

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      git \
      curl \
      ca-certificates \
      unzip \
      xz-utils \
      zip \
      clang \
      cmake \
      ninja-build \
      pkg-config \
      libgtk-3-dev \
      liblzma-dev \
      libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/flutter/flutter.git -b 3.27.1 --depth 1 /opt/flutter \
    && chown -R ubuntu:ubuntu /opt/flutter

ENV PATH="/opt/flutter/bin:${PATH}"

USER ubuntu
RUN flutter config --no-analytics \
    && flutter precache --web
