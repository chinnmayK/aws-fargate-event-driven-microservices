FROM nginx:alpine

# Install curl for healthcheck purposes
RUN apk add --no-cache curl

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy your custom nginx.conf
COPY nginx.conf /etc/nginx/nginx.conf

# Healthcheck to verify Nginx is responding on port 80
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -f http://localhost/customer/whoami || exit 1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]