# Skill Telemetry Analysis

Bash scripts for analyzing skill usage telemetry from `~/.ada/skill-events.jsonl`.

## Scripts

| Script | Purpose |
|--------|---------|
| `analyze-skill-usage.sh` | Core usage stats: counts, percentages, load vs script ratio |
| `analyze-sessions.sh` | Session depth, entry points, multi-skill patterns |
| `analyze-cooccurrence.sh` | Skill pairs, sequences, what skills predict others |
| `analyze-trends.sh` | Daily/weekly patterns, adoption timeline, recent vs historical |
| `analyze-versions.sh` | Version distribution, upgrade tracking, missing versions |
| `analyze-repos.sh` | Repository usage, skill preferences, cross-repo patterns |
| `analyze-retention.sh` | Skill reach, stickiness, return rates |
| `analyze-all.sh` | Run all scripts, optional `--json` output |

## Usage

```bash
# Analyze default telemetry file
.test/analysis/analyze-skill-usage.sh

# Analyze specific file
.test/analysis/analyze-sessions.sh ~/.ada/skill-events.jsonl

# Full report
.test/analysis/analyze-all.sh

# JSON output for programmatic use
.test/analysis/analyze-all.sh --json
```

## Requirements

- `jq` (JSON processor)
- `bash` 4.0+
- Standard POSIX utilities (`awk`, `sort`, `uniq`, `grep`)

## Metrics Explained

### Usage Metrics
- **Total events**: All telemetry events logged
- **Unique skills**: Number of distinct skills used
- **Load vs script ratio**: How often skills execute scripts after loading

### Session Metrics
- **Session depth**: Unique skills per session
- **Entry points**: First skill loaded in each session
- **Multi-skill rate**: Sessions using 2+ skills

### Co-occurrence Metrics
- **Skill pairs**: Skills used together in same session
- **Sequences**: Common skill orderings (A → B)

### Retention Metrics
- **Skill reach**: Sessions using each skill (breadth)
- **Skill depth**: Avg uses per session when used (intensity)
- **Stickiness**: Days active / total days (consistency)

## Test Fixtures

Test data in `fixtures/`:
- `sample-telemetry.jsonl` - 50 events across 15 sessions, 4 repos
- `minimal-telemetry.jsonl` - Single event for edge case testing
- `version-tracking.jsonl` - Version upgrade scenarios
- `cooccurrence-test.jsonl` - Known co-occurrence patterns

## Running Tests

```bash
bash .test/tests/test-analysis.sh
```
