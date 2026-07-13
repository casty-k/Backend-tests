#!/bin/bash

# User Management Service — L1 API Tests
# Newman test runner script
# Usage: ./run-tests.sh [all|happy|errors|idempotency]

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
COLLECTION="${SCRIPT_DIR}/OS2-User-Mgnt-L1-API-Tests.postman_collection.json"
ENVIRONMENT="${SCRIPT_DIR}/env.dev.json"
RESULTS_DIR="${SCRIPT_DIR}/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create results directory
mkdir -p "${RESULTS_DIR}"

# Check if Newman is installed
if ! command -v newman &> /dev/null; then
    echo "❌ Newman not found. Install with: npm install -g newman"
    exit 1
fi

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}User Management Service — L1 API Tests${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Test execution functions
run_all_tests() {
    print_header
    echo "Running ALL tests..."
    echo ""

    newman run "${COLLECTION}" \
        --environment "${ENVIRONMENT}" \
        --reporters cli,json,html \
        --reporter-json-export "${RESULTS_DIR}/l1-api-all-${TIMESTAMP}.json" \
        --reporter-html-export "${RESULTS_DIR}/l1-api-all-${TIMESTAMP}.html"

    check_results "${RESULTS_DIR}/l1-api-all-${TIMESTAMP}.json"
}

run_happy_path() {
    print_header
    echo "Running HAPPY PATH tests only..."
    echo ""

    newman run "${COLLECTION}" \
        --environment "${ENVIRONMENT}" \
        --folder "L1.1 — Happy Path (14 Endpoints)" \
        --reporters cli,json,html \
        --reporter-json-export "${RESULTS_DIR}/l1-api-happy-${TIMESTAMP}.json" \
        --reporter-html-export "${RESULTS_DIR}/l1-api-happy-${TIMESTAMP}.html"

    check_results "${RESULTS_DIR}/l1-api-happy-${TIMESTAMP}.json"
}

run_error_cases() {
    print_header
    echo "Running ERROR CASES tests only..."
    echo ""

    newman run "${COLLECTION}" \
        --environment "${ENVIRONMENT}" \
        --folder "L1.2 — Error Cases (Boundary Tests)" \
        --reporters cli,json,html \
        --reporter-json-export "${RESULTS_DIR}/l1-api-errors-${TIMESTAMP}.json" \
        --reporter-html-export "${RESULTS_DIR}/l1-api-errors-${TIMESTAMP}.html"

    check_results "${RESULTS_DIR}/l1-api-errors-${TIMESTAMP}.json"
}

run_idempotency() {
    print_header
    echo "Running IDEMPOTENCY tests only..."
    echo ""

    newman run "${COLLECTION}" \
        --environment "${ENVIRONMENT}" \
        --folder "L1.3 — Idempotency Tests" \
        --reporters cli,json,html \
        --reporter-json-export "${RESULTS_DIR}/l1-api-idmp-${TIMESTAMP}.json" \
        --reporter-html-export "${RESULTS_DIR}/l1-api-idmp-${TIMESTAMP}.html"

    check_results "${RESULTS_DIR}/l1-api-idmp-${TIMESTAMP}.json"
}

check_results() {
    local result_file=$1

    if [ -f "${result_file}" ]; then
        # Extract stats
        PASSED=$(grep -o '"passed": [0-9]*' "${result_file}" | head -1 | grep -o '[0-9]*')
        FAILED=$(grep -o '"failed": [0-9]*' "${result_file}" | head -1 | grep -o '[0-9]*')
        TOTAL=$(grep -o '"total": [0-9]*' "${result_file}" | head -1 | grep -o '[0-9]*')

        echo ""
        echo "════════════════════════════════════════════════════"
        echo "Test Results Summary"
        echo "════════════════════════════════════════════════════"
        echo "Total Tests: $TOTAL"
        echo "Passed: $PASSED ✅"
        echo "Failed: $FAILED ❌"
        echo "Pass Rate: $((PASSED * 100 / TOTAL))%"
        echo ""
        echo "Report saved to: ${result_file}"
        echo "HTML Report:     ${result_file%.json}.html"
        echo "════════════════════════════════════════════════════"
        echo ""

        if [ "$FAILED" -gt 0 ]; then
            print_error "Tests failed! See report for details."
            exit 1
        else
            print_success "All tests passed!"
            exit 0
        fi
    else
        print_error "Results file not found: ${result_file}"
        exit 1
    fi
}

# Main logic
case "${1:-all}" in
    all)
        run_all_tests
        ;;
    happy)
        run_happy_path
        ;;
    errors)
        run_error_cases
        ;;
    idempotency)
        run_idempotency
        ;;
    *)
        print_header
        echo "Usage: ./run-tests.sh [all|happy|errors|idempotency]"
        echo ""
        echo "Options:"
        echo "  all          Run ALL test suites (default)"
        echo "  happy        Run HAPPY PATH tests only"
        echo "  errors       Run ERROR CASES tests only"
        echo "  idempotency  Run IDEMPOTENCY tests only"
        echo ""
        echo "Examples:"
        echo "  ./run-tests.sh                # Run all tests"
        echo "  ./run-tests.sh happy          # Run happy path only"
        echo "  ./run-tests.sh errors         # Run error cases only"
        echo ""
        exit 0
        ;;
esac
