# How-To: Use Local LLM Models in OpenClaw

## Current Setup (as of 2026-03-15)

### Available Local Models

| Model | Provider | Context | Best For |
|-------|----------|---------|----------|
| qwen3.5:9b | Ollama | 64K | General tasks, coding |
| qwen3.5:2b | Ollama | 64K | Fast responses, simple queries |
| qwen3.5-9b-mlx | LM Studio | 64K | High-quality local inference |
| gemma-3-4b | LM Studio | 20K | Balanced speed/quality |

## How to Switch to Local Models

### Method 1: Command Line (Temporary)
```bash
# Use a specific model for this session
openclaw run --model ollama/qwen3.5:9b

# Or use MLX via LM Studio
openclaw run --model lmstudio/qwen3.5-9b-mlx
```

### Method 2: Config File (Permanent)
Edit `~/.openclaw/openclaw.json`:

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "lmstudio/qwen3.5-9b-mlx",
        "fallbacks": [
          "ollama/qwen3.5:9b",
          "ollama/qwen3.5:2b"
        ]
      }
    }
  }
}
```

### Method 3: Per-Session Override
In any conversation:
```
/model ollama/qwen3.5:9b
```

## When to Use Local vs Cloud

| Use Case | Recommendation |
|----------|---------------|
| Quick tasks, low latency | Local (qwen3.5:2b) |
| Coding, complex reasoning | Local (qwen3.5-9b-mlx) |
| Image analysis | Local (qwen3.5:9b) |
| Long context (128K+) | Cloud (Kimi K2.5) |
| Best quality responses | Cloud (Kimi K2.5) |

## Checking Local Model Status

```bash
# Check Ollama models
ollama list

# Check LM Studio models
curl http://127.0.0.1:1234/v1/models

# Test if local models are responding
openclaw run --model lmstudio/qwen3.5-9b-mlx --prompt "Hello"
```

## Fallback Chain

Current fallback order:
1. **Primary:** moonshot/kimi-k2.5 (cloud)
2. **Fallback 1:** lmstudio/google/gemma-3-4b (local)
3. **Fallback 2:** lmstudio/qwen3.5-9b-mlx (local)

If you want pure local operation, set primary to a local model.

## Cost Comparison

| Model | Input Cost | Output Cost |
|-------|-----------|-------------|
| Kimi K2.5 | $0 (in config) | $0 (in config) |
| qwen3.5:9b (Ollama) | $0 | $0 |
| qwen3.5-9b-mlx | $0 | $0 |

All local models run at $0 cost.

## Troubleshooting

### LM Studio not responding?
```bash
# Check if LM Studio is running
curl http://127.0.0.1:1234/v1/models

# Restart LM Studio if needed
```

### Ollama not responding?
```bash
# Check Ollama status
ollama list

# Start Ollama if needed
ollama serve
```

### Model not found error?
```bash
# Pull the model
ollama pull qwen3.5:9b

# Or download via LM Studio UI
```

---
*Document created: 2026-03-15*
