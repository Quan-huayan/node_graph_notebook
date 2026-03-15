# Refactor 文档文件夹

由于整个重构任务庞大且复杂性极高，重构过程中要始终留下文档记录。

每次重构都需在refactor文件夹下新建一个文件夹，含有以下内容：

- refactor_plan.md 本次重构的计划
- refactor_status.md 本次重构的实施状态（如果已完成，则可删除）
- refactor_changes.md 说明本次重构进行了哪些更改，更改前以及更改后的架构如何，有哪些问题需要解决，发现原来的总架构设计可能哪些地方不合理需要调整重构方向等。

然后在下面按序添加上述文档的引用以便其他人了解重构进度：

Phase 1 添加 Command Bus:

- [重构计划](phase_1_command_bus/refactor_plan.md)
- [变更说明](phase_1_command_bus/refactor_changes.md)

Phase 1 重构已完成。
