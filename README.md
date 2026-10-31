# pfUI-trades

An external module for [pfUI](https://github.com/brues-code/pfUI) that adds a task list and a
materials overview beside the game's own profession windows. It needs pfUI, and so ClassicAPI.
Altoholic is optional. Don't run it alongside AdvancedTradeSkillWindow2, which uses the same window.

## Using it

Press **Tasks** at the bottom left of the recipe details.

- **Add** puts the selected recipe on the list, using the amount in the window's quantity box.
- **Start** crafts the first task on the list that has its materials, as many as it can, and **Stop**
  halts it. The game only starts a craft from a click, so press **Start** again for the next task.
  Enchanting needs a target for every cast, so there the button is **Next** and casts one at a time.
- Each task has buttons to change its count (hold Shift for 5), move it and remove it. Click its
  name to select the recipe.

Tasks count down whenever the recipe's craft succeeds, including from the window's own Create
button. The list is saved per character and per profession. A task's count is crafts, not items.

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

Your own bags and bank are always live. Mail and alts come from Altoholic, covering characters
of the same realm and faction, and are as recent as each character's last login. Both can be
turned off under pfUI's settings, in Thirdparty > Trades.

## Testing

`luajit tools/test.lua`

## License

MIT. See `LICENSE`.
