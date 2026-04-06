#!/bin/bash
# benchmark.sh - Compare Kimi vs Gemma performance

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test tasks
FAST_TASK="List the first 5 files in /tmp"
MEDIUM_TASK="Write a Python function to calculate fibonacci numbers with memoization"
COMPLEX_TASK="Analyze this Python code for performance issues and suggest optimizations: def slow_function(n): result = 0; for i in range(n): for j in range(n): result += i * j; return result"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    OpenClaw Model Benchmark${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Testing models:"
echo "  - gemma-fast (8k context, local)"
echo "  - kimi (256k context, API)"
echo ""

# Function to run benchmark
run_benchmark() {
    local model=$1
    local task=$2
    local task_name=$3
    
    echo -e "${YELLOW}Testing: $task_name${NC}"
    echo "Model: $model"
    echo "Task: $task"
    echo ""
    
    # Time the execution
    start_time=$(date +%s.%N)
    
    # Run the task and capture output
    if [ "$model" == "gemma-fast" ]; then
        output=$(openclaw sessions spawn --task "$task" --model gemma-fast --timeout 60 2>&1) || true
    else
        output=$(openclaw run --model moonshot/kimi-k2.5 "$task" 2>&1) || true
    fi
    
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc)
    
    echo "Duration: ${duration}s"
    echo "Output preview: $(echo "$output" | head -3)"
    echo ""
}

# Function to check if LM Studio is running
check_lmstudio() {
    echo -e "${YELLOW}Checking if LM Studio is running...${NC}"
    if curl -s http://127.0.0.1:1234/v1/models > /dev/null 2>&1; then
        echo -e "${GREEN}✓ LM Studio is running${NC}"
        return 0
    else
        echo -e "${RED}✗ LM Studio is not running${NC}"
        echo "Please start LM Studio and load the Gemma model"
        return 1
    fi
}

# Function to check API key
check_api_key() {
    echo -e "${YELLOW}Checking Moonshot API key...${NC}"
    if [ -n "$MOONSHOT_API_KEY" ] || grep -q "MOONSHOT_API_KEY" ~/.openclaw/.env 2>/dev/null; then
        echo -e "${GREEN}✓ API key configured${NC}"
        return 0
    else
        echo -e "${RED}✗ API key not found${NC}"
        return 1
    fi
}

# Main benchmark
echo -e "${BLUE}Pre-flight checks...${NC}"
echo ""

# Check prerequisites
lmstudio_ok=false
api_ok=false

check_lmstudio && lmstudio_ok=true
check_api_key && api_ok=true

echo ""
echo -e "${BLUE}========================================${NC}"
echo ""

# Run benchmarks
if [ "$lmstudio_ok" = true ]; then
    echo -e "${GREEN}=== GEMMA-FAST BENCHMARKS ===${NC}"
    echo ""
    
    echo -e "${YELLOW}Test 1: Simple Task${NC}"
    run_benchmark "gemma-fast" "$FAST_TASK" "List files"
    
    echo -e "${YELLOW}Test 2: Medium Task${NC}"
    run_benchmark "gemma-fast" "$MEDIUM_TASK" "Write Fibonacci function"
    
    echo -e "${YELLOW}Test 3: Complex Task${NC}"
    run_benchmark "gemma-fast" "$COMPLEX_TASK" "Code analysis"
    
    echo ""
fi

if [ "$api_ok" = true ]; then
    echo -e "${GREEN}=== KIMI BENCHMARKS ===${NC}"
    echo ""
    
    echo -e "${YELLOW}Test 1: Simple Task${NC}"
    run_benchmark "kimi" "$FAST_TASK" "List files"
    
    echo -e "${YELLOW}Test 2: Medium Task${NC}"
    run_benchmark "kimi" "$MEDIUM_TASK" "Write Fibonacci function"
    
    echo -e "${YELLOW}Test 3: Complex Task${NC}"
    run_benchmark "kimi" "$COMPLEX_TASK" "Code analysis"
    
    echo ""
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}         Benchmark Complete${NC}"
echo -e "${BLUE}========================================${NC}"
