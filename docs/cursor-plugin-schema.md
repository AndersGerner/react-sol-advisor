# Cursor plugin schema evidence

The Cursor adapter targets the current official plugin manifest shape and the current
agent frontmatter documented by Cursor. The repository does not vendor or execute a
Cursor runtime; CI validates the deterministic local subset and records the inspected
upstream source here.

- Official plugin repository: https://github.com/cursor/plugins
- Inspected upstream commit: `2a8044425c7bddf429c3bdedf3ab61e791d34d65`
- Manifest schema: `schemas/plugin.schema.json`
- Inspected manifest schema SHA-256: `a393b758901803fcf5cfe0d77bda8a83e987d32c3377dfce2d9edf445af884ed`
- Marketplace schema: `schemas/marketplace.schema.json`
- Inspected marketplace schema SHA-256: `1aae96a24c2796419933bc8bfe3a1255394e7199c35740b36325e0ce6dbc253d`
- Official plugin documentation: https://cursor.com/docs/plugins
- Official subagent documentation: https://cursor.com/docs/subagents

The package uses `.cursor-plugin/plugin.json`, `skills/`, `agents/`, `commands/`, and
`rules/`. Bundled agents use `model: inherit`; the setup flow writes exact IDs returned
by the user's current model picker/catalog and records requested and independently
observed model values separately. The local `cursor-agent --list-models` catalog was
used only to seed acceptance fixtures (`composer-2.5`, `gpt-5.6-luna-max`, and
`cursor-grok-4.5-high`); those IDs are never bundled as defaults.
