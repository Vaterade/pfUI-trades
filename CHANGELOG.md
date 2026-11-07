# Changelog

Each release gets a section here, newest first. The release workflow copies the section for
the version in `pfUI-tradeskill.toc` into the GitHub release notes, so write it for players.

Versions follow [semantic versioning](https://semver.org/): a fix raises the last number, a
new feature the middle one. While the first number is 0 the addon isn't considered stable yet.

## [Unreleased]

### Added
- **Missing**, next to **Queue**, opens a panel listing the recipes of the open profession you
  haven't learned (in place of the task list, which **Queue** brings back), with their skill level, how they're learned or where their recipe comes from,
  and their reagents. Tick **Learnable now** to narrow it to what your rank allows.
- With pfQuest loaded, a missing recipe's item names who sells or drops it and where, and a click
  shows them on the map.
- Other addons can queue crafts for any character on the realm (Altoholic's Recipes page does).

### Changed
- Renamed from pfUI-trades to pfUI-tradeskill. Rename `pfUI-trades.lua` to `pfUI-tradeskill.lua` in
  your `WTF` saved variables to keep your task lists.

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

[0.1.0]: https://github.com/Vaterade/pfUI-tradeskill/releases/tag/v0.1.0
