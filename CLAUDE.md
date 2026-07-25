# GearLensRu — working notes

Single-file World of Warcraft addon (`GearLensRu.lua`) for **Classic: Mists of
Pandaria, interface 50504**. It draws per-slot item levels on the Character and
Inspect frames and flags gear problems. Repo lives inside the live addon folder,
so the working tree *is* the installed addon — `/reload` in game tests the
working copy directly.

## Hard constraints

- **ruRU client only.** Detection matches Russian tooltip strings
  (`"Уровень предмета: %d"`, `EMPTY_SOCKET_TEXT`, `ENG_TINKER_PATTERNS`). On any
  other locale the checks silently find nothing. All player-facing strings are
  Russian; code and comments are English.
- **No Lua interpreter on this machine** and no way to run the game from here.
  Changes are reviewed, not parsed. `/reload` in game is the only real check —
  it prints Lua errors immediately.
- **`C_TooltipInfo` does not exist in MoP Classic** (`/glr diag` reports `nil`).
  The `C_TooltipInfo` branch in the tooltip readers never runs here; the
  FontString scrape is the live path. Keep the branch for clients that have it.

## Where data comes from — check this first when a check misbehaves

| Check | Source | Fragile? |
|---|---|---|
| Empty sockets, tinkers, upgrade level, current ilvl | scan tooltip lines | **yes** |
| Belt buckle, blacksmithing socket | derived from socket count | **yes** (inherits above) |
| Enchants | item link (`GetEnchantFromLink`) | no |
| Armor spec, gem quality/era | `GetItemInfo` | no |

If several checks fail at once and the link-based ones still work, the fault is
in `GetInventoryTooltipLines`, not in the individual checks.

## The scan tooltip

All tooltip reads go through `ReadScanTip`. Two rules, both learned the hard way:

1. **`SetOwner` before every read.** Owning the tooltip once at load and only
   calling `ClearLines()` between reads works at first and degrades later in the
   session — `SetInventoryItem` starts returning fewer lines, or none, and the
   addon reports gear problems that do not exist. This looked like a stale item
   cache because a `/reload` fixed it; it is not. A `/reload` does not refetch
   item data the client already holds, it recreates this frame. `SetOwner` also
   clears the lines, so no separate `ClearLines()` is needed.
2. **A short read is not an answer.** `ScanLines` re-reads once if a tooltip
   comes back with under two lines.

Separately, the client's item cache genuinely does start cold. Right after
client launch a tooltip can be *truncated*: the item's own `"Уровень предмета"`
line is present while the tinker's `"Использование:"` line, which needs the
enchant's spell data, is not. Handling:

- `incompleteRead` (missing ilvl line) and "engineer's tinker slot with no
  tinker found" both mark the read retryable
- `RETRY_LIMIT` × `RETRY_DELAY` (12 × 0.4s) self-heal window
- `GET_ITEM_INFO_RECEIVED`, coalesced, catches anything slower

Sticky caches (`tinkerSeen`, `upgradeSeen`, `ilvlSeen`) hold last-known-good
values per slot, keyed by item link so they cannot survive an actual item change.

## Debugging

- `/glr` — tinker detection plus current vs base ilvl per slot
- `/glr diag` — scan tooltip owner, line counts, the `Использование:` /
  `Уровень ...` lines found, per-pattern match results, and blank-line counts
- `/glr dump <slot>` — every tooltip line for one slot

Neither retries, so both show the raw current state.

**`/reload` cannot reproduce cold-cache bugs** — it restarts the addon and keeps
the client's item cache warm. Only a full client restart gives a cold cache.

Verified facts worth not re-testing: WoW's `string.lower` *does* fold Cyrillic
(`("Ж"):lower() == "ж"` is true), and the scrape returns every line the tooltip
has, with no blank entries, when the data is there.

## Icon

`GearLens_Icon.png` (512×512) is repo-only — it backs the README on GitHub and
the CurseForge avatar. **WoW cannot load PNG**, so `## IconTexture` resolves to
`GearLens_Icon.tga`: 128×128, 32-bit, uncompressed, **bottom-origin**.

Regenerating it: ImageMagick's `-orient bottom-left` sets the header flag
*without reordering rows*, so it must be paired with `-flip` or the icon ships
upside down. Verify by round-tripping and comparing against the source:

```sh
magick GearLens_Icon.png -resize 128x128 -alpha set -type TrueColorAlpha \
       -compress None -flip -orient bottom-left GearLens_Icon.tga
magick GearLens_Icon.tga rt.png && magick GearLens_Icon.png -resize 128x128 ref.png
magick compare -metric AE ref.png rt.png null:    # must be 0
```

## Release process

1. Bump `## Version:` in `GearLensRu.toc`
2. Add a `CHANGELOG.md` section (Russian, Keep a Changelog format)
3. Commit, then `git tag -a vX.Y`, push branch and tag
4. Build from the **tag**, never the working tree:

```sh
git archive --format=zip -9 --prefix=GearLensRu/ -o dist/GearLensRu-X.Y.zip vX.Y
```

The `GearLensRu/` prefix is required — CurseForge extracts the zip straight into
`Interface/AddOns/`. `.gitattributes` marks repo-only files `export-ignore`
(this file, `.gitignore`, `.gitattributes`, the PNG); `dist/` is git-ignored.

**Do not move a published tag.** Tags were moved several times pre-publication
when only packaging changed; once a version is on CurseForge that stops.

CurseForge: project ID `1625028`, categories Character Advancement + Tooltip,
game version MoP Classic 5.5.x. Moderation requires **English first** in the
summary and description — mirrored in `## Notes` (English) with `## Notes-ruRU`
overriding, and in the README.

Watch out: the local IDE's Git plugin has silently reworded a commit immediately
after it was created, orphaning a tag that pointed at the pre-reword hash. Verify
`HEAD` right before tagging.

## Open items

- **The v1.2 mid-session tooltip fix is unverified.** It needs hours of play to
  confirm. If false "Нет улучшения инженера" warnings return, run `/glr diag`
  first: `владелец подсказки: нет` would mean owner loss survived the fix, and
  the next single variable to try is owning the tooltip with `UIParent` instead
  of `WorldFrame` (note: `UIParent` stops populating while the UI is hidden).
- **Sockets could leave the tooltip path entirely.** `GetItemStats(link)` returns
  `EMPTY_SOCKET_*` counts from the link — locale-independent and immune to all of
  the above. That would also retire the Russian-only `EMPTY_SOCKET_TEXT` table
  and take the belt buckle and blacksmithing checks off the fragile path.
- `CHANGELOG.md` is Russian only.

## Fixed, kept as a note

`GetAvgIlvlForUnit` returning `total/16` twice for an inspected unit looked like
a bug but is correct — bags are not visible, so there is no separate maximum.
The real defect was on the player branch: `GetAverageItemLevel()` returns a
bag-inclusive average and a worn-only one, and passing them through unswapped
made the character frame show a different metric from the inspect frame. It now
orders the pair with `math.min`/`math.max`, which is correct whichever order the
client returns them in.
