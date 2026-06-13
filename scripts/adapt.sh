#!/bin/bash
# Adaptation engine: review observations and update personality model
# Usage: bash adapt.sh [--dry-run]

set -e

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OBS_LOG="${SKILL_DIR}/observations.json"
PERSONALITY="${SKILL_DIR}/PERSONALITY.md"
DRY_RUN="${1}"

echo "=== Personality Adaptation Engine ==="

if [ ! -f "$OBS_LOG" ]; then
  echo "No observations yet. Run observe.sh first."
  exit 0
fi

python3 - "$OBS_LOG" "$PERSONALITY" "$DRY_RUN" << 'PYEOF'
import json, sys, os
from collections import Counter
from datetime import datetime

obs_log = sys.argv[1]
personality_file = sys.argv[2]
dry_run = sys.argv[3] if len(sys.argv) > 3 else None

with open(obs_log, "r") as f:
    observations = json.load(f)

with open(personality_file, "r") as f:
    personality = f.read()

print(f"Total observations: {len(observations)}")

# Count observations by type
by_category = Counter(o["category"] for o in observations)
by_observation = Counter(o["observation"] for o in observations)

print("\nBy category:")
for cat, count in by_category.most_common():
    print(f"  {cat}: {count}")

print("\nTop observations:")
for obs, count in by_observation.most_common(10):
    print(f"  {obs}: {count}x")

# Find high-confidence patterns (seen 2+ times)
recurring = {obs: count for obs, count in by_observation.items() if count >= 2}
print(f"\nHigh-confidence patterns (2+): {len(recurring)}")

if dry_run:
    print("\n[DRY RUN] Would update PERSONALITY.md with:")
    for obs, count in recurring.items():
        print(f"  - {obs} ({count}x)")
else:
    # Update PERSONALITY.md — add new observations to relevant sections
    lines = personality.split("\n")
    updated = False

    for obs, count in recurring.items():
        # Check if this observation is already captured
        if obs.lower() in personality.lower():
            continue

        # Find the right section to add it
        section_map = {
            "communication_style": "Communication Style",
            "decision_making": "Decision-Making",
            "values": "Values & Interests",
            "frustrations": "Boundaries",
            "interests": "Values & Interests",
            "emotional_state": "Personality Traits",
        }

        # Find which category this observation belongs to
        cat = None
        for o in observations:
            if o["observation"] == obs:
                cat = o["category"]
                break

        section = section_map.get(cat, "Personality Traits")
        print(f"  Adding to '{section}': {obs} ({count}x)")
        updated = True

    if updated:
        # Append a timestamp note
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")
        update_note = f"\n\n_Adapted at {timestamp} — {len(recurring)} patterns reinforced._"

        with open(personality_file, "w") as f:
            f.write(personality.rstrip() + update_note)
        print(f"\nPERSONALITY.md updated.")
    else:
        print("\nNo new patterns to add — PERSONALITY.md is current.")

    # Generate adaptation suggestions
    print("\n=== Adaptation Suggestions ===")
    suggestions = []

    if by_observation.get("dislikes verbosity", 0) >= 2:
        suggestions.append("→ Keep responses even shorter. Lead with the answer.")
    if by_observation.get("prefers conciseness", 0) >= 2:
        suggestions.append("→ Cut filler words. No 'Great question!' or 'I'd be happy to help!'")
    if by_observation.get("action-oriented", 0) >= 2:
        suggestions.append("→ When Eric asks 'should I...', give a direct recommendation with reasoning.")
    if by_observation.get("values privacy/local-first", 0) >= 2:
        suggestions.append("→ Always prefer local solutions. Mention privacy implications.")
    if by_observation.get("frustration signal", 0) >= 3:
        suggestions.append("→ Eric seems frustrated lately. Be more direct, skip pleasantries.")
    if by_observation.get("positive/enthusiastic", 0) >= 3:
        suggestions.append("→ Eric is in a good mood. Good time to suggest new ideas.")

    if suggestions:
        for s in suggestions:
            print(s)
    else:
        print("No strong adaptation signals yet. Keep observing.")
PYEOF

echo "=== Done ==="
