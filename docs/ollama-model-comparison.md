# Ollama Model Comparison: frob/qwen3.5-instruct:9b vs qwen3.5-instruct:9b-32k

## Key Differences

| Feature | frob/qwen3.5-instruct:9b | qwen3.5-instruct:9b-32k |
|---------|--------------------------|------------------------|
| **Context Window (default)** | 2,048 tokens | 32,768 tokens |
| **Thinking Mode** | Non-thinking (disabled) | Standard (thinking enabled) |
| **Quantization** | Q4_K_M | Q4_K_M |
| **Parameters** | 9.7B | 9.7B |
| **Architecture** | qwen35 | qwen35 |
| **Batch Size** | Default | 512 |
| **GPU Layers** | Auto | 35 (forced) |
| **CPU Threads** | Auto | 4 |

## Configuration Details

### frob/qwen3.5-instruct:9b (Non-thinking)
```
Parameters:
  presence_penalty: 1.5
  temperature: 1
  top_k: 20
  top_p: 0.95

Template: Standard Qwen3.5 with <think> block (but empty)
```

**Key Feature:** This is a modified version that disables Qwen3.5's thinking mode. The model still has the `<think>` tag in the template but it's empty, so responses come directly without reasoning steps.

### qwen3.5-instruct:9b-32k
```
Parameters:
  num_batch: 512
  num_ctx: 32000
  num_gpu: 35
  num_thread: 4
  presence_penalty: 1.5
  temperature: 1
  top_k: 20
  top_p: 0.95
```

**Key Feature:** Pre-configured for 32K context window with explicit resource allocation.

## Performance Benchmarks

### Short Prompt (~35 tokens, 300 output)
| Metric | frob | 32k |
|--------|------|-----|
| Total Time | 27.97s | 28.46s |
| Load Time | 3.14s | 3.63s |
| Tokens/sec | 12.85 | 12.74 |

### Medium Prompt (~246 tokens, 150 output)
| Metric | frob | 32k |
|--------|------|-----|
| Total Time | 17.78s | 18.05s |
| Prompt Processing | 91.14 t/s | 110.41 t/s |
| Generation | 12.75 t/s | 12.65 t/s |

### 8K Context Test
| Metric | frob | 32k |
|--------|------|-----|
| Total Time | 17.67s | 16.96s |
| Generation | 12.68 t/s | 12.67 t/s |

## Why the 32k Model Might Be Slower for You

Even though benchmarks show similar speeds, the 32k model can be slower in practice because:

1. **Memory Allocation**: The 32k model pre-allocates KV cache for 32,768 tokens
   - At Q4_K_M quantization: ~4 bytes per token per layer
   - 9B model has ~40 layers
   - 32K × 40 × 4 bytes = ~5GB just for KV cache!
   - frob model only allocates for 2K context = ~320MB

2. **GPU Layer Offloading**: With `num_gpu: 35` set, if your GPU has limited VRAM:
   - The model may partially offload to CPU
   - CPU inference is 10-50x slower than GPU
   - frob model lets Ollama auto-decide based on available VRAM

3. **Batch Processing**: `num_batch: 512` can cause memory pressure on systems with limited VRAM

## Recommendations

### Use **frob/qwen3.5-instruct:9b** when:
- You want faster responses for typical chat/tasks
- You don't need thinking/reasoning steps
- You have limited VRAM (< 16GB)
- Working with short-to-medium contexts (< 4K tokens)
- You want Ollama to auto-optimize GPU layers

### Use **qwen3.5-instruct:9b-32k** when:
- You need long context support (16K-32K tokens)
- You have plenty of VRAM (16GB+)
- Processing long documents or codebases
- You want the model's thinking/reasoning capability

### Override Options

To use frob with 32K context:
```bash
ollama run frob/qwen3.5-instruct:9b --num_ctx 32768
```

To use 32k with smaller context (faster):
```bash
ollama run qwen3.5-instruct:9b-32k --num_ctx 4096
```

To check GPU offloading:
```bash
ollama ps  # Shows which models are loaded and GPU %
```

## Conclusion

The **frob** model is faster because:
1. It has thinking mode disabled (direct answers)
2. It uses default 2K context (less memory pressure)
3. It auto-optimizes GPU offloading

The **32k** model appears slower likely due to memory allocation overhead, not raw inference speed. If you need long context, the 32k model is appropriate but requires sufficient VRAM.
