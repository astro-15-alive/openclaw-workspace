#!/bin/bash
# VRAM usage test with large context

echo "=== VRAM Usage Comparison ==="
echo "Testing with 8K context window..."
echo ""

MODELS=("frob/qwen3.5-instruct:9b" "qwen3.5-instruct:9b-32k")

# Generate a ~2000 token prompt (will test with num_ctx=8192)
LARGE_PROMPT=$(python3 -c "print('Explain the following topic in detail: ' + ' '.join(['machine learning is a subset of artificial intelligence that enables computers to learn from data without explicit programming'] * 50))")

for model in "${MODELS[@]}"; do
    echo "----------------------------------------"
    echo "Model: $model"
    echo "Context: 8192 tokens"
    echo "----------------------------------------"
    
    # Check VRAM before
    VRAM_BEFORE=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null || echo "N/A")
    
    JSON_PAYLOAD=$(jq -n \
        --arg model "$model" \
        --arg prompt "$LARGE_PROMPT" \
        '{model: $model, prompt: $prompt, stream: false, options: {num_ctx: 8192, num_predict: 100}}')
    
    START_TIME=$(date +%s.%N)
    
    RESULT=$(curl -s http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d "$JSON_PAYLOAD")
    
    END_TIME=$(date +%s.%N)
    
    # Check VRAM after
    VRAM_AFTER=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null || echo "N/A")
    
    TOTAL_DURATION=$(echo "$RESULT" | jq -r '.total_duration // 0')
    PROMPT_EVAL_COUNT=$(echo "$RESULT" | jq -r '.prompt_eval_count // 0')
    EVAL_COUNT=$(echo "$RESULT" | jq -r '.eval_count // 0')
    EVAL_DURATION=$(echo "$RESULT" | jq -r '.eval_duration // 0')
    
    TOTAL_SEC=$(echo "scale=3; $TOTAL_DURATION / 1000000000" | bc 2>/dev/null)
    EVAL_SEC=$(echo "scale=3; $EVAL_DURATION / 1000000000" | bc 2>/dev/null)
    
    if [ "$EVAL_DURATION" -gt 0 ] 2>/dev/null; then
        TPS=$(echo "scale=2; $EVAL_COUNT / $EVAL_SEC" | bc 2>/dev/null)
    else
        TPS="N/A"
    fi
    
    echo "  Total time: ${TOTAL_SEC}s"
    echo "  Prompt tokens: $PROMPT_EVAL_COUNT"
    echo "  Output tokens: $EVAL_COUNT"
    echo "  Generation: $TPS tokens/sec"
    echo "  VRAM before: ${VRAM_BEFORE}MB"
    echo "  VRAM after: ${VRAM_AFTER}MB"
    echo ""
done

echo "=== Test Complete ==="
