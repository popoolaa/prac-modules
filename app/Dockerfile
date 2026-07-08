# syntax=docker/dockerfile:1
FROM alpine/git:2.43.0 AS fetch
WORKDIR /src
RUN git clone --depth 1 https://github.com/saikiranpi/SecOps-game.git . \
    && rm -rf .git

FROM nginx:1.27-alpine
COPY --from=fetch /src/ /usr/share/nginx/html/
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost/ >/dev/null || exit 1
