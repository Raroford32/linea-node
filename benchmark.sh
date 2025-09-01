#!/bin/bash

# Performance testing script for Linea node
# Tests concurrent connections, response times, and throughput

set -e

# Configuration
NODE_URL="http://localhost"
WS_URL="ws://localhost:8080"
TEST_DURATION=60
CONCURRENT_CLIENTS=(10 50 100 200 500 1000)
OUTPUT_DIR="./benchmark_results"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    print_status "Checking dependencies..."
    
    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        print_error "curl is required but not installed"
        exit 1
    fi
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        print_warning "jq not found, installing..."
        sudo apt-get update -qq
        sudo apt-get install -y jq
    fi
    
    # Check if ab (Apache Bench) is available
    if ! command -v ab &> /dev/null; then
        print_warning "apache2-utils not found, installing..."
        sudo apt-get install -y apache2-utils
    fi
    
    # Check if node is running
    if ! curl -s "$NODE_URL/health" > /dev/null 2>&1; then
        print_error "Linea node is not responding at $NODE_URL"
        print_error "Make sure the node is running with: docker-compose up -d"
        exit 1
    fi
    
    print_status "All dependencies are available"
}

setup_output_directory() {
    mkdir -p "$OUTPUT_DIR"
    rm -f "$OUTPUT_DIR"/*
    echo "timestamp,concurrent_clients,requests_per_second,avg_response_time,errors,success_rate" > "$OUTPUT_DIR/benchmark_summary.csv"
}

test_basic_connectivity() {
    print_status "Testing basic connectivity..."
    
    # Test health endpoint
    HEALTH_RESPONSE=$(curl -s "$NODE_URL/health" || echo "ERROR")
    if [ "$HEALTH_RESPONSE" == "healthy" ]; then
        print_status "Health check: PASSED"
    else
        print_warning "Health check: FAILED or not available"
    fi
    
    # Test JSON-RPC endpoint
    RPC_RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        "$NODE_URL/" | jq -r '.result // "ERROR"')
    
    if [ "$RPC_RESPONSE" != "ERROR" ] && [ "$RPC_RESPONSE" != "null" ]; then
        print_status "JSON-RPC connectivity: PASSED (Block: $RPC_RESPONSE)"
    else
        print_error "JSON-RPC connectivity: FAILED"
        exit 1
    fi
}

run_load_test() {
    local clients=$1
    local test_name="load_test_${clients}_clients"
    
    print_status "Running load test with $clients concurrent clients..."
    
    # Create JSON-RPC request payload
    local rpc_payload='{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
    
    # Save payload to temporary file
    echo "$rpc_payload" > "/tmp/rpc_payload.json"
    
    # Run Apache Bench test
    local ab_output=$(ab -n $((clients * 10)) -c $clients -T "application/json" -p "/tmp/rpc_payload.json" "$NODE_URL/" 2>/dev/null)
    
    # Parse results
    local requests_per_sec=$(echo "$ab_output" | grep "Requests per second" | awk '{print $4}')
    local avg_time=$(echo "$ab_output" | grep "Time per request" | head -1 | awk '{print $4}')
    local failed_requests=$(echo "$ab_output" | grep "Failed requests" | awk '{print $3}')
    local total_requests=$(echo "$ab_output" | grep "Complete requests" | awk '{print $3}')
    
    # Calculate success rate
    local success_rate=0
    if [ "$total_requests" -gt 0 ]; then
        success_rate=$(echo "scale=2; (($total_requests - $failed_requests) / $total_requests) * 100" | bc -l)
    fi
    
    # Save results
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp,$clients,$requests_per_sec,$avg_time,$failed_requests,$success_rate" >> "$OUTPUT_DIR/benchmark_summary.csv"
    
    # Save detailed results
    echo "$ab_output" > "$OUTPUT_DIR/${test_name}_detailed.txt"
    
    print_status "Results: ${requests_per_sec} req/s, ${avg_time}ms avg, ${success_rate}% success rate"
    
    # Clean up
    rm -f "/tmp/rpc_payload.json"
}

run_sustained_load_test() {
    print_status "Running sustained load test for $TEST_DURATION seconds..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + TEST_DURATION))
    local request_count=0
    local error_count=0
    
    while [ $(date +%s) -lt $end_time ]; do
        local response=$(curl -s -w "%{http_code}" -X POST \
            -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
            "$NODE_URL/" 2>/dev/null)
        
        local http_code=$(echo "$response" | tail -c 4)
        
        if [ "$http_code" == "200" ]; then
            ((request_count++))
        else
            ((error_count++))
        fi
        
        # Small delay to prevent overwhelming
        sleep 0.1
    done
    
    local actual_duration=$(($(date +%s) - start_time))
    local rps=$(echo "scale=2; $request_count / $actual_duration" | bc -l)
    local error_rate=$(echo "scale=2; ($error_count / ($request_count + $error_count)) * 100" | bc -l)
    
    print_status "Sustained test results: ${rps} req/s over ${actual_duration}s, ${error_rate}% error rate"
    
    # Save sustained test results
    echo "Sustained Load Test Results" > "$OUTPUT_DIR/sustained_test.txt"
    echo "Duration: ${actual_duration} seconds" >> "$OUTPUT_DIR/sustained_test.txt"
    echo "Total Requests: $request_count" >> "$OUTPUT_DIR/sustained_test.txt"
    echo "Errors: $error_count" >> "$OUTPUT_DIR/sustained_test.txt"
    echo "Requests per Second: $rps" >> "$OUTPUT_DIR/sustained_test.txt"
    echo "Error Rate: ${error_rate}%" >> "$OUTPUT_DIR/sustained_test.txt"
}

test_cache_performance() {
    print_status "Testing cache performance..."
    
    # Make the same request multiple times to test caching
    local cache_test_requests=100
    local start_time=$(date +%s%N)
    
    for i in $(seq 1 $cache_test_requests); do
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
            "$NODE_URL/" > /dev/null
    done
    
    local end_time=$(date +%s%N)
    local total_time=$(echo "scale=3; ($end_time - $start_time) / 1000000000" | bc -l)
    local avg_time=$(echo "scale=3; $total_time / $cache_test_requests" | bc -l)
    local rps=$(echo "scale=2; $cache_test_requests / $total_time" | bc -l)
    
    print_status "Cache test: ${rps} req/s, ${avg_time}s avg response time"
    
    # Save cache test results
    echo "Cache Performance Test" > "$OUTPUT_DIR/cache_test.txt"
    echo "Total Requests: $cache_test_requests" >> "$OUTPUT_DIR/cache_test.txt"
    echo "Total Time: ${total_time}s" >> "$OUTPUT_DIR/cache_test.txt"
    echo "Average Response Time: ${avg_time}s" >> "$OUTPUT_DIR/cache_test.txt"
    echo "Requests per Second: $rps" >> "$OUTPUT_DIR/cache_test.txt"
}

generate_report() {
    print_status "Generating performance report..."
    
    local report_file="$OUTPUT_DIR/performance_report.html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Linea Node Performance Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background: #f0f0f0; padding: 20px; border-radius: 5px; }
        .metric { margin: 10px 0; padding: 10px; background: #f9f9f9; border-left: 4px solid #007cba; }
        .good { border-left-color: #28a745; }
        .warning { border-left-color: #ffc107; }
        .error { border-left-color: #dc3545; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Linea Node Performance Report</h1>
        <p>Generated on: $(date)</p>
        <p>Node URL: $NODE_URL</p>
    </div>
    
    <h2>Load Test Results</h2>
    <table>
        <tr>
            <th>Concurrent Clients</th>
            <th>Requests/Second</th>
            <th>Avg Response Time (ms)</th>
            <th>Errors</th>
            <th>Success Rate (%)</th>
        </tr>
EOF

    # Add load test results to HTML report
    tail -n +2 "$OUTPUT_DIR/benchmark_summary.csv" | while IFS=, read -r timestamp clients rps avg_time errors success_rate; do
        local class="good"
        if (( $(echo "$success_rate < 95" | bc -l) )); then
            class="warning"
        fi
        if (( $(echo "$success_rate < 90" | bc -l) )); then
            class="error"
        fi
        
        cat >> "$report_file" << EOF
        <tr class="$class">
            <td>$clients</td>
            <td>$rps</td>
            <td>$avg_time</td>
            <td>$errors</td>
            <td>$success_rate</td>
        </tr>
EOF
    done
    
    cat >> "$report_file" << EOF
    </table>
    
    <h2>Test Files</h2>
    <ul>
        <li><a href="benchmark_summary.csv">Benchmark Summary (CSV)</a></li>
        <li><a href="sustained_test.txt">Sustained Load Test Results</a></li>
        <li><a href="cache_test.txt">Cache Performance Test</a></li>
    </ul>
    
    <h2>Recommendations</h2>
    <div class="metric">
        <strong>Performance Baseline:</strong><br>
        • Target: >1000 req/s for high-performance setup<br>
        • Target: >95% success rate under load<br>
        • Target: <100ms average response time
    </div>
</body>
</html>
EOF
    
    print_status "Report generated: $report_file"
}

# Main execution
main() {
    echo "=================================================================="
    echo "           Linea Node Performance Benchmark Tool"
    echo "=================================================================="
    
    check_dependencies
    setup_output_directory
    test_basic_connectivity
    
    # Run load tests with different client counts
    for clients in "${CONCURRENT_CLIENTS[@]}"; do
        run_load_test "$clients"
        sleep 5  # Brief pause between tests
    done
    
    run_sustained_load_test
    test_cache_performance
    generate_report
    
    print_status "Benchmark complete! Results saved in $OUTPUT_DIR/"
    print_status "View the report: xdg-open $OUTPUT_DIR/performance_report.html"
}

# Check if bc is available for calculations
if ! command -v bc &> /dev/null; then
    print_warning "bc calculator not found, installing..."
    sudo apt-get update -qq
    sudo apt-get install -y bc
fi

main "$@"