#published at sammyaknan/minecraft-server-jbr21-hotswap

FROM ubuntu:22.04

ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
ARG EXTRA_DEB_PACKAGES=""
ARG FORCE_INSTALL_PACKAGES=1

RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    dos2unix \
    sudo \
    ${EXTRA_DEB_PACKAGES} && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ARG JBR_VERSION=21.0.6
ARG JBR_BUILD=b895.97
ENV JBR_URL=https://cache-redirector.jetbrains.com/intellij-jbr/jbr-${JBR_VERSION}-linux-x64-${JBR_BUILD}.tar.gz

RUN curl -fsSL ${JBR_URL} | tar -xz -C /opt && \
    ln -s /opt/jbr-${JBR_VERSION} /opt/jbr

ENV JAVA_HOME=/opt/jbr-${JBR_VERSION}-linux-x64-${JBR_BUILD}
ENV PATH="${JAVA_HOME}/bin:${PATH}"

ARG HOTSWAP_AGENT_VERSION=2.0.0
ENV HOTSWAP_AGENT_URL=https://github.com/HotswapProjects/HotswapAgent/releases/download/RELEASE-${HOTSWAP_AGENT_VERSION}/hotswap-agent-${HOTSWAP_AGENT_VERSION}.jar

RUN mkdir -p /opt/jbr-linux-x64/lib/hotswap && chmod 755 /opt/jbr-linux-x64/lib/hotswap

RUN curl -fsSL -o /opt/jbr-linux-x64/lib/hotswap/hotswap-agent.jar ${HOTSWAP_AGENT_URL}

COPY build/ /build/
RUN find /build -type f -exec dos2unix {} +

ARG TARGET="${TARGETARCH}${TARGETVARIANT}"
RUN /build/run.sh install-packages
RUN /build/run.sh setup-user

COPY --chmod=644 files/sudoers* /etc/sudoers.d

EXPOSE 25565

ARG APPS_REV=1
ARG GITHUB_BASEURL=https://github.com

ARG EASY_ADD_VERSION=0.8.8
ADD ${GITHUB_BASEURL}/itzg/easy-add/releases/download/${EASY_ADD_VERSION}/easy-add_${TARGETOS}_${TARGETARCH}${TARGETVARIANT} /usr/bin/easy-add
RUN chmod +x /usr/bin/easy-add

ARG RESTIFY_VERSION=1.7.5
RUN easy-add --var os=${TARGETOS} --var arch=${TARGETARCH}${TARGETVARIANT} \
  --var version=${RESTIFY_VERSION} --var app=restify --file {{.app}} \
  --from ${GITHUB_BASEURL}/itzg/{{.app}}/releases/download/{{.version}}/{{.app}}_{{.version}}_{{.os}}_{{.arch}}.tar.gz

ARG RCON_CLI_VERSION=1.6.9
RUN easy-add --var os=${TARGETOS} --var arch=${TARGETARCH}${TARGETVARIANT} \
  --var version=${RCON_CLI_VERSION} --var app=rcon-cli --file {{.app}} \
  --from ${GITHUB_BASEURL}/itzg/{{.app}}/releases/download/{{.version}}/{{.app}}_{{.version}}_{{.os}}_{{.arch}}.tar.gz

ARG MC_MONITOR_VERSION=0.14.1
RUN easy-add --var os=${TARGETOS} --var arch=${TARGETARCH}${TARGETVARIANT} \
  --var version=${MC_MONITOR_VERSION} --var app=mc-monitor --file {{.app}} \
  --from ${GITHUB_BASEURL}/itzg/{{.app}}/releases/download/{{.version}}/{{.app}}_{{.version}}_{{.os}}_{{.arch}}.tar.gz

ARG MC_SERVER_RUNNER_VERSION=1.12.3
RUN easy-add --var os=${TARGETOS} --var arch=${TARGETARCH}${TARGETVARIANT} \
  --var version=${MC_SERVER_RUNNER_VERSION} --var app=mc-server-runner --file {{.app}} \
  --from ${GITHUB_BASEURL}/itzg/{{.app}}/releases/download/{{.version}}/{{.app}}_{{.version}}_{{.os}}_{{.arch}}.tar.gz

ARG MC_HELPER_VERSION=1.40.2
ARG MC_HELPER_BASE_URL=${GITHUB_BASEURL}/itzg/mc-image-helper/releases/download/${MC_HELPER_VERSION}
# used for cache busting local copy of mc-image-helper
ARG MC_HELPER_REV=1
RUN curl -fsSL ${MC_HELPER_BASE_URL}/mc-image-helper-${MC_HELPER_VERSION}.tgz \
  | tar -C /usr/share -zxf - \
  && ln -s /usr/share/mc-image-helper-${MC_HELPER_VERSION}/bin/mc-image-helper /usr/bin

VOLUME ["/data"]
WORKDIR /data

STOPSIGNAL SIGTERM

ENV TYPE=VANILLA VERSION=LATEST EULA="" UID=1000 GID=1000

COPY --chmod=755 scripts/start* /
COPY --chmod=755 bin/ /usr/local/bin/
COPY --chmod=755 bin/mc-health /health.sh
COPY --chmod=644 files/* /image/
COPY --chmod=755 files/auto /auto

RUN curl -fsSL -o /image/Log4jPatcher.jar https://github.com/CreeperHost/Log4jPatcher/releases/download/v1.0.1/Log4jPatcher-1.0.1.jar

RUN dos2unix /start* /auto/*

ENV SKIP_CHOWN_DATA="true"

ENTRYPOINT [ "/start" ]
HEALTHCHECK --start-period=2m --retries=2 --interval=30s CMD mc-health