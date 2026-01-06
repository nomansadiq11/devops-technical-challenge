# Java App Containerization

This directory contains a production-friendly, multi-stage Dockerfile for a Java REST API (Spring Boot compatible) that serves on port 8080 with a `/health` endpoint.

## Why these choices?
- Multi-stage build: Compiles with Maven + JDK, then ships only a slim JRE to reduce final image size.
- Base images: Eclipse Temurin 21 (LTS) variants — `maven:*-temurin-21` to build, `temurin:21-jre-alpine` to run.
- Security: Runs as a non-root `app` user.
- Healthcheck: Container-level `HEALTHCHECK` probes `http://localhost:8080/health` using `curl`.
- Minimal size: Alpine JRE + `.dockerignore` to shrink build context and final image.

## Expected project layout
A standard Maven Java project (e.g., Spring Boot):

```
app/hello-world/
  Dockerfile
  .dockerignore
../ (your Maven project root)
  pom.xml
  src/main/java/... (includes controller exposing GET /health -> {"status":"ok"})
```

The Dockerfile assumes a fat jar is produced under `target/`.

## Build and run

```bash
# From your Maven project root (where pom.xml lives)
# 1) Build the jar
mvn -q -DskipTests package

# 2) Build the Docker image (point Dockerfile context to project root)
docker build -f devops-technical-challenge/app/hello-world/Dockerfile -t hello-world:latest .

# 3) Run the container
docker run --rm -p 8080:8080 hello-world:latest

# 4) Verify health endpoint
curl -fsS http://localhost:8080/health
```

## Notes
- If your jar name is ambiguous (multiple jars in `target/`), adjust the `COPY` line or add a build arg.
- If your health endpoint differs, update the `HEALTHCHECK` URL accordingly.
- For even smaller images, consider distroless Java 21; you’ll need an alternate health check approach (no shell/curl).
