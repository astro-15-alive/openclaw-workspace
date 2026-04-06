#!/usr/bin/env python3
"""
Simplified Embedding Benchmark - Single Model Test
Avoids threading issues by testing one model at a time
"""

import time
import json
import sys
import os
from datetime import datetime

# Disable threading warnings
os.environ['KMP_DUPLICATE_LIB_OK'] = 'TRUE'
os.environ['TOKENIZERS_PARALLELISM'] = 'false'

TEST_SENTENCES = [
    "The quick brown fox jumps over the lazy dog.",
    "Machine learning is a subset of artificial intelligence.",
    "The cat sat on the mat and looked out the window.",
    "Python is a popular programming language for data science.",
    "The Earth revolves around the Sun in approximately 365 days.",
    "Neural networks are inspired by biological neural systems.",
    "The Great Wall of China is visible from space.",
    "Coffee is one of the most traded commodities in the world.",
]

def benchmark_model(model_name):
    """Benchmark a single embedding model."""
    print(f"\nTesting: {model_name}")
    print("-" * 50)
    
    from sentence_transformers import SentenceTransformer
    
    # Load
    start = time.time()
    model = SentenceTransformer(model_name, device='cpu')
    load_time = time.time() - start
    
    # Get info
    dims = model.get_sentence_embedding_dimension()
    max_tokens = model.max_seq_length
    
    # Single inference
    start = time.time()
    _ = model.encode(TEST_SENTENCES[0], convert_to_numpy=True)
    single_time = time.time() - start
    
    # Batch inference
    start = time.time()
    _ = model.encode(TEST_SENTENCES, convert_to_numpy=True, batch_size=10)
    batch_time = time.time() - start
    
    throughput = len(TEST_SENTENCES) / batch_time
    
    result = {
        "model": model_name,
        "dimensions": dims,
        "max_tokens": max_tokens,
        "load_time_sec": round(load_time, 2),
        "single_embed_ms": round(single_time * 1000, 2),
        "batch_10_embed_ms": round(batch_time * 1000, 2),
        "throughput_per_sec": round(throughput, 1),
        "timestamp": datetime.now().isoformat()
    }
    
    print(f"  Dimensions: {dims}")
    print(f"  Load time: {load_time:.2f}s")
    print(f"  Single embed: {single_time*1000:.1f}ms")
    print(f"  Throughput: {throughput:.1f} embeddings/sec")
    
    return result

def main():
    models = sys.argv[1:] if len(sys.argv) > 1 else ["all-MiniLM-L6-v2"]
    results = []
    
    for model_name in models:
        try:
            result = benchmark_model(model_name)
            results.append(result)
        except Exception as e:
            print(f"  ERROR: {e}")
    
    # Save results
    output_file = f"benchmark_result_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2)
    print(f"\nResults saved to: {output_file}")
    
    return results

if __name__ == "__main__":
    main()
