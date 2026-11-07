## Model rates — the cost card

**As of 2026-10-18** (Anthropic; OpenAI rows last verified 2026-09-29). Prices move; re-verify every week or two and bump the date. A cost figure is only
auditable against the card version that produced it, so quote this date alongside any number.

**On-demand — never `@import` this file.** `agent-dispatch.md` is Tier-0 and picks the *tier*; this file
prices it. A price table loaded in every session costs tokens in every conversation that never mentions
money.

This card is **published third-party pricing**, not personal, so it ships to every consumer beside the
tier table that consumes it. Any cost tool may price delivered work from it, but nothing here depends
on one being present — this file stands alone.

### Anthropic (Claude)

| Model | Input $/MTok | Output $/MTok |
|---|---:|---:|
| Claude Opus 5.5 (`claude-opus-5-5`) | 4.00 | 20.00 |
| Claude Sonnet 5.5 (`claude-sonnet-5-5`) | 2.00 | 10.00 |
| Claude Haiku 5.5 (`claude-haiku-5-5`) — prompt ≤ 100K | 0.10 | 0.50 |
| Claude Haiku 5.5 (`claude-haiku-5-5`) — prompt > 100K | 0.50 | 2.50 |
| Claude Haiku 4.5 (`claude-haiku-4-5`) | 1.00 | 5.00 |
| Claude Fable 5.1 (`claude-fable-5-1`) | 10.00 | 50.00 |
| Claude Opus 5 (`claude-opus-5`) — legacy | 5.00 | 25.00 |
| Claude Fable 5 (`claude-fable-5`) — legacy | 10.00 | 50.00 |
| Claude Sonnet 5 (`claude-sonnet-5`) — legacy | 2.00 | 10.00 |

Fast mode: Opus 5.5 bills at 8.00 / 40.00, Opus 5 at 10.00 / 50.00 — select from `usage.speed == "fast"`,
not from settings.

No long-context premium on Claude 4.6+ except **Haiku 5.5**: a prompt over 100K tokens (input + cache
writes + cache reads) bills the whole call at its second row, cache tiers included. Session logs are
summed per model, so pick the tier from the row's mean prompt per call and say so; one call apiece is
exact. Everything else bills the full 1M window flat (contrast OpenAI's 272K cliff below).

Batch (50% off) and Priority Tier don't apply to an interactive agent — Priority Tier is closed to new
purchase and excludes Opus 5.5, Opus 5, Sonnet 5, and Fable 5.1 entirely (Sonnet 5.5 unconfirmed).

### OpenAI (Codex)

| Model | Input $/MTok | Cached input | Output $/MTok |
|---|---:|---:|---:|
| `gpt-6-astra` | 10.00 | 1.00 | 50.00 |
| `gpt-6-sol` | 2.00 | 0.20 | 10.00 |
| `gpt-6-luna` | 0.10 | 0.01 | 0.50 |
| `gpt-5.6-sol` | 4.00 | 0.40 | 20.00 |
| `gpt-5.6-terra` | 2.00 | 0.20 | 12.00 |
| `gpt-5.6-luna` | 0.20 | 0.02 | 1.20 |
| `gpt-5.5` — retires 2026-10-14 | 5.00 | 0.50 | 30.00 |
| `gpt-5.4` | 2.50 | 0.25 | 15.00 |
| `gpt-5.4-mini` | 0.75 | 0.075 | 4.50 |

`gpt-5.2` and `gpt-5.3-codex` are already deprecated under ChatGPT sign-in — no current rate.

⚠ **Tier remap trap.** GPT-6 renamed the tiers; it did not shift 1:1 onto the old names. In
`agent-dispatch.md`'s Step 2 tier table: architectural/opus row → `gpt-6-astra`; sonnet rows →
`gpt-6-sol`; haiku rows → `gpt-6-luna`. A naive `gpt-5.6-sol`→`gpt-6-sol` rename silently demotes the
flagship row to mid-tier.

⚠ **272K long-context cliff** — above 272,000 input tokens a request bills at **2× input / 1.5× output**.
Kit-sized sessions re-read hundreds of thousands of cached tokens per turn, so a Codex peer on a full
context sits past this routinely. Check the input size before assuming the base rate.

⚠ Codex's flagship still costs **more** on output: `gpt-6-astra` 50.00 vs Opus 5.5 20.00. Mid-tier is
parity: `gpt-6-sol` 10.00 vs Sonnet 5.5 10.00. Dispatching to Codex is a diversity or throughput decision,
not a guaranteed saving.

### Cache multipliers

Read — varies by Anthropic model; flat on OpenAI:

| Provider | Model(s) | Cache read |
|---|---|---:|
| Anthropic | Sonnet 5, Haiku 5.5, Haiku 4.5, Opus 5, Fable 5 | 0.1× |
| Anthropic | Opus 5.5, Sonnet 5.5 | 0.05× |
| Anthropic | Fable 5.1 | 0.025× |
| OpenAI | all Codex models | 0.1× |

Write — Anthropic only; OpenAI has none:

| TTL | Multiplier |
|---|---:|
| 5-minute | 1.25× |
| 1-hour | 2.0× |

⚠ Cache read is **not** a universal 0.1× — that's Anthropic's default tier only. Take the read multiplier
from the table per model, not as a constant.

⚠ **Write premiums are Anthropic-only.** OpenAI cache writes bill at the plain input rate — only the read
side is discounted.

Anthropic reports the TTL split under `usage.cache_creation` (`ephemeral_5m_input_tokens` /
`ephemeral_1h_input_tokens`) — price them separately; assuming one TTL misprices by up to 60%.

**TTL is not a flat 1h, even on Claude.** Main conversation: 1h on a Claude subscription within plan
usage, 5m on API key / usage credits / cloud providers. **Subagents, workflows, forks, and compaction
cache at 5m by default**, regardless of billing — this kit's loop is subagent-heavy, so most of its
traffic is 5m, not 1h. Configurable via `promptCacheTtl` / `CLAUDE_CODE_PROMPT_CACHE_TTL` (main
conversation) and `subagentPromptCacheTtl` / `CLAUDE_CODE_SUBAGENT_PROMPT_CACHE_TTL` (everything else),
Claude Code ≥ v2.1.242; `ENABLE_PROMPT_CACHING_1H=1` makes 1h the default but ranks below the per-bucket
settings above, which still override it — only `FORCE_PROMPT_CACHING_5M=1` truly forces a TTL, winning
over everything else. A hit refreshes the TTL free, measured from request start; on expiry the next
request rewrites the prefix at write price. Measured on this kit's own feature work: every subagent cache
write was 5m — the 16 apparent 1h writes inside fork transcripts are duplicated main-session records
(same `message.id` + `requestId`, 16 of 16), not a genuine fork write; every plain orchestrator write was
1h.

**OpenAI caching is automatic** (1,024-token minimum prefix, no opt-in). GPT-5.6+ retention is a fixed
**30-minute** TTL (`prompt_cache_options.ttl: "30m"`, no 24h option); GPT-5.5 and earlier offer
`in_memory` (~5–10 min, up to 1h) or `24h`, both at the same price.

### GitHub Copilot and Cursor

Neither publishes its own token prices — both re-bill the underlying model's rate from the tables above.

**Copilot** has been token-metered since **2026-06-01** ("GitHub AI Credits," 1 credit = $0.01): input,
output, and cache tokens all billed at the model's published rate, no markup; overage at the same rates.
Plans: Pro $10→$15/mo, Pro+ $39→$70/mo, Max $100→$200/mo, Business $19/seat/mo (1,900 credits included),
Enterprise $39/seat/mo (3,900 credits included). Legacy annual Pro/Pro+ holdouts are still request-counted
(300 / 1,500 premium requests, $0.04 overage, model multipliers) — that track has no token or cache
pricing at all.

**Cursor** bills Total Tokens (input + output + cache read + cache write) × the model's API rate.
Individual plans pool a monthly budget for third-party models — Pro $20, Pro+ $70, Ultra $400 — then meter
on-demand at the same rates past it. Teams/Enterprise add a flat **+$0.25/MTok** Cursor Token Rate on
every third-party token, including BYOK.

Both fit the `Computing a cost` formula below; the plan pool is a prepaid layer on top — zero marginal
cost to the user until it's exhausted, not a separate rate.

⚠ Neither publishes which cache TTL it bills, only a single write rate — the 5-minute-equivalent (1.25×,
above). Treat that as a modelling assumption, not a confirmed TTL.

### Computing a cost

```
cost = input×R + cache_w5m×R×1.25 + cache_w1h×R×2.0 + cache_read×R×M_read + output×R_out
```

`M_read` is the model's cache-read multiplier (table above). The two write terms are Anthropic-only —
zero them for OpenAI, which bills cache writes at the plain input rate `R`.

There is **no cost field in the session logs** — `~/.claude/projects/*.jsonl` carries token counts only.
Dollars are always computed from this card.

### Effort → cost (measured, not assumed)

Anthropic shares these effort sweeps as **internal, directional** figures, not a formal spec — treat them
as estimates. The multiplier is **workload- and model-dependent** — use the row that matches the task,
relative to `high`:

| Workload (model, benchmark) | `low` | `medium` | `high` | `xhigh` |
|---|---:|---:|---:|---:|
| **Long-horizon coding** ← the kit's case (Opus 5.5, SWE-bench Pro) | 0.33× (−8 pts) | 0.70× (−2.5 pts) | 1.00× | 2.5× (+1.4 pts) |
| Research / knowledge work (Fable 5, 4 benchmarks) | 0.50–0.67× (−1..3 pts) | 0.70–0.87× (no measurable loss) | 1.00× | — |

The `medium` figure for research/knowledge work is corroborated by Anthropic's own effort guidance:
`platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence`.

**Claude Code's default effort is model-dependent, not a flat `xhigh`**
(`code.claude.com/docs/en/model-config`): `high` on most models, `medium` on Opus 5.5, `xhigh` only on
Opus 4.7. A corpus of real sessions is a *mix* of these, not a clean `xhigh` (or `high`) baseline — anchor
the model before comparing.

**Cheap-first with re-run on failure** is the strongest lever here, and it needs a failure signal the
kit already has (the per-phase review gate + tests, mandatory in
`.agent-kit/common/process/planning/execution-loop.md`). Measured on Opus 5.5 coding tasks: everything at
`low` with failures re-run at `high` reached **~97% pass for ~$0.17/task**, against **95.3% for ~$0.29**
running everything at `high` — a higher pass rate for less money, *including* the wasted cheap attempts.
Starting at `medium`: ~97% for ~$0.24. Price in the doubled wall-clock on failures. Source:
`platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence` (fetched
2026-09-24).

### Where the money actually goes

On a measured month of real agent work: **cache traffic was 92% of the bill** (read 60.6%, write 31.6%),
output 7.3%, raw input ~0%. Cost tracks *context volume × turns*, not code produced — an estimate built
on lines written measures the 7% and misses the 92%. Caching is not the waste: those reads would bill
~10× uncached. It is simply where cost lives.

**Orchestrator economics, Opus 5.5 vs Opus 5** (projection from one measured feature, not the month
above): Opus 5.5 reads cache at half Opus 5's multiplier (0.05× vs 0.1×) at a lower base price too. That
feature's deduplicated orchestrator traffic — 1h-write 361,156, read 52,516,248, output 163,347 tokens —
priced out to **~$17** at Opus 5.5 against **~$34** at Opus 5.
