#!/bin/bash
# Test real agent with Tavily search and deep reasoning

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPTS_DIR="${SCRIPT_DIR}/skills/agent-orchestration/scripts"

echo "=========================================="
echo "Real Agent Test - Tavily Search + Deep Reasoning"
echo "=========================================="
echo ""

# Test: Spawn a research agent with explicit instructions to use Tavily
echo "Spawning research agent with Tavily search instructions..."
echo ""

PROMPT="Research and provide a comprehensive answer about information retrieval systems. 

Your task:
1. Use Tavily search tools (tavily_search, tavily_extract) to gather current information about information retrieval systems
2. Search for: best practices, key concepts, modern approaches, and real-world applications
3. Use deep reasoning to analyze and synthesize the information
4. Write a comprehensive, well-structured answer covering:
   - What information retrieval systems are
   - Key components and architectures
   - Best practices and modern approaches
   - Real-world applications and use cases
   - Important considerations and trade-offs

Use tavily_search with search_depth: 'advanced' and max_results: 10-15 to get thorough results.
Extract full content from the most relevant URLs using tavily_extract with extract_depth: 'advanced'.
Apply deep reasoning to synthesize the information into a coherent, insightful answer.

Write your final answer to answer.md in the root of this directory."

RUN_ID=$("${AGENT_SCRIPTS_DIR}/agent-spawn.sh" \
  --provider cursor \
  --mode research \
  --runtime await \
  --prompt "$PROMPT" \
  --model auto)

echo "✓ Agent spawned with runId: $RUN_ID"
echo ""

# Wait for agent to complete
echo "Waiting for agent to complete (this may take 2-5 minutes for thorough research)..."
echo "Monitoring progress..."
echo ""

TIMEOUT=300  # 5 minutes
START_TIME=$(date +%s)
LAST_SIZE=0

while true; do
  # Check if process is still running
  if [ -f ".ada/data/agents/runs/${RUN_ID}/meta.json" ]; then
    STATUS=$(grep -o '"status":"[^"]*"' ".ada/data/agents/runs/${RUN_ID}/meta.json" 2>/dev/null | sed 's/"status":"\([^"]*\)"/\1/' || echo "running")
    
    # Check out.ndjson for progress
    if [ -f ".ada/data/agents/runs/${RUN_ID}/out.ndjson" ]; then
      CURRENT_SIZE=$(wc -c < ".ada/data/agents/runs/${RUN_ID}/out.ndjson" 2>/dev/null || echo "0")
      if [ "$CURRENT_SIZE" -gt "$LAST_SIZE" ]; then
        echo "  [$(date +%H:%M:%S)] Agent is working... (output: ${CURRENT_SIZE} bytes)"
        LAST_SIZE=$CURRENT_SIZE
      fi
    fi
    
    if [ "$STATUS" = "completed" ] || [ "$STATUS" = "failed" ]; then
      echo ""
      echo "✓ Agent completed with status: $STATUS"
      break
    fi
  fi
  
  # Check timeout
  CURRENT_TIME=$(date +%s)
  ELAPSED=$((CURRENT_TIME - START_TIME))
  if [ $ELAPSED -gt $TIMEOUT ]; then
    echo ""
    echo "⚠ Timeout after ${TIMEOUT} seconds"
    break
  fi
  
  sleep 5
done

echo ""
echo "=========================================="
echo "Collecting Results"
echo "=========================================="
echo ""

# Collect results
echo "Collecting results and analyzing patch..."
RESULT_JSON=$("${AGENT_SCRIPTS_DIR}/agent-collect.sh" "$RUN_ID" 2>&1)

# Check results
if [ ! -f ".ada/data/agents/runs/${RUN_ID}/result.json" ]; then
  echo "❌ ERROR: result.json not found"
  exit 1
fi

echo "✓ Results collected"
echo ""

# Display patch analysis
if command -v jq &> /dev/null; then
  echo "Patch Analysis:"
  jq -r '.patchAnalysis' ".ada/data/agents/runs/${RUN_ID}/result.json" | jq '.' | sed 's/^/  /'
  echo ""
  
  STATUS=$(jq -r '.status' ".ada/data/agents/runs/${RUN_ID}/result.json")
  echo "Status: $STATUS"
  echo ""
fi

# Check for answer.md
if [ -f ".ada/data/agents/runs/${RUN_ID}/answer.md" ]; then
  ANSWER_SIZE=$(wc -c < ".ada/data/agents/runs/${RUN_ID}/answer.md" 2>/dev/null || echo "0")
  echo "✓ answer.md found (${ANSWER_SIZE} bytes)"
  echo ""
  echo "Answer preview (first 500 characters):"
  echo "----------------------------------------"
  head -c 500 ".ada/data/agents/runs/${RUN_ID}/answer.md" | sed 's/$/.../'
  echo ""
  echo "----------------------------------------"
  echo ""
  
  if [ "$ANSWER_SIZE" -gt 500 ]; then
    echo "✓ Answer appears comprehensive (${ANSWER_SIZE} bytes)"
  else
    echo "⚠ WARNING: Answer is quite short (${ANSWER_SIZE} bytes)"
  fi
else
  echo "⚠ WARNING: answer.md not found in run directory"
  
  # Check worktree
  WORKTREE_PATH=$(grep -o '"worktreePath":"[^"]*"' ".ada/data/agents/runs/${RUN_ID}/meta.json" 2>/dev/null | sed 's/"worktreePath":"\([^"]*\)"/\1/' || echo "")
  if [ -n "$WORKTREE_PATH" ] && [ -f "${WORKTREE_PATH}/answer.md" ]; then
    echo "  (but answer.md exists in worktree: ${WORKTREE_PATH}/answer.md)"
    ANSWER_SIZE=$(wc -c < "${WORKTREE_PATH}/answer.md" 2>/dev/null || echo "0")
    echo "  Size: ${ANSWER_SIZE} bytes"
  fi
fi

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Run ID: $RUN_ID"
echo "Result JSON: .ada/data/agents/runs/${RUN_ID}/result.json"
echo "Answer: .ada/data/agents/runs/${RUN_ID}/answer.md"
echo "Patch: .ada/data/agents/runs/${RUN_ID}/patch.diff"
echo ""

# Show full result.json if jq available
if command -v jq &> /dev/null; then
  echo "Full Result JSON:"
  jq '.' ".ada/data/agents/runs/${RUN_ID}/result.json"
else
  echo "Result JSON:"
  cat ".ada/data/agents/runs/${RUN_ID}/result.json"
fi

echo ""
echo "=========================================="
echo "Test Complete"
echo "=========================================="

