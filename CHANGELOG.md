# Changelog

Each release gets a section here, newest first. The release workflow copies the section for
the version in `pfUI-trades.toc` into the GitHub release notes, so write it for players.

Versions follow [semantic versioning](https://semver.org/): a fix raises the last number, a
new feature the middle one. While the first number is 0 the addon isn't considered stable yet.

## [0.1.0] - 2026-11-05

The first release.

### Added
- A task list beside the profession windows. **Queue** at the bottom left of the recipe
  details opens it; **Add** puts the selected recipe on it with the window's quantity.
- **Start** crafts the first task that has its materials, one batch per press, and **Stop**
  halts it. In Enchanting the button is **Next** and casts one at a time.
- A materials table showing what the tasks still need against your bags, bank, mail and
  alts (mail and alts from Altoholic, if it's installed).
- A bank reminder listing materials to take out for your tasks.
- An alt reminder at the bank and mailbox listing materials to send to your other characters.

[0.1.0]: https://github.com/Vaterade/pfUI-trades/releases/tag/v0.1.0
