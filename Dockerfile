# Use Node.js
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Install runtime tools used by the ECS container health check
RUN apk add --no-cache curl

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy full source code
COPY . .

# Build inside container
RUN npm run build

# Expose port
EXPOSE 3000

# Start app
CMD ["node", "dist/index.js"]
