/// 命令接口
abstract class Command {
  Future<void> execute();
  Future<void> undo();

  String get description;
}