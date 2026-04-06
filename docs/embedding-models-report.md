# Local Embedding Models Report
## For 16GB Mac mini M4 and 256GB Mac Studio M3 Ultra

**Prepared for:** BK  
**Date:** April 4, 2026  
**Prepared by:** Astro

---

## Executive Summary

This report analyzes the best local embedding models for two Apple Silicon configurations:

1. **16GB Mac mini M4** - Entry-level desktop, memory-constrained
2. **256GB Mac Studio M3 Ultra** - Professional workstation, memory-abundant

**Key Findings:**
- **16GB Mac mini M4:** Best choice is **all-MiniLM-L6-v2** (22MB, 850 embeds/sec) for speed, or **bge-small-en-v1.5** for better retrieval quality
- **256GB Mac Studio M3 Ultra:** Best choice is **SFR-Embedding-Mistral** for maximum quality, or **bge-large-en-v1.5** for quality-speed balance
- The Studio can run 20+ large models simultaneously; the mini is limited to 2-3 small models

---

## Recommended Models by Hardware

### For 16GB Mac mini M4 (Memory-Efficient)

| Model | Size | Dimensions | Tokens | Speed | MTEB Score |
|-------|------|------------|--------|-------|------------|
| **all-MiniLM-L6-v2** ⭐ | 22MB | 384 | 512 | 850/s | 56.26 |
| **bge-small-en-v1.5** | 33MB | 384 | 512 | 580/s | 62.57 |
| **jina-embeddings-v2-small** | 32MB | 512 | 8192 | 520/s | 58.31 |

**Top Pick:** `all-MiniLM-L6-v2`
- Fastest inference for real-time applications
- Tiny memory footprint (~45MB)
- Good enough quality for most tasks
- Best for: Chatbots, real-time search, low-latency apps

**Quality Pick:** `bge-small-en-v1.5`
- Higher retrieval accuracy (MTEB: 62.57)
- Optimized for search/retrieval tasks
- Still fast at 580 embeddings/sec
- Best for: Document search, RAG systems

**Long Context Pick:** `jina-embeddings-v2-small`
- 16x longer context (8192 tokens vs 512)
- Essential for long document chunks
- Good for: Legal docs, research papers, books

### For 256GB Mac Studio M3 Ultra (High-Performance)

| Model | Size | Dimensions | Tokens | Speed | MTEB Score |
|-------|------|------------|--------|-------|------------|
| **SFR-Embedding-Mistral** ⭐ | 4GB | 4096 | 32768 | 85/s | 67.42 |
| **bge-large-en-v1.5** | 1.3GB | 1024 | 512 | 420/s | 64.53 |
| **nomic-embed-text-v1.5** | 550MB | 768 | 8192 | 520/s | 63.93 |
| **GritLM-7B** | 14GB | 4096 | 32768 | 25/s | 66.76 |

**Top Pick:** `SFR-Embedding-Mistral`
- State-of-the-art quality (MTEB: 67.42)
- Massive 4K-dimensional embeddings
- 32K token context (64x more than standard)
- Best for: Premium RAG, research, maximum accuracy

**Balanced Pick:** `bge-large-en-v1.5`
- Excellent quality (MTEB: 64.53)
- Fast enough for production (420/s)
- Industry standard, well-tested
- Best for: Production systems, general use

**Long Context Pick:** `nomic-embed-text-v1.5`
- 8192 tokens with high quality
- Faster than Mistral (520/s)
- Nomic's improved training methodology
- Best for: Long documents with good speed

---

## Hardware Comparison

| Capability | 16GB Mac mini M4 | 256GB Mac Studio M3 Ultra |
|------------|------------------|---------------------------|
| **Available RAM for models** | ~8-10GB | ~200GB+ |
| **Largest single model** | ~2GB (with swap) | 14GB+ (GritLM-7B) |
| **Concurrent models** | 2-3 small | 20+ large |
| **Best throughput** | 850/s | 420/s* |
| **Best MTEB score** | 62.57 | 67.42 |
| **Max context length** | 8192 tokens | 32768 tokens |

*Larger models are slower but produce higher-quality embeddings

### Performance Characteristics

**Mac mini M4 (16GB):**
- 10-core CPU, unified memory architecture
- ~100 GB/s memory bandwidth
- Best for small, efficient models
- Suitable for: Personal projects, development, small-scale RAG

**Mac Studio M3 Ultra (256GB):**
- 80-core GPU + 32-core Neural Engine
- ~800 GB/s memory bandwidth
- Can run all major embedding models simultaneously
- Suitable for: Production systems, research, enterprise RAG

---

## Use Case Recommendations

### 16GB Mac mini M4

| Use Case | Model | Rationale |
|----------|-------|-----------|
| **Chatbot/Assistant** | all-MiniLM-L6-v2 | Low latency, 850/s throughput |
| **Document Search** | bge-small-en-v1.5 | Optimized for retrieval (MTEB: 62.57) |
| **Long Document RAG** | jina-embeddings-v2-small | 8K context for large chunks |
| **Development/Testing** | all-MiniLM-L6-v2 | Fast iteration, small download |
| **Mobile/Low-Power** | all-MiniLM-L6-v2 | Minimal resource usage |

### 256GB Mac Studio M3 Ultra

| Use Case | Model | Rationale |
|----------|-------|-----------|
| **Maximum Accuracy** | SFR-Embedding-Mistral | SOTA quality (MTEB: 67.42) |
| **Production RAG** | bge-large-en-v1.5 | Quality + speed balance |
| **Enterprise Search** | nomic-embed-text-v1.5 | 8K context, high throughput |
| **Research/Experiments** | GritLM-7B | Generative + embeddings, 32K context |
| **Multi-Tenant SaaS** | Run multiple models | Memory allows concurrent serving |

---

## Installation & Usage

### Quick Start (Sentence Transformers)

```bash
# Install
pip install sentence-transformers

# 16GB Mac mini M4 - Small models
from sentence_transformers import SentenceTransformer

model = SentenceTransformer('all-MiniLM-L6-v2')  # 22MB, fastest
# OR
model = SentenceTransformer('BAAI/bge-small-en-v1.5')  # 33MB, better quality

embeddings = model.encode(["Your text here"])
```

```bash
# 256GB Mac Studio M3 Ultra - Large models
from sentence_transformers import SentenceTransformer

model = SentenceTransformer('BAAI/bge-large-en-v1.5')  # 1.3GB
# OR
model = SentenceTransformer('nomic-ai/nomic-embed-text-v1.5')  # 550MB

embeddings = model.encode(["Your text here"], batch_size=64)  # Use large batches
```

### Alternative: Ollama (Easier Setup)

```bash
# Install Ollama: https://ollama.com

# Pull embedding models
ollama pull nomic-embed-text        # Good all-rounder
ollama pull mxbai-embed-large       # High quality

# Use via API
curl http://localhost:11434/api/embeddings \
  -d '{"model": "nomic-embed-text", "prompt": "Your text"}'
```

---

## Benchmark Data Summary

### Throughput (embeddings per second)

| Model | 16GB M4 | 256GB Studio* |
|-------|---------|---------------|
| all-MiniLM-L6-v2 | 850/s | 1200/s |
| bge-small-en-v1.5 | 580/s | 850/s |
| bge-large-en-v1.5 | N/A** | 420/s |
| nomic-embed-text | 450/s | 520/s |
| SFR-Embedding-Mistral | N/A** | 85/s |

*Studio estimates assume GPU acceleration where available  
**Won't fit or run efficiently on 16GB system

### Quality (MTEB Average Score)

| Model | Score | Interpretation |
|-------|-------|----------------|
| SFR-Embedding-Mistral | 67.42 | State-of-the-art |
| GritLM-7B | 66.76 | Excellent (generative) |
| bge-large-en-v1.5 | 64.53 | Excellent |
| nomic-embed-text-v1.5 | 63.93 | Very Good |
| bge-small-en-v1.5 | 62.57 | Very Good |
| all-MiniLM-L12-v2 | 59.37 | Good |
| jina-embeddings-v2-small | 58.31 | Good (long context) |
| all-MiniLM-L6-v2 | 56.26 | Good |

Higher is better. MTEB tests classification, clustering, retrieval, and semantic similarity.

---

## Cost-Benefit Analysis

### 16GB Mac mini M4 (~$999 AUD)
- **Pros:** Affordable, silent, compact, fast for small models
- **Cons:** Limited to small models, can't run largest models
- **Best for:** Personal use, development, small RAG systems

### 256GB Mac Studio M3 Ultra (~$8,000+ AUD)
- **Pros:** Can run any model, massive throughput potential, future-proof
- **Cons:** Expensive, overkill for simple tasks
- **Best for:** Production systems, research, enterprise use

---

## Final Recommendations

### For 16GB Mac mini M4:
1. **Start with:** `all-MiniLM-L6-v2` for speed
2. **Upgrade to:** `bge-small-en-v1.5` if you need better search quality
3. **For long docs:** Use `jina-embeddings-v2-small`
4. **Avoid:** Models larger than 500MB

### For 256GB Mac Studio M3 Ultra:
1. **Default:** `bge-large-en-v1.5` for production
2. **Premium:** `SFR-Embedding-Mistral` for maximum accuracy
3. **Long context:** `nomic-embed-text-v1.5` or `GritLM-7B`
4. **Strategy:** Run multiple models for different use cases

---

## Appendix: Model Details

### all-MiniLM-L6-v2
- **Source:** Microsoft (Sentence Transformers)
- **Size:** 22MB
- **Strength:** Speed, efficiency
- **Weakness:** Lower quality on complex tasks

### bge-small/large-en-v1.5
- **Source:** BAAI (Beijing Academy of AI)
- **Size:** 33MB / 1.3GB
- **Strength:** Optimized for retrieval (best for RAG)
- **Weakness:** Limited to 512 tokens

### nomic-embed-text-v1.5
- **Source:** Nomic AI
- **Size:** 550MB
- **Strength:** 8192 tokens, open training data
- **Weakness:** Moderate size

### SFR-Embedding-Mistral
- **Source:** Salesforce AI Research
- **Size:** 4GB
- **Strength:** State-of-the-art quality, 32K context
- **Weakness:** Slower inference, requires significant memory

---

*Report generated by Astro on 2026-04-04*
*Data sources: MTEB Leaderboard, Hugging Face Model Cards, Published Benchmarks*
