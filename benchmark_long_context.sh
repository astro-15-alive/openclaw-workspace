#!/bin/bash
# Long context benchmark - fixed version

MODELS=("frob/qwen3.5-instruct:9b" "qwen3.5-instruct:9b-32k")

# Simple long prompt to test context processing
LONG_PROMPT="Analyze this Python code for performance and best practices. The code implements an async data fetcher with retry logic, semaphore-based concurrency limiting, and exponential backoff. It uses aiohttp for HTTP requests and includes proper context manager support. Key features include: concurrent fetching of multiple URLs with max_concurrent limit, automatic retry with exponential backoff (2^attempt seconds), JSON response parsing, comprehensive error handling with exception categorization, TCP connection pooling with configurable limits, 30-second timeout on requests, structured logging, and type hints throughout. The main issues to analyze are: 1) The semaphore is created in __init__ but used in fetch_single which may cause issues if the object is copied, 2) No rate limiting between requests to the same host, 3) The return_exceptions=True in gather() means we process exceptions manually but lose stack traces, 4) No cancellation support for in-flight requests, 5) The connector limit (100) is much higher than the semaphore limit (10 by default) which wastes resources. Please provide specific recommendations for each issue with code examples. Also suggest any additional improvements for production use."

echo "=== Long Context Benchmark (~300 tokens) ==="
echo ""

for model in "${MODELS[@]}"; do
    echo "----------------------------------------"
    echo "Model: $model"
    echo "----------------------------------------"
    
    # Create JSON payload properly
    JSON_PAYLOAD=$(jq -n \
        --arg model "$model" \
        --arg prompt "$LONG_PROMPT" \
        '{model: $model, prompt: $prompt, stream: false, options: {num_predict: 150}}')
    
    START_TIME=$(date +%s.%N)
    
    RESULT=$(curl -s http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d "$JSON_PAYLOAD")
    
    END_TIME=$(date +%s.%N)
    
    # Check if result is valid
    if echo "$RESULT" | jq -e '.response' > /dev/null 2>&1; then
        TOTAL_DURATION=$(echo "$RESULT" | jq -r '.total_duration // 0')
        PROMPT_EVAL_COUNT=$(echo "$RESULT" | jq -r '.prompt_eval_count // 0')
        PROMPT_EVAL_DURATION=$(echo "$RESULT" | jq -r '.prompt_eval_duration // 0')
        EVAL_COUNT=$(echo "$RESULT" | jq -r '.eval_count // 0')
        EVAL_DURATION=$(echo "$RESULT" | jq -r '.eval_duration // 0')
        
        TOTAL_SEC=$(echo "scale=3; $TOTAL_DURATION / 1000000000" | bc 2>/dev/null)
        PROMPT_EVAL_SEC=$(echo "scale=3; $PROMPT_EVAL_DURATION / 1000000000" | bc 2>/dev/null)
        EVAL_SEC=$(echo "scale=3; $EVAL_DURATION / 1000000000" | bc 2>/dev/null)
        
        if [ "$PROMPT_EVAL_DURATION" -gt 0 ] 2>/dev/null; then
            PROMPT_TPS=$(echo "scale=2; $PROMPT_EVAL_COUNT / $PROMPT_EVAL_SEC" | bc 2>/dev/null)
        else
            PROMPT_TPS="N/A"
        fi
        
        if [ "$EVAL_DURATION" -gt 0 ] 2>/dev/null; then
            TPS=$(echo "scale=2; $EVAL_COUNT / $EVAL_SEC" | bc 2>/dev/null)
        else
            TPS="N/A"
        fi
        
        echo "  Total time: ${TOTAL_SEC}s"
        echo "  Prompt tokens: $PROMPT_EVAL_COUNT (${PROMPT_EVAL_SEC}s)"
        echo "  Prompt processing: $PROMPT_TPS tokens/sec"
        echo "  Output tokens: $EVAL_COUNT (${EVAL_SEC}s)"
        echo "  Generation speed: $TPS tokens/sec"
    else
        echo "  Error: Failed to get valid response"
        echo "  Raw result: $RESULT"
    fi
    echo ""
done

echo "=== Benchmark Complete ==="
