# syntax=docker/dockerfile:1.7

FROM eclipse-temurin:25-jdk-noble AS build

ARG SERVICE_PATH

WORKDIR /workspace

COPY ${SERVICE_PATH}/pom.xml ./pom.xml
COPY ${SERVICE_PATH}/mvnw ./mvnw
COPY ${SERVICE_PATH}/.mvn ./.mvn

RUN --mount=type=cache,target=/root/.m2 \
    chmod +x ./mvnw \
    && ./mvnw -B -ntp dependency:go-offline

COPY ${SERVICE_PATH}/src ./src

RUN --mount=type=cache,target=/root/.m2 ./mvnw -B -ntp -DskipTests package \
    && artifact="$(find target -maxdepth 1 -type f -name '*.jar' | head -n 1)" \
    && test -n "$artifact" \
    && cp "$artifact" /tmp/app.jar

FROM eclipse-temurin:25-jre-noble AS runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system --gid 10001 navio \
    && useradd --system --uid 10001 --gid navio --home-dir /app --shell /usr/sbin/nologin navio

WORKDIR /app

COPY --from=build --chown=navio:navio /tmp/app.jar ./app.jar

USER navio

ENV JAVA_TOOL_OPTIONS="-XX:InitialRAMPercentage=20 -XX:MaxRAMPercentage=70 -XX:+ExitOnOutOfMemoryError"

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
