# Stage 1: Build
FROM public.ecr.aws/docker/library/node:16-alpine AS builder

WORKDIR /app

# Copy manifest files
COPY package*.json ./

# Install dependencies including devDependencies for potential builds
RUN npm install

# Copy source code
COPY . .

# Stage 2: Runtime
FROM node:16-alpine

WORKDIR /app

# Copy only production dependencies and source
COPY --from=builder /app/package*.json ./
RUN npm install --only=production

COPY --from=builder /app/src ./src

# Set default Environment
ENV NODE_ENV=prod

# Change this line in your Dockerfiles
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:${PORT}/health || exit 1

EXPOSE ${PORT}

CMD ["npm", "start"]