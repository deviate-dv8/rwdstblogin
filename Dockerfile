FROM scottyhardy/docker-wine:latest

# Install dependencies
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
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

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

# Setup cron job (using UTC)
RUN echo "CRON_TZ=UTC\n0 0 * * * cd /app && ./dailyScript.sh >> /var/log/cron.log 2>&1" \
    | crontab -

# Log file
RUN touch /var/log/cron.log && chmod 666 /var/log/cron.log

# Screenshots directory
RUN mkdir -p /app/screenshots && chmod 755 /app/screenshots
RUN chmod -R 755 /app

EXPOSE 3000

# Start OpenVPN optionally, then cron and node
CMD if [ "$USE_VPN" = "1" ] && [ -f /app/config.ovpn ]; then \
        echo "Starting OpenVPN..."; \
        openvpn --config /app/config.ovpn & \
    fi && \
    cron -f & \
    npm run dev
