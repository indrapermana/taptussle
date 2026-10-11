# M23.5 accessibility and usability audit

Date: 2026-10-11

This audit covers the shared player journey and representative interaction
patterns across all 18 games. It builds on the completed child-first catalog
review and iPhone 12 mini game pass.

## Automated and code-review evidence

- [x] Home, Grown-up Settings, and Game Setup pass Flutter's labeled tap target,
  Android minimum tap target, and text contrast guidelines at phone size.
- [x] Home player-count filters expose selected button semantics, game cards
  identify the game they open, and Settings has an explicit tooltip.
- [x] Two-to-four-player setup exposes participant count, player type, color,
  token, difficulty, and static player identity through native controls or
  explicit semantics. Compact enlarged-text and tablet layouts are covered.
- [x] Shared ready, pause, result, score, standings, record, replay, options,
  and Games paths have visible text labels and responsive coverage.
- [x] Puzzle results suppress meaningless participant scores. Record ordering,
  daily/weekly/overall windows, standings, and result metrics have focused
  model, repository, and flow tests.
- [x] Compact and enlarged-text coverage includes Home, Settings, graphics,
  setup, results, Lane Dash, Memory Match, Tic-Tac-Toe, Checkers, Cangkulan,
  Solitaire, Nuts & Bolts, Slither, and Sudoku. Other game boards use the same
  constrained match shell and were included in the completed iPhone 12 mini
  catalog pass.
- [x] Interactive game boards provide native controls or explicit semantic
  actions and state. Coverage includes Memory card identity protection,
  adjustable Lane Dash tracks, accessible Sudoku cells, Solitaire cards and
  piles, Nuts & Bolts color symbols, and legal/selected board-game states.
- [x] Important state is not conveyed only by color: selections use outlines,
  shapes, symbols, text, movement, or semantic labels in addition to player
  colors and highlights.
- [x] Rock Paper Scissors conceals the first choice during handoff. Cangkulan
  does not build either player's hand until the correct player confirms and
  does not show human handoff content during bot turns.
- [x] SafeArea protects the shared match shell and full-screen game surfaces;
  compact portrait and Mancala landscape/result-orientation behavior have
  focused regression coverage.

Focused M23.5 validation: 62 tests pass. The complete suite passed 670 tests
before the three new shared accessibility guideline tests were added.

## Physical iPhone checklist

These checks use normal app interaction and do not run an automated device
driver.

| Check | Expected behavior | Status |
| --- | --- | --- |
| Enlarged text | Enable an iOS accessibility text size, then inspect Home, Grown-up Settings, Paddle Duel setup, participant setup, and a result screen. Text remains readable and primary buttons remain reachable. | Passed by project owner on iPhone 12 mini |
| VoiceOver navigation | On Home, VoiceOver identifies the three player filters and their selected state, Settings, and game cards. In setup it identifies favourite and play choices. | Passed by project owner on iPhone 12 mini |
| VoiceOver game sample | In Memory Match or Sudoku, VoiceOver identifies an interactive card/cell and its state. Match pause and result actions remain reachable. | Passed by project owner on iPhone 12 mini |
| Shared-device privacy | In friend Rock Paper Scissors and Cangkulan, the next player's hidden choice/hand is not spoken or displayed before the handoff confirmation. | Passed by project owner on iPhone 12 mini |
| Safe areas and orientation | Controls avoid the notch and home indicator. Mancala enters landscape and its result returns to portrait. | Passed by project owner on iPhone 12 mini |

The project owner completed and accepted the physical iPhone accessibility
check on 2026-10-11. M23.5 is complete.
