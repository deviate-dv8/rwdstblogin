FROM scottyhardy/docker-wine:latest

# Install dependencies including OpenVPN
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglx-mesa0 \
    libgl1-mesa-dri \
    libglu1-mesa \
    mesa-utils \
    wine32 \
    wine64 \
    xvfb \
    wget \
    unzip \
    cron \
    curl \
    lua5.4 \
    imagemagick \
    scrot \
    x11-utils \
    xdotool \
    fluxbox \
    openvpn \
    iptables \
    dos2unix \
    kmod \
    net-tools \
    openresolv \
    procps \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy OpenVPN client functionality from dperson/openvpn-client
# Download the openvpn.sh script from dperson/openvpn-client repo
RUN curl -fsSL https://raw.githubusercontent.com/dperson/openvpn-client/master/openvpn.sh -o /usr/bin/openvpn.sh \
    && chmod +x /usr/bin/openvpn.sh

# Create OpenVPN directories
RUN mkdir -p /vpn \
    && mkdir -p /dev/net \
    && mknod /dev/net/tun c 10 200 \
    && chmod 600 /dev/net/tun

WORKDIR /app
COPY . /app

# Copy secrets from /etc/secrets to /app
RUN if [ -d /etc/secrets ]; then \
        cp -r /etc/secrets/* /app/; \
    fi

# Permissions
RUN mkdir -p /app/Light_Config && chmod 755 /app/Light_Config
RUN chmod +x /app/dailyScript.sh

# Node dependencies
RUN npm install

# Setup cron job (using UTC) - Create crontab file instead of using crontab command
RUN mkdir -p /var/spool/cron/crontabs && \
    echo "CRON_TZ=UTC" > /var/spool/cron/crontabs/root && \
    echo "0 0 * * * cd /app && ./dailyScript.sh >> /var/log/cron.log 2>&1" >> /var/spool/cron/crontabs/root && \
    chmod 600 /var/spool/cron/crontabs/root

# Log file
RUN touch /var/log/cron.log && chmod 666 /var/log/cron.log

# Screenshots directory
RUN mkdir -p /app/screenshots && chmod 755 /app/screenshots
RUN chmod -R 755 /app

# Create necessary directories for cron
RUN mkdir -p /var/run && chmod 755 /var/run

# OpenVPN environment variables (can be overridden at runtime)
ENV OPENVPN_CONFIG=""
ENV OPENVPN_OPTS=""
ENV LOCAL_NETWORK=""

EXPOSE 3000

# Enhanced start script that includes OpenVPN
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
