# Stage 1: OpenVPN client tools
FROM dperson/openvpn-client:latest as openvpn-client

# Stage 2: Main wine image
FROM scottyhardy/docker-wine:latest

# Install dependencies for your app + OpenVPN
RUN apt-get update && apt-get install -y \
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
    iptables \
    openvpn \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy OpenVPN scripts/configs from the first stage
COPY --from=openvpn-client /openvpn /usr/local/bin/openvpn-client
COPY --from=openvpn-client /etc/openvpn /etc/openvpn

WORKDIR /app
COPY . /app

# Copy secrets if available
RUN if [ -d /etc/secrets ]; then \
        cp -r /etc/secrets/* /app/; \
    fi

# Permissions
RUN mkdir -p /app/Light_Config && chmod 755 /app/Light_Config
RUN chmod +x /app/dailyScript.sh

# Node dependencies
RUN npm install

# Setup cron job (UTC)
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

EXPOSE 3000

# Start script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# CMD uses the script you provided
CMD ["/start.sh"]
