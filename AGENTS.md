# Agent Guidelines

- Trailer for commit messages:
  - Assisted-by: GitHub Copilot
  - Assisted-by: OpenAI GPT-5-Codex
- When making changes to Ruby files, run `bundle exec rubocop` before committing.
- Review additional project practices in `DEVELOPMENT.md`.
- `bundle exec rake` (full Rails test suite) takes a long time; prefer running the smallest relevant spec(s). If you truly need the full suite, use the parallel workflow from `DEVELOPMENT.md` (`bundle exec rake parallel:create parallel:prepare parallel:spec`).
