# Idea: <name>

Status: Incubating | Survived | Promoted | Killed | Postponed
Register: Talk | Shape | Forge
Scope: companion (`<existing-project>`) | new project
Last updated: YYYY-MM-DD

---

## The idea, in one sentence

What it is. If it takes more than a sentence, it isn't clear yet.

## Who + the loop

Who opens this, and the one moment it exists for. The posture — where they are, what's
in their hands — is usually the whole product.

---

## The gauntlet

> The kill zone. Fill **only the dimensions the conversation actually raised** — delete the rest,
> the way the feature template deletes untouched test tiers. A blank heading left in is a question
> you dodged. Mark any unanswered blocker with `[OPEN: …]` — the idea cannot reach **Survived** while
> one remains.
>
> These are *what* to evaluate. The reasoning lenses that *stress* a soft answer (inversion,
> constraint-removal, red-team) live in the `/brainstorm` skill, not here — they leave their mark as
> a sharpened answer, not a new heading.

### Market — is the demand real?

- **Audience & niche** — who, how many, how narrow
- **Room & competitors** — does space exist; who already occupies it
- **Moat** — what *this* has that they don't
- **Monetization** — how it makes money, or explicitly "not yet" / "never"
- **Legality & risk** — the kill-box: rights, law, liability. If the risk is real, is it worth it?

### Reach & timing — can it be found, and why now?

- **Distribution** — how a stranger discovers this exists. No channel = dead, however good.
- **Why now** — what makes this winnable now that wasn't true two years ago (behavior, tech, law)

### Fit for you — should *you* build it, now?

- **Opportunity cost** — is this a better use of attention than finishing what's already started?
  Every new project competes with the unfinished ones, not with nothing.

### Survival — is it still alive in six months?

- **Durability** — who opens it *twice* (retention); what third party can switch it off
  (platform dependency); what forever-cost it adds (upkeep, licensing, moderation)

---

## Pre-mortem

> Required for **Forge**. The synthesis where the dimensions collide.

It's six months later and this has 12 users. Why? Two or three sentences, worked backward from
the failure. This is where a soft answer above turns into an `[OPEN]` — or a kill.

---

## If it survives

> Do not write a word of this until the gauntlet is passed. Writing it early is how a dead idea
> dresses itself up as a live one.

### Smallest proof (V1)

The one thing it must do. If *this* isn't useful alone, nothing added later rescues it.

### Not this

Merges and features someone will later propose, pre-rejected — one line of rationale each.

### Shape when it lands

Companion (shares which project's backend / auth / catalog) or new project. Stack, chosen from the
kit's covered stacks. This is the cheapest question on the page — hence last.

### Open calls for `/feature-plan`

The load-bearing design decisions the plan must resolve *first* — name them, don't resolve
them. **No schema, no slices, no test plan here**: if you're writing those, stop — that's the
feature plan's job, and a copy here only rots. Omit this heading entirely for a trivial fork
with no real open decisions. Each call: one line, why it's load-bearing, and (if apt) "investigate first."

---

## Outcome

> Filled when the idea leaves `ideas/`. One line.

- **Promoted** → `features/<slug>.md` in `<project>` (or new repo `<name>`, scaffolded via `install.sh`)
- **Killed** → moved to `archive/`; the one-line "why" stays in the header
- **Postponed** → moved to `parked/`; resume trigger noted
