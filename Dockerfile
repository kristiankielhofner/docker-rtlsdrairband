FROM debian:stable-slim

ENV BRANCH_RTLSDR="ed0317e6a58c098874ac58b769cf2e609c18d9a5" \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    ## Both services
    PORT="8000" \
    ## Icecast
    ICECAST_DISABLE="" \
    ICECAST_CUSTOMCONFIG="" \
    ICECAST_ADMIN_PASSWORD="rtlsdrairband" \
    ICECAST_ADMIN_USERNAME="admin" \
    ICECAST_ADMIN_EMAIL="test@test.com" \
    ICECAST_LOCATION="earth" \
    ICECAST_HOSTNAME="localhost" \
    ICECAST_MAX_CLIENTS="100" \
    ICECAST_MAX_SOURCES="4" \
    ## RTLSDR AirBand
    NFM_MAKE=0 \
    RTLSDRAIRBAND_CUSTOMCONFIG="" \
    RTLSDRAIRBAND_RADIO_TYPE="rtlsdr" \
    RTLSDRAIRBAND_GAIN=40 \
    RTLSDRAIRBAND_CORRECTION="" \
    RTLSDRAIRBAND_MODE="multichannel" \
    RTLSDRAIRBAND_FREQS="" \
    RTLSDRAIRBAND_SERIAL=""; \
    RTLSDRAIRBAND_MOUNTPOINT="GND.mp3" \
    RTLSDRAIRBAND_NAME="Tower" \
    RTLSDRAIRBAND_GENRE="ATC" \
    RTLSDRAIRBAND_DESCRIPTION="Air traffic feed" \
    RTLSDRAIRBAND_LABELS="" \
    RTLSDRAIRBAND_SHOWMETADATA="" \
    SQUELCH="" \
    LOG_SCAN_ACTIVITY="" \
    FFT_SIZE="2048" \
    SAMPLE_RATE="2.56"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY rootfs/ /

RUN set -x && \
    TEMP_PACKAGES=() && \
    KEPT_PACKAGES=() && \
    # Required for building multiple packages.
    TEMP_PACKAGES+=(build-essential) && \
    TEMP_PACKAGES+=(pkg-config) && \
    TEMP_PACKAGES+=(cmake) && \
    TEMP_PACKAGES+=(git) && \
    TEMP_PACKAGES+=(automake) && \
    TEMP_PACKAGES+=(autoconf) && \
    # logging
    KEPT_PACKAGES+=(gawk) && \
    # required for S6 overlay
    TEMP_PACKAGES+=(gnupg2) && \
    TEMP_PACKAGES+=(file) && \
    TEMP_PACKAGES+=(wget) && \
    TEMP_PACKAGES+=(ca-certificates) && \
    # libusb-1.0-0 + dev - Required for rtl-sdr, libiio (bladeRF/PlutoSDR).
    KEPT_PACKAGES+=(libusb-1.0-0) && \
    TEMP_PACKAGES+=(libusb-1.0-0-dev) && \
    # packages for icecast
    KEPT_PACKAGES+=(libxml2) && \
    TEMP_PACKAGES+=(libxml2-dev) && \
    KEPT_PACKAGES+=(libxslt1.1) && \
    TEMP_PACKAGES+=(libxslt1-dev) && \
    KEPT_PACKAGES+=(mime-support) && \
    # Required for healthchecks
    KEPT_PACKAGES+=(net-tools) && \
    # install first round of packages
    apt-get update && \
    apt-get install -y --no-install-recommends \
      ${KEPT_PACKAGES[@]} \
      ${TEMP_PACKAGES[@]} \
      && \
    # icecast install
    sh -c "echo deb-src http://download.opensuse.org/repositories/multimedia:/xiph/Debian_9.0/ ./ >>/etc/apt/sources.list.d/icecast.list" && \
    wget -qO - http://icecast.org/multimedia-obs.key | apt-key add - && \
    KEPT_PACKAGES+=(icecast2) && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ${KEPT_PACKAGES[@]} \
      ${TEMP_PACKAGES[@]} \
      && \
    mkdir -p /etc/icecast2/logs && \
    chown -R icecast2 /etc/icecast2 && \
    # Deploy rtl-sdr
    git clone git://git.osmocom.org/rtl-sdr.git /src/rtl-sdr && \
    pushd /src/rtl-sdr && \
    git checkout "${BRANCH_RTLSDR}" && \
    echo "rtl-sdr ${BRANCH_RTLSDR}" >> /VERSIONS && \
    mkdir -p /src/rtl-sdr/build && \
    pushd /src/rtl-sdr/build && \
    cmake ../ -DINSTALL_UDEV_RULES=ON -Wno-dev && \
    make -Wstringop-truncation && \
    make -Wstringop-truncation install && \
    cp -v /src/rtl-sdr/rtl-sdr.rules /etc/udev/rules.d/ && \
    popd && popd && \
    # Deploy RTLSDR-Airband
    bash -x /scripts/rtlsdr-airband-deploy.sh && \
    # install S6 Overlay
    wget -qO /tmp/deploy-s6-overlay.sh https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh && \
    bash -x /tmp/deploy-s6-overlay.sh && \
    # Deploy healthchecks framework
    git clone \
      --depth=1 \
      "https://github.com/mikenye/docker-healthchecks-framework.git" \
      /opt/healthchecks-framework \
      && \
    rm -rf \
      /opt/healthchecks-framework/.git* \
      /opt/healthchecks-framework/*.md \
      /opt/healthchecks-framework/tests \
      && \
    # Get rtl_airband source (compiled on first run via /etc/cont-init.d/01-build-rtl_airband)
    git clone git://github.com/szpajder/RTLSDR-Airband.git /opt/rtlsdr-airband && \
    pushd /opt/rtlsdr-airband && \
    BRANCH_RTL_AIRBAND=$(git tag | tail -1) && \
    git checkout "$BRANCH_RTL_AIRBAND" && \
    echo "$BRANCH_RTL_AIRBAND" > /CONTAINER_VERSION && \
    popd && \
    # Clean up
    apt-get remove -y ${TEMP_PACKAGES[@]} && \
    apt-get autoremove -y && \
    # Install packages required for first-run build of rtl_airband
    # This is done after clean-up to prevent accidental package removal
    unset KEPT_PACKAGES && \
    KEPT_PACKAGES=() && \
    KEPT_PACKAGES+=(g++) && \
    KEPT_PACKAGES+=(libconfig++-dev) && \
    KEPT_PACKAGES+=(libfftw3-dev) && \
    KEPT_PACKAGES+=(libmp3lame-dev) && \
    KEPT_PACKAGES+=(libogg-dev) && \
    KEPT_PACKAGES+=(libshout3-dev) && \
    KEPT_PACKAGES+=(libvorbis-dev) && \
    KEPT_PACKAGES+=(make) && \
    apt-get install -y --no-install-recommends \
      ${KEPT_PACKAGES[@]} \
      && \
    # Clean up
    rm -rf /src/* /tmp/* /var/lib/apt/lists/*

ENTRYPOINT [ "/init" ]

# Add healthcheck
HEALTHCHECK --start-period=300s --interval=300s CMD /scripts/healthcheck.sh
