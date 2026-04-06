#!/usr/bin/env python3
"""
Embedding Model Benchmark Suite
Tests local embedding models for performance and quality metrics.
"""

import time
import psutil
import json
import sys
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, asdict
from datetime import datetime

# Test sentences for benchmarking
TEST_SENTENCES = [
    "The quick brown fox jumps over the lazy dog.",
    "Machine learning is a subset of artificial intelligence.",
    "The cat sat on the mat and looked out the window.",
    "Python is a popular programming language for data science.",
    "The Earth revolves around the Sun in approximately 365 days.",
    "Neural networks are inspired by biological neural systems.",
    "The Great Wall of China is visible from space.",
    "Coffee is one of the most traded commodities in the world.",
    "Photosynthesis converts light energy into chemical energy.",
    "The Internet was originally developed for military communication.",
    # Add more for batch testing
    "Water boils at 100 degrees Celsius at sea level.",
    "The human brain contains approximately 86 billion neurons.",
    "DNA stands for deoxyribonucleic acid.",
    "The speed of light is approximately 299,792,458 meters per second.",
    "Shakespeare wrote 37 plays during his lifetime.",
    "The Amazon rainforest produces 20% of the world's oxygen.",
    "Antibiotics are ineffective against viral infections.",
    "The Mona Lisa was painted by Leonardo da Vinci.",
    "Gravity is one of the four fundamental forces of nature.",
    "The Pacific Ocean is the largest ocean on Earth.",
]

SIMILARITY_PAIRS = [
    ("The cat sat on the mat.", "A cat was sitting on a rug.", 0.9),
    ("Dogs are loyal pets.", "Canines make faithful companions.", 0.85),
    ("Machine learning is amazing.", "I love programming in Python.", 0.3),
    ("The weather is sunny today.", "It's a bright and clear day.", 0.8),
    ("Cars drive on roads.", "Airplanes fly in the sky.", 0.4),
]

@dataclass
class BenchmarkResult:
    model_name: str
    model_size_mb: Optional[float]
    dimensions: int
    max_tokens: int
    
    # Performance metrics
    load_time_ms: float
    single_embed_ms: float
    batch_10_embed_ms: float
    batch_20_embed_ms: float
    throughput_per_sec: float
    
    # Memory metrics
    memory_before_mb: float
    memory_after_mb: float
    memory_used_mb: float
    
    # Quality metrics (if computed)
    avg_similarity_score: Optional[float] = None
    
    # System info
    timestamp: str = ""
    cpu_count: int = 0
    total_memory_gb: float = 0.0
    
    def __post_init__(self):
        if not self.timestamp:
            self.timestamp = datetime.now().isoformat()
        if not self.cpu_count:
            self.cpu_count = psutil.cpu_count()
        if not self.total_memory_gb:
            self.total_memory_gb = psutil.virtual_memory().total / (1024**3)


def benchmark_sentence_transformers(model_name: str, device: str = "cpu") -> BenchmarkResult:
    """Benchmark a sentence-transformers model."""
    from sentence_transformers import SentenceTransformer
    
    print(f"\n{'='*60}")
    print(f"Benchmarking: {model_name}")
    print(f"{'='*60}")
    
    # Memory before loading
    process = psutil.Process()
    mem_before = process.memory_info().rss / (1024**2)
    
    # Load model
    load_start = time.time()
    model = SentenceTransformer(model_name, device=device)
    load_time = (time.time() - load_start) * 1000
    
    mem_after_load = process.memory_info().rss / (1024**2)
    memory_used = mem_after_load - mem_before
    
    # Get model info
    dimensions = model.get_sentence_embedding_dimension()
    max_tokens = model.max_seq_length
    
    # Try to estimate model size
    try:
        import os
        model_path = model.model_path if hasattr(model, 'model_path') else ""
        if model_path and os.path.exists(model_path):
            total_size = sum(
                os.path.getsize(os.path.join(dirpath, filename))
                for dirpath, dirnames, filenames in os.walk(model_path)
                for filename in filenames
            )
            model_size_mb = total_size / (1024**2)
        else:
            model_size_mb = None
    except:
        model_size_mb = None
    
    # Warmup
    print("  Warming up...")
    _ = model.encode(TEST_SENTENCES[0], convert_to_numpy=True)
    
    # Single embedding
    print("  Testing single embedding...")
    single_times = []
    for _ in range(10):
        start = time.time()
        _ = model.encode(TEST_SENTENCES[0], convert_to_numpy=True)
        single_times.append((time.time() - start) * 1000)
    single_embed_ms = sum(single_times) / len(single_times)
    
    # Batch of 10
    print("  Testing batch of 10...")
    batch_10_start = time.time()
    _ = model.encode(TEST_SENTENCES[:10], convert_to_numpy=True, batch_size=10)
    batch_10_embed_ms = (time.time() - batch_10_start) * 1000
    
    # Batch of 20
    print("  Testing batch of 20...")
    batch_20_start = time.time()
    _ = model.encode(TEST_SENTENCES, convert_to_numpy=True, batch_size=20)
    batch_20_embed_ms = (time.time() - batch_20_start) * 1000
    
    # Throughput test
    print("  Testing throughput...")
    throughput_start = time.time()
    iterations = 5
    for _ in range(iterations):
        _ = model.encode(TEST_SENTENCES, convert_to_numpy=True, batch_size=20)
    throughput_time = time.time() - throughput_start
    total_embeddings = len(TEST_SENTENCES) * iterations
    throughput_per_sec = total_embeddings / throughput_time
    
    # Similarity test
    print("  Testing similarity accuracy...")
    from sklearn.metrics.pairwise import cosine_similarity
    similarities = []
    for sent1, sent2, expected in SIMILARITY_PAIRS:
        emb1 = model.encode(sent1, convert_to_numpy=True)
        emb2 = model.encode(sent2, convert_to_numpy=True)
        sim = cosine_similarity([emb1], [emb2])[0][0]
        similarities.append(abs(sim - expected))
    avg_similarity_error = sum(similarities) / len(similarities)
    avg_similarity_score = 1.0 - avg_similarity_error
    
    # Final memory
    mem_final = process.memory_info().rss / (1024**2)
    
    result = BenchmarkResult(
        model_name=model_name,
        model_size_mb=model_size_mb,
        dimensions=dimensions,
        max_tokens=max_tokens,
        load_time_ms=load_time,
        single_embed_ms=single_embed_ms,
        batch_10_embed_ms=batch_10_embed_ms,
        batch_20_embed_ms=batch_20_embed_ms,
        throughput_per_sec=throughput_per_sec,
        memory_before_mb=mem_before,
        memory_after_mb=mem_final,
        memory_used_mb=mem_final - mem_before,
        avg_similarity_score=avg_similarity_score
    )
    
    print(f"  ✓ Complete: {throughput_per_sec:.1f} embeddings/sec")
    return result


def benchmark_ollama(model_name: str, host: str = "http://localhost:11434") -> Optional[BenchmarkResult]:
    """Benchmark an Ollama embedding model."""
    import requests
    
    print(f"\n{'='*60}")
    print(f"Benchmarking Ollama: {model_name}")
    print(f"{'='*60}")
    
    # Check if Ollama is running
    try:
        response = requests.get(f"{host}/api/tags", timeout=5)
        if response.status_code != 200:
            print(f"  ✗ Ollama not responding at {host}")
            return None
    except Exception as e:
        print(f"  ✗ Cannot connect to Ollama: {e}")
        return None
    
    # Check if model exists
    models = response.json().get("models", [])
    model_exists = any(m["name"].startswith(model_name) for m in models)
    if not model_exists:
        print(f"  ✗ Model {model_name} not found. Run: ollama pull {model_name}")
        return None
    
    # Memory before
    process = psutil.Process()
    mem_before = process.memory_info().rss / (1024**2)
    
    # Load model (first embedding loads it)
    print("  Loading model...")
    load_start = time.time()
    response = requests.post(
        f"{host}/api/embeddings",
        json={"model": model_name, "prompt": TEST_SENTENCES[0]},
        timeout=60
    )
    load_time = (time.time() - load_start) * 1000
    
    if response.status_code != 200:
        print(f"  ✗ Failed to get embedding: {response.text}")
        return None
    
    embedding = response.json().get("embedding", [])
    dimensions = len(embedding)
    
    mem_after_load = process.memory_info().rss / (1024**2)
    
    # Single embedding
    print("  Testing single embedding...")
    single_times = []
    for _ in range(10):
        start = time.time()
        requests.post(
            f"{host}/api/embeddings",
            json={"model": model_name, "prompt": TEST_SENTENCES[0]},
            timeout=30
        )
        single_times.append((time.time() - start) * 1000)
    single_embed_ms = sum(single_times) / len(single_times)
    
    # Batch via multiple requests (Ollama doesn't natively batch)
    print("  Testing batch of 10...")
    batch_10_start = time.time()
    for sent in TEST_SENTENCES[:10]:
        requests.post(
            f"{host}/api/embeddings",
            json={"model": model_name, "prompt": sent},
            timeout=30
        )
    batch_10_embed_ms = (time.time() - batch_10_start) * 1000
    
    print("  Testing batch of 20...")
    batch_20_start = time.time()
    for sent in TEST_SENTENCES:
        requests.post(
            f"{host}/api/embeddings",
            json={"model": model_name, "prompt": sent},
            timeout=30
        )
    batch_20_embed_ms = (time.time() - batch_20_start) * 1000
    
    # Throughput
    print("  Testing throughput...")
    throughput_start = time.time()
    for sent in TEST_SENTENCES * 3:
        requests.post(
            f"{host}/api/embeddings",
            json={"model": model_name, "prompt": sent},
            timeout=30
        )
    throughput_time = time.time() - throughput_start
    total_embeddings = len(TEST_SENTENCES) * 3
    throughput_per_sec = total_embeddings / throughput_time
    
    mem_final = process.memory_info().rss / (1024**2)
    
    result = BenchmarkResult(
        model_name=f"ollama/{model_name}",
        model_size_mb=None,  # Would need to check Ollama's model storage
        dimensions=dimensions,
        max_tokens=8192,  # Most Ollama embedding models use 8K
        load_time_ms=load_time,
        single_embed_ms=single_embed_ms,
        batch_10_embed_ms=batch_10_embed_ms,
        batch_20_embed_ms=batch_20_embed_ms,
        throughput_per_sec=throughput_per_sec,
        memory_before_mb=mem_before,
        memory_after_mb=mem_final,
        memory_used_mb=mem_final - mem_before,
        avg_similarity_score=None  # Would need additional computation
    )
    
    print(f"  ✓ Complete: {throughput_per_sec:.1f} embeddings/sec")
    return result


def save_results(results: List[BenchmarkResult], output_path: str):
    """Save benchmark results to JSON."""
    data = {
        "timestamp": datetime.now().isoformat(),
        "system": {
            "cpu_count": psutil.cpu_count(),
            "total_memory_gb": psutil.virtual_memory().total / (1024**3),
            "platform": sys.platform
        },
        "results": [asdict(r) for r in results]
    }
    with open(output_path, 'w') as f:
        json.dump(data, f, indent=2)
    print(f"\n✓ Results saved to {output_path}")


def print_summary(results: List[BenchmarkResult]):
    """Print a summary table of results."""
    print("\n" + "="*100)
    print("BENCHMARK SUMMARY")
    print("="*100)
    print(f"{'Model':<35} {'Dims':>6} {'Load(ms)':>10} {'Single(ms)':>11} {'Throughput':>12} {'Memory(MB)':>11}")
    print("-"*100)
    
    for r in sorted(results, key=lambda x: x.throughput_per_sec, reverse=True):
        print(f"{r.model_name:<35} {r.dimensions:>6} {r.load_time_ms:>10.1f} {r.single_embed_ms:>11.2f} {r.throughput_per_sec:>11.1f}/s {r.memory_used_mb:>10.1f}")
    
    print("="*100)


def main():
    """Run the benchmark suite."""
    print("="*60)
    print("EMBEDDING MODEL BENCHMARK SUITE")
    print("="*60)
    print(f"System: {psutil.cpu_count()} CPUs, {psutil.virtual_memory().total / (1024**3):.1f} GB RAM")
    print(f"Platform: {sys.platform}")
    print("="*60)
    
    results = []
    
    # Check for sentence-transformers
    try:
        import sentence_transformers
        print("\n✓ sentence-transformers available")
        
        # Small models for 16GB Mac mini M4
        small_models = [
            "all-MiniLM-L6-v2",
            "all-MiniLM-L12-v2", 
            "BAAI/bge-small-en-v1.5",
            "jinaai/jina-embeddings-v2-small",
        ]
        
        for model_name in small_models:
            try:
                result = benchmark_sentence_transformers(model_name)
                results.append(result)
            except Exception as e:
                print(f"  ✗ Failed: {e}")
                
    except ImportError:
        print("\n✗ sentence-transformers not installed")
        print("  Install with: pip install sentence-transformers")
    
    # Check for Ollama models
    try:
        import requests
        response = requests.get("http://localhost:11434/api/tags", timeout=2)
        if response.status_code == 200:
            print("\n✓ Ollama available")
            
            ollama_models = ["nomic-embed-text", "mxbai-embed-large"]
            for model_name in ollama_models:
                result = benchmark_ollama(model_name)
                if result:
                    results.append(result)
        else:
            print("\n✗ Ollama not responding")
    except:
        print("\n✗ Ollama not available")
    
    # Save and summarize results
    if results:
        output_path = f"embedding_benchmark_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        save_results(results, output_path)
        print_summary(results)
    else:
        print("\n✗ No benchmarks completed successfully")
        sys.exit(1)


if __name__ == "__main__":
    main()
