## Technical terminology in another language

The kit's docs are English; a project's commits, plans, module memory and replies may not be. When
writing in another language, **never translate a term that is English at its root** — `thread`,
`managed executor`, `axis`, `heap`, `commit`, `deploy`, `outbox` stay as they are.

A translated term stops matching the code, the framework's own docs, and everything the reader will
search for — and it frequently stops being recognizable prose at all ("executores gerenciados" for
*managed executor*). ⚠ The test is **origin, not familiarity**: if the concept arrived in the language
as an English term, keep the English. Translate the sentence around it, never the term.
