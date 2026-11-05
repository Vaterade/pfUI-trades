# pfUI-trades

An external module for [pfUI](https://github.com/brues-code/pfUI) that adds a task list and a
materials overview beside the game's own profession windows. It needs pfUI, and so ClassicAPI.
Altoholic is optional. Don't run it alongside AdvancedTradeSkillWindow2, which uses the same window.

## Installing

Download `pfUI-trades-vX.Y.Z-classic.zip` from the latest release on the
[Releases page](https://github.com/Vaterade/pfUI-trades/releases) and unzip it into
`Interface/AddOns/`, so there is a `pfUI-trades` folder with `pfUI-trades.toc` directly inside.
Changes in each version are in `CHANGELOG.md`.

## Using it

Press **Queue** at the bottom left of the recipe details.

- **Add** puts the selected recipe on the list, using the amount in the window's quantity box.
- **Start** crafts the first task on the list that has its materials, as many as it can, and **Stop**
  halts it. The game only starts a craft from a click, so press **Start** again for the next task.
  Enchanting needs a target for every cast, so there the button is **Next** and casts one at a time.
- Each task has buttons to change its count (hold Shift for 5), move it and remove it. Click its
  name to select the recipe.

Tasks count down whenever the recipe's craft succeeds, including from the window's own Create
button. Each character has its own list per profession. A task's count is crafts, not items.

## Materials

The table lists what the tasks still need: **Need**, **Bags**, **Bank**, **Mail** and **Alts**.
Hover a row to see which alt has what.

| Name color | Meaning |
|---|---|
| Green | Enough in your bags |
| Yellow | Enough with your bank |
| Orange | Enough with your mail and alts |
| Red | Not enough anywhere |

Something a task earlier on the list makes comes off what's needed, so smelting bars for a later
task doesn't show those bars as missing.

Your own bags and bank are always live. Mail and alts come from Altoholic, covering your other
characters on the realm, of either faction, since this server lets the factions mail each other, and are as recent as each character's last login. Both can be
turned off under pfUI's settings, in Thirdparty > Trades.

## Bank reminder

Opening your bank tells you if it holds materials your tasks need, in any profession: a message
on screen and a list in chat of how many of each to take. It only counts what your bags are short
of, and says nothing if there's nothing to take. It can be turned off in the same settings.

## Alt reminder

Opening your bank or mailbox also tells you if this character has materials that another
character's task list needs, with how many to send to whom. It covers your other characters on the
realm, of either faction, once they've logged in with this version. This character keeps what its own tasks need, and
what the alt holds comes off, as Altoholic last saw it. Without Altoholic, the alt counts as having
none. It can be turned off in the same settings.

## Testing

`luajit tools/test.lua`

## License

MIT. See `LICENSE`.
