# AGENTS.md

Repository guidance for contributors building the `solvera_ojt_core` module for Odoo 18.

## Purpose
- Primary goal: deliver a production-ready Odoo 18 module for managing on-the-job training (OJT) programs.
- Target edition: compatible with both Community and Enterprise variants.
- Keep the codebase installable as a standalone addon; avoid dependencies outside the official Odoo distribution unless documented in `README.md`.

## Environment expectations
- Odoo source checkout: `~/work/odoo`.
- Custom addons directory: `~/custom_addons`.
- Python environment: `~/.venvs/odoo18` (Python 3.10+).
- PostgreSQL 15 or newer with local socket authentication.
- Use `odoo-bin` commands with `--addons-path=~/work/odoo/addons,~/custom_addons`.

## Coding standards
- Follow Odoo 18 coding conventions and the official [Odoo Developer Guidelines](https://www.odoo.com/documentation/18.0/contributing/development/index.html).
- Python:
  - Use the Odoo ORM (models, fields, api decorators) instead of raw SQL when possible.
  - Prefer single quotes for strings unless double quotes improve readability.
  - Order imports: stdlib, third-party, Odoo, local; group with blank lines.
  - Add docstrings to public methods that expose business logic.
- XML/QWeb:
  - Keep XML nodes sorted by logical order (models, security, data, views).
  - Use `position` modifiers sparingly; prefer explicit inherits.
  - Wrap translatable strings in `<field name="name">_("Text")</field>` or `t-translate` attributes where appropriate.
- JavaScript/SCSS:
  - Place assets under `static/src/<type>` following Odoo asset conventions.
  - Use ES modules and OWL 2 patterns for client code.

## Data and security
- Define access control lists in `security/ir.model.access.csv` for each new model.
- Place record rules in `security/<module>_rules.xml` and namespace XML IDs with the module name.
- Do not include demo data in production data files; put example records in `demo/` and load them via the manifest flag.
- Ensure all CSV files are UTF-8 encoded with LF line endings.

## Tests
- Add or update tests in `tests/` when modifying business logic.
- Use Odoo's built-in testing framework (`odoo.tests.common`) and aim for deterministic tests.
- Run tests locally with:
  ```bash
  odoo-bin --test-tags=solvera_ojt_core --workers=0 --log-level=test --stop-after-init
  ```

## Documentation
- Update `README.md` whenever functional behavior or setup steps change.
- Document configuration parameters, scheduled actions, and user-visible workflows.

## Git & PR workflow
- Keep commits focused and include meaningful messages.
- Before opening a PR, ensure tests pass and linters (if any) are clean.
- Pull requests should summarize functional changes, database impacts, and manual testing performed.
