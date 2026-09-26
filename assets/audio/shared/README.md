# TapTussle Shared Sound Pack

Original synthesized sound effects for the TapTussle mobile game.

## Technical format
- WAV
- Mono
- 16-bit PCM
- 44.1 kHz
- Short effects designed for low-latency mobile playback

## Suggested Flutter asset path
`assets/audio/shared/`

## Recommended shared mappings
- UI: `ui_tap`, `ui_confirm`, `ui_back`, `ui_invalid`
- Start flow: `countdown_tick`, `countdown_go`, `round_start`
- Competitive scoring: `score_warm`, `score_cool`
- Physics/movement: `impact_soft`, `impact_heavy`, `piece_move`, `collect`
- Cards/boards/puzzles: `card_flip`, `dice_roll`, `match_pair`, `puzzle_complete`
- Results: `result_win`, `result_draw`, `result_lose`

## Brand direction
The pack uses a short, bright arcade sound palette designed to match TapTussle's
red/orange-vs-blue/cyan visual identity. Warm and cool scoring cues are intentionally
different so two-player events can be identified by sound without looking at the HUD.

## Ownership / source
These effects were synthesized specifically for this project and do not contain
third-party samples.
