#!/bin/bash
# Extract personality observations from daily notes
# Usage: bash observe.sh [--days 7] [--dry-run]

set -e

WORKSPACE="/root/.openclaw/workspace"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DAYS="${1:-7}"
DRY_RUN="${2}"

echo "=== Personality Observation Engine ==="
echo "Scanning last ${DAYS} days of daily notes..."

python3 - "${WORKSPACE}" "${SKILL_DIR}" "${DAYS}" "${DRY_RUN}" << 'PYEOF'
import json, os, glob, sys, re
from datetime import datetime, timedelta

workspace = sys.argv[1]
skill_dir = sys.argv[2]
days = int(sys.argv[3])
dry_run = sys.argv[4] if len(sys.argv) > 4 else None

daily_dir = f"{workspace}/memory"
personality_file = f"{skill_dir}/PERSONALITY.md"

# Read existing personality model
with open(personality_file, "r") as f:
    existing = f.read()

# Observation patterns — things that reveal personality
OBSERVATION_PATTERNS = {
    "communication_style": [
        (r'\b(no|don\'t|stop|quit)\s+(?:the|with the)\s+(?:long|verbose|wordy|fluff)', 'dislikes verbosity'),
        (r'\b(keep it|make it|be)\s+(?:short|concise|brief|tight)', 'prefers conciseness'),
        (r'\b(just|get to)\s+(?:the point|it)', 'wants directness'),
        (r'\b(don\'t|do not)\s+(?:over.?explain|elaborate)', 'dislikes over-explanation'),
        (r'\b(perfect|great|exactly|that\'s it)\s*[!！]', 'values precision'),
    ],
    "decision_making": [
        (r'\b(let\'s|i\'ll|we should)\s+(?:try|test|experiment|ship|deploy)', 'action-oriented'),
        (r'\b(don\'t overthink|just do it|ship it|move fast)', 'bias toward action'),
        (r'\b(we can always|can revert|is reversible|undo)', 'reversibility-aware'),
        (r'\b(plan out|think through|analyze|consider all)', 'analytical when needed'),
    ],
    "values": [
        (r'\b(local|self.?hosted|no cloud|no API key|no external)', 'values privacy/local-first'),
        (r'\b(no fluff|no bs|no nonsense|pragmatic)', 'values pragmatism'),
        (r'\b(elegant|clean|simple|minimal)', 'values simplicity'),
        (r'\b(secure|privacy|private|encrypt)', 'values security'),
        (r'\b(free.?and.?open|FOSS|open source)', 'values open source'),
    ],
    "frustrations": [
        (r'\b(annoying|frustrat|irritat|tired of|sick of)', 'frustration signal'),
        (r'\b(why does|this shouldn\'t|this is broken)', 'frustration with tools'),
        (r'\b(takes too long|too slow|waste of time)', 'impatient with inefficiency'),
        (r'\b(API key|paywall|vendor lock)', 'dislikes external dependencies'),
    ],
    "interests": [
        (r'\b(TypeScript|Node\.js|npm|package)', 'interested in TypeScript/Node'),
        (r'\b(Docker|container|Kubernetes|deploy)', 'interested in infrastructure'),
        (r'\b(API|webhook|endpoint|REST|GraphQL)', 'interested in APIs'),
        (r'\b(automation|cron|scheduled|script)', 'interested in automation'),
        (r'\b(database|SQL|Mongo|Postgres|Meili|Lance)', 'interested in databases'),
    ],
    "emotional_state": [
        (r'\b(excited|pumped|love this|this is great)', 'positive/enthusiastic'),
        (r'\b(confused|unsure|not sure|what do you think)', 'uncertain/seekinng input'),
        (r'\b(busy|tired|late night|early morning)', 'energy level signal'),
    ]
}

cutoff = datetime.now() - timedelta(days=days)
observations = []
files_scanned = 0

for fname in sorted(glob.glob(f"{daily_dir}/*.md")):
    try:
        file_date = datetime.strptime(os.path.basename(fname)[:10], "%Y-%m-%d")
    except:
        continue
    if file_date < cutoff:
        continue

    with open(fname, "r") as f:
        content = f.read()
    if len(content) < 50:
        continue

    files_scanned += 1

    # Scan user messages only (what Eric actually said)
    in_user = False
    for line in content.split("\n"):
        line = line.strip()
        if line.startswith("user:") or line.startswith("> "):
            in_user = True
            msg = line.split(":", 1)[-1].strip() if ":" in line else line[2:].strip()
        elif line.startswith("assistant:") or line.startswith("⚔️"):
            in_user = False
            continue
        else:
            if in_user:
                msg = line
            else:
                continue

        if not msg or len(msg) < 10:
            continue

        for category, patterns in OBSERVATION_PATTERNS.items():
            for pattern, observation in patterns:
                if re.search(pattern, msg, re.IGNORECASE):
                    # Avoid duplicates
                    key = f"{category}:{observation}"
                    if key not in [o["key"] for o in observations]:
                        observations.append({
                            "key": key,
                            "category": category,
                            "observation": observation,
                            "evidence": msg[:100],
                            "source": os.path.basename(fname),
                            "date": file_date.strftime("%Y-%m-%d")
                        })

print(f"Files scanned: {files_scanned}")
print(f"New observations: {len(observations)}")

if observations:
    print("\nObservations found:")
    for o in observations:
        print(f"  [{o['category']}] {o['observation']}")
        print(f"    Evidence: \"{o['evidence'][:80]}\"")

if dry_run:
    print("\n[DRY RUN] — no changes written")
else:
    # Append observations to a log file
    obs_log = f"{skill_dir}/observations.json"
    existing_obs = []
    if os.path.exists(obs_log):
        with open(obs_log, "r") as f:
            try:
                existing_obs = json.load(f)
            except:
                pass

    # Merge, avoiding duplicates by key
    existing_keys = {o["key"] for o in existing_obs}
    new_obs = [o for o in observations if o["key"] not in existing_keys]
    all_obs = existing_obs + new_obs

    with open(obs_log, "w") as f:
        json.dump(all_obs, f, indent=2)

    print(f"\nLogged {len(new_obs)} new observations to observations.json")

    # Auto-update PERSONALITY.md with high-confidence observations
    # (those that appear 3+ times in the log)
    from collections import Counter
    obs_counts = Counter(o["observation"] for o in all_obs)
    recurring = {obs for obs, count in obs_counts.items() if count >= 2}

    if recurring:
        print(f"\nRecurring patterns ({len(recurring)}) — should update PERSONALITY.md:")
        for r in recurring:
            print(f"  - {r} (seen {obs_counts[r]}x)")
PYEOF

echo "=== Done ==="
