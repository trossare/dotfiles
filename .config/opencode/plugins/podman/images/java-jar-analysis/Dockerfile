FROM docker.io/library/eclipse-temurin:25-jdk-noble

ARG VINEFLOWER_VERSION=1.12.0
ARG VINEFLOWER_SHA256=1dfcfe974395734fa467ce620661c7623d05ba83670de0529b1fbd63ff548b9d
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        binutils \
        ca-certificates \
        curl \
        file \
        git \
        jq \
        passwd \
        python3 \
        ripgrep \
        unzip \
        yara \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/tools \
    && curl -fL --retry 3 \
        "https://github.com/Vineflower/vineflower/releases/download/${VINEFLOWER_VERSION}/vineflower-${VINEFLOWER_VERSION}.jar" \
        -o /opt/tools/vineflower.jar \
    && echo "${VINEFLOWER_SHA256}  /opt/tools/vineflower.jar" | sha256sum --check --status \
    && printf '%s\n' \
        '#!/bin/sh' \
        'exec java -jar /opt/tools/vineflower.jar "$@"' \
        > /usr/local/bin/vineflower \
    && chmod 0755 /usr/local/bin/vineflower

# Fail the image build if the selected JDK tools are missing.
RUN java -version && javap -version && jdeps --version

RUN groupadd --gid 10001 analyst \
    && useradd --uid 10001 --gid 10001 --shell /bin/bash analyst

USER analyst
CMD ["bash"]
