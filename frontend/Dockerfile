# LYRR Frontend (Flutter Web) Dockerfile
#
# Multi-stage build for production

# Stage 1: Build Flutter web app
FROM ghcr.io/cirruslabs/flutter:3.16.0 as builder

WORKDIR /app

# Copy pubspec files
COPY pubspec.yaml pubspec.lock ./

# Get dependencies
RUN flutter pub get

# Copy source code
COPY lib/ ./lib/
COPY assets/ ./assets/

# Build for web
RUN flutter build web --release

# Stage 2: Serve with Nginx
FROM nginx:alpine as production

# Copy built app
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copy nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
