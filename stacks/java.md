---
stack: java
description: "Java backend stack — detection, build, test, migration, and deployment for Spring Boot/Quarkus projects."
---

# Java Stack Guide

## Detection Signals

### Primary indicators
- `pom.xml` exists (Maven)
- `build.gradle` or `build.gradle.kts` exists (Gradle)
- `gradlew` or `mvnw` wrapper scripts exist

### Framework detection
| Framework | Detection signal |
|-----------|-----------------|
| Spring Boot | `spring-boot-starter` in pom.xml or build.gradle |
| Quarkus | `quarkus-` dependency in pom.xml or build.gradle |
| Micronaut | `micronaut-` dependency in pom.xml or build.gradle |

### Detection commands
```bash
[ -f "pom.xml" ] || [ -f "build.gradle" ] || [ -f "build.gradle.kts" ] && echo "JAVA_DETECTED=yes" || echo "JAVA_DETECTED=no"
grep -l "spring-boot" pom.xml build.gradle build.gradle.kts 2>/dev/null && echo "FRAMEWORK=spring-boot"
grep -l "quarkus" pom.xml build.gradle build.gradle.kts 2>/dev/null && echo "FRAMEWORK=quarkus"
```

## Build Verification

### Build tool detection
```bash
if [ -f "mvnw" ]; then BUILD="./mvnw"
elif [ -f "pom.xml" ]; then BUILD="mvn"
elif [ -f "gradlew" ]; then BUILD="./gradlew"
elif [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then BUILD="gradle"
fi
echo "BUILD_TOOL=$BUILD"
```

### Testing
```bash
cd {backend_dir}
$BUILD test 2>&1
```

### Build (package)
```bash
cd {backend_dir}
$BUILD package -DskipTests 2>/dev/null || $BUILD build -x test 2>/dev/null
```

### Verify JAR/WAR
```bash
find {backend_dir}/target -name "*.jar" -o -name "*.war" 2>/dev/null | head -1
find {backend_dir}/build/libs -name "*.jar" 2>/dev/null | head -1
```

## Database Migration

### Migration tool detection
| Tool | Detection signal | Command |
|------|-----------------|---------|
| Flyway | `flyway-` in dependencies or `db/migration/` dir | `mvn flyway:migrate` |
| Liquibase | `liquibase-` in dependencies or `db/changelog/` dir | `mvn liquibase:update` |
| Spring Data JPA | `spring-boot-starter-data-jpa` + `spring.jpa.hibernate.ddl-auto` | Auto via Spring Boot |
| None | No migration tool found | Generate manual SQL |

## Dependency Management

```bash
cd {backend_dir}
$BUILD dependency:resolve 2>/dev/null || $BUILD dependencies 2>/dev/null
```

## Service Start

### Spring Boot
```bash
java -jar target/{service_name}.jar --spring.profiles.active=prod
```

### Quarkus
```bash
java -jar target/quarkus-app/quarkus-run.jar
```

### Using systemd
```bash
java -jar /opt/{service_name}/{service_name}.jar --spring.profiles.active=prod
```

## Common Issues

1. **JDK version mismatch**: Check `java -version` matches project's `sourceCompatibility`
2. **Build fails with dependency errors**: Run `$BUILD dependency:tree` to check conflicts
3. **Out of memory during build**: Set `MAVEN_OPTS="-Xmx1024m"` or `GRADLE_OPTS="-Xmx1024m"`
4. **Port already in use**: Spring default is 8080 — use `--server.port=8081` to override
5. **Profile not active**: Ensure `--spring.profiles.active=prod` is set for production