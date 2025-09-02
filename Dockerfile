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
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app

# Make the script executable
RUN chmod +x /app/dailyScript.sh

RUN npm install

EXPOSE 3000

# Use exec form and start cron properly
CMD ["sh", "-c", "/usr/sbin/cron && npm run dev & wait"]
