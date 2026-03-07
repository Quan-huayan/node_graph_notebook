import 'package:node_graph_notebook/bloc/ui/ui_bloc.dart';

extension BlocProviderExtensions on UIBloc {
  UIBloc also(void Function(UIBloc) callback) {
    callback(this);
    return this;
  }
}