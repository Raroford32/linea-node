#!/bin/bash

# Test script to validate the fixes without actually starting the full stack
# This tests the configuration changes without requiring Docker to be running

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

echo "=================================================================="
echo "           Configuration Fix Validation Tests"
echo "=================================================================="

# Test 1: Check JVM configuration doesn't have conflicting GC options
print_test "Checking JVM garbage collector configuration..."
if grep -q "\-XX:+UseZGC.*\-XX:+UseG1GC\|\-XX:+UseG1GC.*\-XX:+UseZGC" docker-compose-high-performance.yaml; then
    print_fail "JVM still has conflicting garbage collectors"
    exit 1
else
    print_pass "JVM configuration is clean (no conflicting GC options)"
fi

# Test 2: Check health checks are present
print_test "Checking health check configuration..."
health_checks=$(grep -c "healthcheck:" docker-compose-high-performance.yaml || echo "0")
if [ "$health_checks" -ge 2 ]; then
    print_pass "Health checks are configured for Besu services"
else
    print_fail "Missing health checks in configuration"
    exit 1
fi

# Test 3: Check service dependency conditions
print_test "Checking service dependency conditions..."
if grep -q "condition: service_healthy" docker-compose-high-performance.yaml; then
    print_pass "Service dependencies use health conditions"
else
    print_fail "Service dependencies don't use health conditions"
    exit 1
fi

# Test 4: Check domain configuration script exists and is executable
print_test "Checking domain configuration script..."
if [ -x "configure-domain.sh" ]; then
    print_pass "Domain configuration script is executable"
else
    print_fail "Domain configuration script missing or not executable"
    exit 1
fi

# Test 5: Check installation script has domain configuration
print_test "Checking installation script includes domain configuration..."
if grep -q "configure_domain" install-high-performance.sh; then
    print_pass "Installation script includes domain configuration"
else
    print_fail "Installation script missing domain configuration"
    exit 1
fi

# Test 6: Check .env.example exists
print_test "Checking environment configuration template..."
if [ -f ".env.example" ]; then
    print_pass "Environment template file exists"
else
    print_fail "Environment template file missing"
    exit 1
fi

# Test 7: Check nginx template exists
print_test "Checking nginx template configuration..."
if [ -f "nginx.conf.template" ]; then
    print_pass "Nginx template file exists"
else
    print_fail "Nginx template file missing"
    exit 1
fi

# Test 8: Validate Docker Compose syntax
print_test "Validating Docker Compose syntax..."
if docker-compose -f docker-compose-high-performance.yaml config > /dev/null 2>&1; then
    print_pass "Docker Compose configuration is valid"
else
    print_fail "Docker Compose configuration has syntax errors"
    exit 1
fi

echo ""
echo "=================================================================="
echo -e "${GREEN}           All Configuration Tests Passed!${NC}"
echo "=================================================================="
echo ""
echo "Key fixes verified:"
echo "✓ JVM garbage collector conflicts resolved"
echo "✓ Health checks implemented for service readiness"
echo "✓ Service dependencies use health conditions"
echo "✓ Domain configuration system implemented"
echo "✓ Environment template system added"
echo "✓ Docker Compose syntax is valid"
echo ""
echo "The configuration should now resolve the following issues:"
echo "• 'Multiple garbage collectors selected' errors"
echo "• 'Host not found in upstream' errors"
echo "• Missing domain address configuration"
echo "• Service startup timing issues"