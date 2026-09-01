# Snooker Calendar for Omarchy

A Quickshell bar widget for the World Snooker Tour. It shows the tournament that
is on right now with live frame-by-frame scores, the rest of today's order of
play, the latest results, and the events that follow — every time converted to
your local zone.

## Features

- The current (or next) ranking event with venue, dates, and a live `T−` countdown
- Live matches with frame score, per-frame points, best-of, and in-play state
- Today's remaining order of play, with a countdown to each match
- Latest completed results from the running event
- The next six tournaments on tour
- Offline cache and a respectful six-hour schedule refresh
- No API key, account, daemon, or telemetry

## Install

```bash
omarchy plugin add https://github.com/<you>/omarchy-snooker.git --enable
```

Or from a local checkout:

```bash
omarchy plugin add "$(pwd)" --enable
```

## Usage

- Left-click the 🎱 to open or close the calendar.
- Middle-click it to force a schedule refresh.
- Press `R` while the panel is open to refresh.
- Press `Escape` to close the panel.

The schedule refresh interval defaults to six hours (3–24 configurable). While
the panel is open and a match is live, frame scores refresh every 45 seconds
(20–300 configurable). Nothing polls while the panel is closed.

## Disable or uninstall

```bash
omarchy plugin disable underday.snooker-calendar
omarchy plugin enable underday.snooker-calendar
omarchy plugin remove underday.snooker-calendar
```

The schedule cache may remain under `$XDG_CACHE_HOME/omarchy/snooker-calendar`
(or `~/.cache/omarchy/snooker-calendar`) and can be deleted separately.

## Data and network use

Schedule, match, and live-score data come from the public World Snooker Tour web
endpoints that [wst.tv](https://www.wst.tv) itself reads:

| Endpoint | Used for |
|---|---|
| `tournaments.snooker.web.gc.wstservices.co.uk/v2/?season=YYYY` | Season calendar |
| `matches.snooker.web.gc.wstservices.co.uk/v2/` | Order of play and results |
| `snooker.graph.gc.wstservices.co.uk/graphql` | Live frame scores |
| `players.snooker.org` | Player IDs for profile links (cached 7 days) |
| `www.snooker.org/res/index.asp?template=2&season=YYYY` | Event IDs for links (cached 12 hours) |

The match feed ignores query filters and returns roughly 300 KB covering several
tournaments, so `bin/snooker-build` reduces it to the running event before
anything is cached — about 12 KB on disk. Live scores are requested for every
in-play match in one batched GraphQL call.

Clicking a match opens its live match centre on wst.tv, whose route is simply the
match UUID the feed already carries. Tournaments and player names open the
matching page on snooker.org instead: wst.tv is a single-page app that returns the
same shell for every route — including routes that do not exist — so a guessed
slug cannot be verified. snooker.org is server-rendered with stable numeric IDs, but keys on
its own IDs rather than the WST UUIDs, so `bin/snooker-links` matches events on
their dates and players on their names. Name matching runs in tiers: exact, then
a diacritic fold (`Nüßle` / `Nuessle`), then dropping middle initials
(`Mark J Williams` / `Mark Williams`). A name that stays ambiguous gets no link
rather than a wrong one.

If a refresh fails, the previous cached calendar continues to be shown
regardless of its age. If only the snooker.org sources fail, the calendar still
works and links fall back to the season page.

A World Snooker Tour season runs from June to May and is named for its opening
year, which is how `bin/snooker-fetch` picks the season to request.

This plugin is unofficial and is not associated with the World Snooker Tour,
WPBSA, or their affiliates. Trademarks belong to their respective owners.

## Requirements

- Omarchy Quattro / Omarchy Shell with third-party plugin support
- `curl` and `python` (included with Omarchy)
- Network access only when refreshing

## Validate

```bash
omarchy plugin validate .
qmllint -I /usr/share/omarchy/shell BarWidget.qml Panel.qml
```

## Credits

Widget structure, cache-read hardening, and countdown behavior follow
[omarchy-f1](https://github.com/spaceXrace/omarchy-f1) by spaceXrace (MIT).

## License

MIT. See [LICENSE](LICENSE).
