FROM scottyhardy/docker-wine:latest

# Install Node.js and npm
RUN apt-get update && apt-get install -y curl \
    && curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs npm \
    && apt-get clean

# Verify installations
RUN wine --version && node --version

# Install required packages
RUN apt-get update && apt-get install -y \
    xvfb \
    wget \
    unzip \
    cron \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app

# Make the script executable (assuming your script is named dailyScript.sh)
RUN chmod +x /app/dailyScript.sh

# Add the cron job to the crontab
RUN echo "0 0 * * * TZ=UTC /app/dailyScript.sh >> /var/log/cron.log 2>&1" > /etc/cron.d/daily-job

# Apply correct permissions to the cron job file
RUN chmod 0644 /etc/cron.d/daily-job

# Register the cron job
RUN crontab /etc/cron.d/daily-job

# Create a log file for cron logs
RUN touch /var/log/cron.log

RUN npm install

# Listen port 3000
EXPOSE 3000

CMD ["sh", "-c", "npm run dev & cron && tail -f /var/log/cron.log"]

