#!/usr/bin/env bash
# Phase 23 — SonarQube project configuration files
# Run from: ~/courses/pokeshop

cd ~/courses/pokeshop

# ── Auth service ──────────────────────────────────────────────────────────
cat > services/auth-service/sonar-project.properties << 'EOF'
sonar.projectKey=pokeshop-auth-service
sonar.projectName=PokéShop Auth Service
sonar.projectVersion=1.0
sonar.sources=src
sonar.tests=src/tests
sonar.exclusions=node_modules/**,coverage/**
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.host.url=${SONAR_HOST_URL}
EOF

# ── Pokemon service ───────────────────────────────────────────────────────
cat > services/pokemon-service/sonar-project.properties << 'EOF'
sonar.projectKey=pokeshop-pokemon-service
sonar.projectName=PokéShop Pokemon Service
sonar.projectVersion=1.0
sonar.sources=src
sonar.tests=src/tests
sonar.exclusions=node_modules/**,coverage/**
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.host.url=${SONAR_HOST_URL}
EOF

# ── Favorites service ─────────────────────────────────────────────────────
cat > services/favorites-service/sonar-project.properties << 'EOF'
sonar.projectKey=pokeshop-favorites-service
sonar.projectName=PokéShop Favorites Service
sonar.projectVersion=1.0
sonar.sources=src
sonar.tests=src/tests
sonar.exclusions=node_modules/**,coverage/**
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.host.url=${SONAR_HOST_URL}
EOF

echo "Phase 23 complete ✓"
echo "Files created:"
find services -name "sonar-project.properties" | sort