FROM scottyhardy/docker-wine:latest

# Install Node.js and npm
RUN apt-get update && apt-get install -y curl \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install required packages
RUN apt-get update && apt-get install -y \
    xvfb \
    wget \
    unzip \
    cron \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app

# Make the script executable
RUN chmod +x /app/dailyScript.sh

# Create necessary directories
RUN mkdir -p /var/run
RUN touch /var/log/cron.log

# Add the cron job
RUN echo "0 0 * * * TZ=UTC /app/dailyScript.sh >> /var/log/cron.log 2>&1" > /etc/cron.d/daily-job
RUN chmod 0644 /etc/cron.d/daily-job
RUN crontab /etc/cron.d/daily-job

RUN npm install

EXPOSE 3000

# Use exec form and start cron properly
CMD ["sh", "-c", "/usr/sbin/cron && npm run dev & wait"]
