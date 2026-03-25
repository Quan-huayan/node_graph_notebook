#!/bin/bash
# Lua 命令行发送工具 (Unix/Linux/macOS)

if [ $# -eq 0 ]; then
    echo "用法："
    echo "  ./tool/lua.sh \"debugPrint('Hello')\""
    echo "  ./tool/lua.sh --file=myscript.lua"
    echo ""
    echo "示例："
    echo "  ./tool/lua.sh \"registerToolbarButton('test', 'Test', 'onTest', 'star')\""
    echo ""
    exit 1
fi

dart run tool/send_lua_command.dart "$@"
