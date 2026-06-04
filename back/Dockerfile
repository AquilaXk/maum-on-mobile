FROM eclipse-temurin:21-jre-jammy

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --system --gid 10001 maumon \
    && useradd --system --uid 10001 --gid maumon --home-dir /home/maumon --create-home --shell /usr/sbin/nologin maumon

COPY maum-on-mobile-back.jar /app/maum-on-mobile-back.jar

RUN chown -R maumon:maumon /app

USER maumon

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=5 \
    CMD curl -fsS http://127.0.0.1:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "/app/maum-on-mobile-back.jar"]
