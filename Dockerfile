FROM scottyhardy/docker-wine:latest

# Install Node.js and npm
RUN apt-get update && apt-get install -y curl \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install required packages including cron
RUN apt-get update && apt-get install -y \
    xvfb \
    wget \
    unzip \
    cron \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app

# Create Light_Config directory and ensure proper permissions
RUN mkdir -p /app/Light_Config \
    && chmod 755 /app/Light_Config

# Make the script executable
RUN chmod +x /app/dailyScript.sh

RUN npm install

# Create necessary directories and set permissions for cron
RUN mkdir -p /var/run \
    && chmod 755 /var/run \
    && touch /var/run/crond.pid \
    && chmod 644 /var/run/crond.pid

# Create cron job that runs dailyScript.sh every day at midnight GMT (00:00)
RUN echo "0 0 * * * cd /app && ./dailyScript.sh >> /var/log/cron.log 2>&1" | crontab -

# Create log file for cron and set permissions
RUN touch /var/log/cron.log \
    && chmod 666 /var/log/cron.log

# Ensure cron has proper permissions
RUN chmod u+s /usr/sbin/cron

EXPOSE 3000

# Use exec form and start cron properly
CMD ["sh", "-c", "service cron start && npm run dev & tail -f /var/log/cron.log & wait"]
