# Multi-stage build for a Java REST API (Spring Boot compatible)
# Stage 1: Build (uses Maven + JDK)
FROM maven:3.9.6-eclipse-temurin-21 AS build
WORKDIR /workspace

# Leverage Docker layer caching for dependencies
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2 mvn -q -DskipTests dependency:go-offline

# Copy sources and build
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -q -DskipTests package

# Stage 2: Runtime (slim JRE + curl for HEALTHCHECK)
FROM eclipse-temurin:21-jre-alpine AS runtime
# Install curl for container-level health checks
RUN apk add --no-cache curl

# Create non-root user
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app

# Copy the fat jar produced by Spring Boot (assumes single jar in target)
COPY --from=build /workspace/target/*.jar /app/app.jar

# Expose the application port
EXPOSE 8080

# Healthcheck hitting the app's /health endpoint
HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
  CMD curl -fsS http://localhost:8080/health || exit 1

# Run as non-root
USER app

# Reasonable JVM defaults for containers
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:InitialRAMPercentage=25.0"
ENTRYPOINT ["sh", "-lc", "exec java $JAVA_OPTS -jar /app/app.jar"]
