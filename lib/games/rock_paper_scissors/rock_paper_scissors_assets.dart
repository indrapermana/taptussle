import 'rock_paper_scissors_model.dart';

abstract final class RockPaperScissorsAssets {
  static const _root = 'assets/games/rock_paper_scissors';

  static const choiceLocked = '$_root/rps_choice_locked.png';

  static String choice(RockPaperScissorsChoice choice, {required bool warm}) =>
      '$_root/rps_${choice.name}_${warm ? 'warm' : 'cool'}.png';
}
