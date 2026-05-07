#!/usr/bin/env bash
# ============================================================
# Health Check Script - All Services
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

HOST=${1:-localhost}
PASS=0
FAIL=0

echo -e "${CYAN}"
echo "ษออออออออออออออออออออออออออออออออออออออออออออออป"
echo "บ   Fusionpact Health Check Dashboard          บ"
echo "ศออออออออออออออออออออออออออออออออออออออออออออออผ"
echo -e "${NC}"

check_endpoint() {
    local name=$1
    local url=$2
    local expected=${3:-200}
    
    HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" \
        --max-time 10 --connect-timeout 5 "$url" || echo "000")
    
    if [ "$HTTP_CODE" = "$expected" ] || [[ "$HTTP_CODE" =~ ^2 ]]; then
        echo -e "  ${GREEN}? $name${NC} (HTTP $HTTP_CODE)"
        ((PASS++)) || true
    else
        echo -e "  ${RED}? $name${NC} (HTTP $HTTP_CODE) - Expected $expected"
        ((FAIL++)) || true
    fi
}

echo "?? Service Endpoints:"
check_endpoint "Frontend (HTTP)"       "http://${HOST}:80"
check_endpoint "Frontend Health"       "http://${HOST}:80/health"
check_endpoint "Backend API"           "http://${HOST}:8000"
check_endpoint "Backend Health"        "http://${HOST}:8000/health"
check_endpoint "Backend Metrics"       "http://${HOST}:8000/metrics"
check_endpoint "Prometheus"            "http://${HOST}:9090/-/healthy"
check_endpoint "Prometheus API"        "http://${HOST}:9090/api/v1/status/runtimeinfo"
check_endpoint "Grafana"              "http://${HOST}:3000/api/health"
check_endpoint "AlertManager"         "http://${HOST}:9093/-/healthy"
check_endpoint "Node Exporter"        "http://${HOST}:9100/metrics"
check_endpoint "cAdvisor"             "http://${HOST}:8080/metrics"

echo ""
echo "?? Docker Container Status:"
docker-compose ps 2>/dev/null || docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "????????????????????????????????????????????"
TOTAL=$((PASS + FAIL))
echo -e "  Results: ${GREEN}$PASS passed${NC} | ${RED}$FAIL failed${NC} | $TOTAL total"

if [ $FAIL -eq 0 ]; then
    echo -e "  ${GREEN}?? All services are HEALTHY!${NC}"
    exit 0
else
    echo -e "  ${RED}??  Some services need attention!${NC}"
    exit 1
fi
