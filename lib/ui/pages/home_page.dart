import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../plugins/graph/bloc/graph_bloc.dart';
import '../../plugins/graph/bloc/graph_state.dart';
import '../../plugins/graph/bloc/node_bloc.dart';
import '../../plugins/graph/bloc/node_state.dart';
import '../../plugins/graph/ui/graph_view.dart';
import '../bars/core_toolbar.dart';
import '../bars/sidebar.dart';
import '../bloc/ui_bloc.dart';
import '../bloc/ui_event.dart';
import '../bloc/ui_state.dart';

/// 主页面
///
/// 应用的主页面，包含核心工具栏、侧边栏和图形视图
class HomePage extends StatefulWidget {
  /// 创建一个主页面
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const CoreToolbar(),
    body: _buildBody(),
  );

  Widget _buildBody() => BlocBuilder<GraphBloc, GraphState>(
    builder: (context, graphState) => BlocBuilder<NodeBloc, NodeState>(
      builder: (context, nodeState) => BlocBuilder<UIBloc, UIState>(
        builder: (context, uiState) => Row(
          children: [
            // 侧边栏 - 由主UI管理
            if (uiState.isSidebarOpen && graphState.hasGraph)
              Row(
                children: [
                  SizedBox(
                    width: uiState.sidebarWidth,
                    child: Sidebar(
                      graph: graphState.graph,
                      nodes: nodeState.nodes,
                    ),
                  ),
                  // 侧边栏宽度调整把手
                  GestureDetector(
                    onPanUpdate: (details) {
                      final newWidth = uiState.sidebarWidth + details.delta.dx;
                      context.read<UIBloc>().add(
                        UISetSidebarWidthEvent(newWidth),
                      );
                    },
                    child: Container(
                      width: 5,
                      color: Colors.transparent,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeLeftRight,
                        child: Container(
                          width: 1,
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            // 主内容区 - GraphView
            const Expanded(
              child: GraphView(),
            ),
          ],
        ),
      ),
    ),
  );
}
