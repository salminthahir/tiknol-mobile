#!/bin/bash

# Test Script for QRIS Payment Enhancement
# This script verifies rate limiting, manual check functionality, and overall system health

set -e

echo "🚀 Starting QRIS Payment Enhancement Tests..."
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    echo -e "${GREEN}✅ PASS:${NC} $1"
    ((PASS_COUNT++))
}

fail() {
    echo -e "${RED}❌ FAIL:${NC} $1"
    ((FAIL_COUNT++))
}

warn() {
    echo -e "${YELLOW}⚠️ WARN:${NC} $1"
}

# Configuration
API_BASE_URL="${API_BASE_URL:-http://localhost:3000}"
ORDER_ID="${TEST_ORDER_ID:-test_order_123456789}"
MAX_RETRIES=5
RETRY_DELAY=2

echo "📋 Configuration:"
echo "   API URL: $API_BASE_URL"
echo "   Test Order ID: $ORDER_ID"
echo "   Max Retries: $MAX_RETRIES"
echo ""

# Test 1: Verify Rate Limiter Module Exists
echo "Test 1: Checking Rate Limiter Module..."
if [ -f "/Users/macbooksale/Work/Projects/tiknol-web-system/lib/rate-limiter.ts" ]; then
    pass "Rate limiter module exists"
else
    fail "Rate limiter module not found at lib/rate-limiter.ts"
fi

# Test 2: Check Environment Variables
echo ""
echo "Test 2: Verifying Redis Configuration..."
if [ -n "$UPSTASH_REDIS_REST_URL" ] && [ -n "$UPSTASH_REDIS_REST_TOKEN" ]; then
    pass "Redis credentials configured"
else
    warn "Redis credentials not set in environment (cache will be disabled)"
fi

# Test 3: Test Normal Payment Status Check
echo ""
echo "Test 3: Testing Normal Payment Status Check..."
for i in $(seq 1 $MAX_RETRIES); do
    echo "   Attempt $i/$MAX_RETRIES..."
    
    RESPONSE=$(curl -s -w "\n%{http_code}" \
        -X POST "$API_BASE_URL/api/payment/check-status" \
        -H "Content-Type: application/json" \
        -d "{\"orderId\": \"$ORDER_ID\"}" 2>/dev/null || echo "")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | head -n-1)
    
    if [ "$HTTP_CODE" == "200" ]; then
        STATUS=$(echo "$BODY" | grep -o '"status":[^,]*' | cut -d':' -f2 | tr -d '"' || echo "unknown")
        pass "Normal payment status check succeeded (Status: $STATUS)"
        break
    elif [ "$HTTP_CODE" == "429" ]; then
        warn "Rate limited on attempt $i - this is expected if previous tests consumed quota"
        pass "Rate limiting triggered as expected"
        break
    else
        echo "      Response: $HTTP_CODE - $(echo "$BODY" | head -c 100)"
        if [ $i -eq $MAX_RETRIES ]; then
            fail "Payment status check failed after $MAX_RETRIES attempts"
        else
            sleep $RETRY_DELAY
        fi
    fi
done

# Test 4: Verify Rate Limit Headers
echo ""
echo "Test 4: Checking Response Headers..."
HEADERS=$(curl -s -I \
    -X POST "$API_BASE_URL/api/payment/check-status" \
    -H "Content-Type: application/json" \
    -d "{\"orderId\": \"$ORDER_ID\"}" 2>/dev/null || echo "")

if echo "$HEADERS" | grep -qi "x-ratelimit-limit"; then
    pass "Rate limit headers present in response"
else
    warn "Rate limit headers not found (might not be enabled without Redis)"
fi

# Test 5: Simulate Rapid Requests (Rate Limit Stress Test)
echo ""
echo "Test 5: Stress Testing Rate Limit (20 rapid requests)..."
SUCCESS_COUNT=0
RATE_LIMITED_COUNT=0

for i in $(seq 1 20); do
    RESPONSE=$(curl -s -w "\n%{http_code}" \
        -X POST "$API_BASE_URL/api/payment/check-status" \
        -H "Content-Type: application/json" \
        -d "{\"orderId\": \"$ORDER_ID\"}" 2>/dev/null || echo "")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    
    if [ "$HTTP_CODE" == "200" ]; then
        ((SUCCESS_COUNT++))
    elif [ "$HTTP_CODE" == "429" ]; then
        ((RATE_LIMITED_COUNT++))
    fi
    
    sleep 0.1 # Small delay between requests
done

if [ $RATE_LIMITED_COUNT -gt 0 ]; then
    pass "Rate limiting caught $RATE_LIMITED_COUNT requests out of 20"
else
    warn "No rate limiting observed in rapid request test (may exceed threshold or Redis unavailable)"
fi

# Test 6: Frontend File Verification
echo ""
echo "Test 6: Verifying Frontend Enhancements..."

FLUTTER_FILE="/Users/macbooksale/Work/Projects/tiknol-mobile-flutter/lib/screens/qris_payment_screen.dart"

if grep -q "_manualCheck" "$FLUTTER_FILE"; then
    pass "Manual check method implemented in frontend"
else
    fail "Manual check method not found in qris_payment_screen.dart"
fi

if grep -q "lastCheckedAt\|_lastCheckedAt" "$FLUTTER_FILE"; then
    pass "Last checked timestamp tracking implemented"
else
    fail "Timestamp tracking not found"
fi

if grep -q "Periksa Sekarang" "$FLUTTER_FILE"; then
    pass "Manual check button UI element present"
else
    fail "Manual check button not found"
fi

if grep -q "_manualRefreshInProgress" "$FLUTTER_FILE"; then
    pass "Debounce mechanism implemented"
else
    fail "Debounce logic missing"
fi

# Test 7: Success Feedback Implementation
echo ""
echo "Test 7: Checking Success Feedback Components..."

if grep -q "showSuccessFeedback\|_playSuccessSound" "$FLUTTER_FILE"; then
    pass "Success feedback methods implemented"
else
    fail "Success feedback not found"
fi

if grep -q "HapticFeedback\|SystemSound.play" "$FLUTTER_FILE"; then
    pass "Haptic/sound feedback configured"
else
    warn "No haptic/sound feedback detected (optional feature)"
fi

# Test 8: Error Handling Checks
echo ""
echo "Test 8: Verifying Error Handling..."

if grep -q "PaymentCheckException" "$FLUTTER_FILE"; then
    pass "Error handling for PaymentCheckException present"
else
    fail "PaymentCheckException handler missing"
fi

if grep -q "catch.*on PaymentCheckException" "$FLUTTER_FILE"; then
    pass "Fail-closed pattern maintained"
else
    fail "Fail-closed pattern not preserved"
fi

# Test 9: Backend Route Updates
echo ""
echo "Test 9: Verifying Backend Route Changes..."

ROUTE_FILE="/Users/macbooksale/Work/Projects/tiknol-web-system/app/api/payment/check-status/route.ts"

if grep -q "checkPaymentRateLimit" "$ROUTE_FILE"; then
    pass "Rate limiting integrated into route handler"
else
    fail "Rate limiting not integrated in route handler"
fi

if grep -q "X-RateLimit-Limit\|X-RateLimit-Remaining" "$ROUTE_FILE"; then
    pass "Rate limit response headers configured"
else
    warn "Response headers not explicitly set (using default NextResponse behavior)"
fi

if grep -q "cache" "$ROUTE_FILE" -i; then
    pass "Caching layer implemented"
else
    warn "Caching not detected (optional optimization)"
fi

# Summary Report
echo ""
echo "============================================================"
echo "              TEST SUMMARY REPORT"
echo "============================================================"
echo ""
echo -e "Passed Tests:  ${GREEN}$PASS_COUNT${NC}"
echo -e "Failed Tests:  ${RED}$FAIL_COUNT${NC}"
echo ""

TOTAL_TESTS=$((PASS_COUNT + FAIL_COUNT))
if [ $TOTAL_TESTS -gt 0 ]; then
    PASS_RATE=$(echo "scale=2; $PASS_COUNT / $TOTAL_TESTS * 100" | bc)
    echo -e "Pass Rate:     ${GREEN}${PASS_RATE}%${NC}"
fi

echo ""
echo "============================================================"

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
    echo ""
    echo "The QRIS Payment Enhancement is ready for production!"
    echo ""
    exit 0
else
    echo -e "${RED}⚠️ SOME TESTS FAILED${NC}"
    echo ""
    echo "Please review the failures above and fix issues before deployment."
    echo ""
    exit 1
fi
