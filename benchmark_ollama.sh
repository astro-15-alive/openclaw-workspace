#!/bin/bash
# Benchmark script for comparing Ollama models

MODELS=("frob/qwen3.5-instruct:9b" "qwen3.5-instruct:9b-32k")
PROMPT="Explain the difference between synchronous and asynchronous programming in Python, including when to use each approach and provide code examples."

# Warm up the models first
echo "Warming up models..."
for model in "${MODELS[@]}"; do
    echo "  - $model"
    curl -s http://localhost:11434/api/generate \
        -d "{\"model\": \"$model\", \"prompt\": \"hi\", \"stream\": false, \"options\": {\"num_predict\": 10}}" > /dev/null
done

echo ""
echo "=== Ollama Model Benchmark ==="
echo "Prompt: $PROMPT"
echo ""

for model in "${MODELS[@]}"; do
    echo "----------------------------------------"
    echo "Model: $model"
    echo "----------------------------------------"
    
    # Run benchmark with timing
    START_TIME=$(date +%s.%N)
    
    RESULT=$(curl -s http://localhost:11434/api/generate \
        -d "{\"model\": \"$model\", \"prompt\": \"$PROMPT\", \"stream\": false, \"options\": {\"num_predict\": 300}}")
    
    END_TIME=$(date +%s.%N)
    
    # Extract metrics
    RESPONSE=$(echo "$RESULT" | jq -r '.response' 2>/dev/null)
    TOTAL_DURATION=$(echo "$RESULT" | jq -r '.total_duration' 2>/dev/null)
    LOAD_DURATION=$(echo "$RESULT" | jq -r '.load_duration' 2>/dev/null)
    PROMPT_EVAL_COUNT=$(echo "$RESULT" | jq -r '.prompt_eval_count' 2>/dev/null)
    PROMPT_EVAL_DURATION=$(echo "$RESULT" | jq -r '.prompt_eval_duration' 2>/dev/null)
    EVAL_COUNT=$(echo "$RESULT" | jq -r '.eval_count' 2>/dev/null)
    EVAL_DURATION=$(echo "$RESULT" | jq -r '.eval_duration' 2>/dev/null)
    
    # Convert nanoseconds to seconds/milliseconds
    TOTAL_SEC=$(echo "scale=3; $TOTAL_DURATION / 1000000000" | bc 2>/dev/null)
    LOAD_SEC=$(echo "scale=3; $LOAD_DURATION / 1000000000" | bc 2>/dev/null)
    PROMPT_EVAL_MS=$(echo "scale=2; $PROMPT_EVAL_DURATION / 1000000" | bc 2>/dev/null)
    EVAL_MS=$(echo "scale=2; $EVAL_DURATION / 1000000" | bc 2>/dev/null)
    
    # Calculate tokens per second
    if [ -n "$EVAL_DURATION" ] && [ "$EVAL_DURATION" -gt 0 ] 2>/dev/null; then
        TPS=$(echo "scale=2; $EVAL_COUNT / ($EVAL_DURATION / 1000000000)" | bc 2>/dev/null)
    else
        TPS="N/A"
    fi
    
    echo "  Total time: ${TOTAL_SEC}s"
    echo "  Load time: ${LOAD_SEC}s"
    echo "  Prompt tokens: $PROMPT_EVAL_COUNT (${PROMPT_EVAL_MS}ms)"
    echo "  Output tokens: $EVAL_COUNT (${EVAL_MS}ms)"
    echo "  Tokens/sec: $TPS"
    echo ""
done

echo "=== Benchmark Complete ==="
