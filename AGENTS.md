# Agent Guidelines

- Add an `Assisted-by:` trailer to commit messages that identifies the assistant and model actually used for the change; do not copy a hard-coded identity.
- When making changes to Ruby files, run `bundle exec rubocop` before committing.
- Review additional project practices in `DEVELOPMENT.md`.
- `bundle exec rake` (full Rails test suite) takes a long time; prefer running the smallest relevant spec(s). If you truly need the full suite, use the parallel workflow from `DEVELOPMENT.md` (`bundle exec rake parallel:create parallel:prepare parallel:spec`).
