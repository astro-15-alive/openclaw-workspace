# Model Router Skill

Routes tasks to the most appropriate model based on complexity and requirements.

## Usage

```bash
# Route a task automatically
model-router "Your task description here"

# Route with explicit preference
model-router --fast "Simple task"
model-router --smart "Complex reasoning task"
```

## Routing Logic

- **gemma-fast** (8k context): Simple tasks, quick lookups, formatting, data extraction
- **gemma** (12k context): Medium complexity, general conversation, coding
- **kimi/qwen** (primary): Complex reasoning, multi-step tasks, large context needs

## Examples

```bash
# Will route to gemma-fast
model-router "List all files in /tmp"

# Will route to kimi
model-router "Analyze this 5000-word document and summarize key insights"
```
