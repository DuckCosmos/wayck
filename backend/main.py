import json
import sys
import clipboard
import launcher
import monitor
import update
import utils

def emit(value):
    print(json.dumps(value, ensure_ascii=False, separators=(",", ":")), flush=True)

def main(argv):
    if len(argv) > 1:
        command, args = argv[1], argv[2:]
        if command == "--monitor":
            monitor.run()
        elif command == "--filter":
            emit(launcher.filter_apps(args[0] if args else ""))
        elif command == "--exec" and len(args) >= 2:
            utils.register_usage(args[0])
            launcher.execute(args[1], args[0])
        elif command == "--clipboard-list":
            emit(clipboard.list_items(args[0] if args else ""))
        elif command == "--clipboard-copy" and args:
            clipboard.copy_item(args[0])
        elif command == "--clipboard-delete" and args:
            clipboard.delete_item(args[0])
        elif command == "--clipboard-clear":
            clipboard.clear()
        elif command == "--check_version":
            try:
                print(str(update.check()).lower(), flush=True)
            except Exception as error:
                print(f"Erro ao verificar atualização: {error}", file=sys.stderr)
                return 1
        elif command == "--version_info":
            try:
                local, remote, available = update.check_info()
                emit({"local": local, "remote": remote, "available": available})
            except Exception as error:
                print(f"Erro ao consultar versões: {error}", file=sys.stderr)
                return 1
        return 0
    for line in sys.stdin:
        try:
            emit(launcher.filter_apps(line.rstrip("\n")))
        except Exception as error:
            print(f"Erro no launcher: {error}", file=sys.stderr)
    return 0

if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv))
    except KeyboardInterrupt:
        raise SystemExit(130)
    except Exception as error:
        print(f"Wayck backend: {error}", file=sys.stderr)
        raise SystemExit(1)
