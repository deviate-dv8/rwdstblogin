FROM scottyhardy/docker-wine:latest

# Install dependencies (merged into one RUN to keep image smaller)
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
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app

RUN mkdir -p /app/Light_Config && chmod 755 /app/Light_Config
RUN chmod +x /app/dailyScript.sh
RUN npm install

# Setup cron job (using UTC)
RUN echo "CRON_TZ=UTC\n0 0 * * * cd /app && ./dailyScript.sh >> /var/log/cron.log 2>&1" \
    | crontab -

# Log file
RUN touch /var/log/cron.log && chmod 666 /var/log/cron.log

# Create screenshots directory
RUN mkdir -p /app/screenshots && chmod 755 /app/screenshots

EXPOSE 3000

# Start both cron and node in a single process manager
CMD cron -f & npm run dev
