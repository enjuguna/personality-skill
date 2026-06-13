# Personality Skill

Learns who you are over time, like a human friend would. Observes patterns in how you communicate, make decisions, and what you value — then adapts behavior accordingly.

## How It Works

1. **Observe** — Scans daily notes for personality signals after each conversation
2. **Model** — Builds a structured personality profile in `PERSONALITY.md`
3. **Adapt** — Changes behavior based on learned patterns
4. **Distill** — Reinforces high-confidence patterns weekly

## What It Observes

| Category | Examples |
|----------|----------|
| Communication style | Brevity preference, directness, tone |
| Decision-making | Action-oriented vs analytical, risk tolerance |
| Values | Privacy, simplicity, open source, pragmatism |
| Frustrations | Verbosity, external dependencies, inefficiency |
| Interests | Technologies, topics, project types |
| Emotional state | Energy level, enthusiasm, uncertainty |

## Files

- `PERSONALITY.md` — Living personality model (auto-updated)
- `observations.json` — Raw observation log
- `scripts/observe.sh` — Extract signals from daily notes
- `scripts/adapt.sh` — Review observations, update model

## Install

```bash
git clone https://github.com/enjuguna/personality-skill.git
cp -r personality-skill ~/.openclaw/workspace/skills/personality
```

Or from ClawHub:

```bash
openclaw skills install personality
```

## Cron Jobs

```
# Daily at 11 PM: observe
0 23 * * * cd ~/.openclaw/workspace/skills/personality && bash scripts/observe.sh >> /tmp/personality-observe.log 2>&1

# Weekly Sunday 3 AM: adapt
0 3 * * 0 cd ~/.openclaw/workspace/skills/personality && bash scripts/adapt.sh >> /tmp/personality-adapt.log 2>&1
```

## License

MIT
