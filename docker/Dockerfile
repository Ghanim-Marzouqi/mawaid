# Stage 1: Build Flutter web app
FROM ghcr.io/cirruslabs/flutter:stable AS build

ARG SUPABASE_URL
ARG SUPABASE_ANON_KEY
ARG VAPID_PUBLIC_KEY

WORKDIR /app
COPY pubspec.yaml ./
RUN flutter pub get

COPY . .
RUN flutter build web --release \
    --dart-define=SUPABASE_URL=${SUPABASE_URL} \
    --dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY} \
    --dart-define=VAPID_PUBLIC_KEY=${VAPID_PUBLIC_KEY}

# Stage 2: Serve with Nginx
FROM nginx:alpine
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
