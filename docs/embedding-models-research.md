# Local Embedding Models Research

## For 16GB Mac mini M4 (Memory-Constrained)

### Recommended Models

| Model | Size | Dimensions | Max Tokens | Memory Usage | Best For |
|-------|------|------------|------------|--------------|----------|
| **all-MiniLM-L6-v2** (Sentence-Transformers) | ~22MB | 384 | 512 | ~50MB RAM | General purpose, fast |
| **all-MiniLM-L12-v2** | ~33MB | 384 | 512 | ~70MB RAM | Better quality than L6 |
| **bge-small-en-v1.5** (BAAI) | ~33MB | 384 | 512 | ~70MB RAM | Retrieval tasks, MTEB leader |
| **jina-embeddings-v2-small** | ~32MB | 512 | 8192 | ~70MB RAM | Long documents |
| **gte-small** (Alibaba) | ~34MB | 384 | 512 | ~70MB RAM | High performance small model |
| **E5-small-v2** (Microsoft) | ~34MB | 384 | 512 | ~70MB RAM | Multilingual, asymmetric |

### Key Considerations for 16GB Mac mini M4
- **Memory limit**: With 16GB unified memory, aim for models under 100MB
- **Quantization**: Use Q4_K_M or Q5_K_M quantized versions via Ollama
- **Concurrent usage**: Leave headroom for OS + other apps (~4-6GB)
- **Throughput**: MiniLM models achieve 1000+ embeddings/sec on M4

### Ollama Commands for 16GB Setup
```bash
# Pull small embedding models
ollama pull nomic-embed-text
ollama pull mxbai-embed-large  # Larger but excellent quality

# Alternative: Use Sentence Transformers via Python
pip install sentence-transformers
```

---

## For 256GB Mac Studio M3 Ultra (High-Performance)

### Recommended Models

| Model | Size | Dimensions | Max Tokens | Memory Usage | Best For |
|-------|------|------------|------------|--------------|----------|
| **bge-large-en-v1.5** (BAAI) | ~1.3GB | 1024 | 512 | ~2.5GB RAM | Best overall quality |
| **gte-large** (Alibaba) | ~1.3GB | 1024 | 512 | ~2.5GB RAM | Excellent retrieval |
| **e5-large-v2** (Microsoft) | ~1.3GB | 1024 | 512 | ~2.5GB RAM | Multilingual |
| **jina-embeddings-v2-base** | ~300MB | 768 | 8192 | ~600MB RAM | Long context leader |
| **SFR-Embedding-Mistral** | ~4GB | 4096 | 32768 | ~8GB RAM | State-of-the-art |
| **GritLM-7B** | ~14GB | 4096 | 32768 | ~28GB RAM | Best quality, generative |
| **nomic-embed-text-v1.5** | ~550MB | 768 | 8192 | ~1.1GB RAM | Long context, Nomic |

### Key Considerations for 256GB Mac Studio M3 Ultra
- **Massive headroom**: Can run multiple large models simultaneously
- **Batch processing**: Utilize large batch sizes (256-512) for throughput
- **Multiple workers**: Run 8-16 concurrent embedding processes
- **Larger context models**: Benefit from 8K+ token models for documents

### Ollama Commands for 256GB Setup
```bash
# Large embedding models
ollama pull mxbai-embed-large:latest
ollama pull nomic-embed-text:latest

# Via Python for cutting-edge models
pip install sentence-transformers
# Download: BAAI/bge-large-en-v1.5, Alibaba-NLP/gte-large, etc.
```

---

## Benchmark Considerations

### Standard Benchmarks
1. **MTEB (Massive Text Embedding Benchmark)** - Industry standard
   - Classification, clustering, retrieval, STS tasks
2. **BEIR** - Information retrieval benchmark
3. **LongEmbed** - Long context evaluation

### Key Metrics
- **NDCG@10** - Normalized Discounted Cumulative Gain (retrieval quality)
- **Accuracy** - Classification/clustering performance
- **Spearman Correlation** - Semantic similarity (STS tasks)
- **Throughput** - Embeddings/second
- **Latency** - Time to first embedding

### Hardware-Specific Metrics to Collect
- Memory usage during inference
- GPU utilization (%)
- Power consumption (Watts)
- Temperature throttling impact
