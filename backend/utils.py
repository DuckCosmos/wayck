import ast
import math
import operator
import os
from pathlib import Path

_OPERATORS = {
    ast.Add: operator.add,
    ast.Sub: operator.sub,
    ast.Mult: operator.mul,
    ast.Div: operator.truediv,
    ast.FloorDiv: operator.floordiv,
    ast.Mod: operator.mod,
    ast.Pow: operator.pow,
    ast.UAdd: operator.pos,
    ast.USub: operator.neg,
}

def _calculate_node(node):
    if isinstance(node, ast.Expression):
        return _calculate_node(node.body)
    if isinstance(node, ast.Constant) and type(node.value) in (int, float):
        return node.value
    if isinstance(node, ast.UnaryOp) and type(node.op) in _OPERATORS:
        return _OPERATORS[type(node.op)](_calculate_node(node.operand))
    if isinstance(node, ast.BinOp) and type(node.op) in _OPERATORS:
        left = _calculate_node(node.left)
        right = _calculate_node(node.right)
        if isinstance(node.op, ast.Pow) and abs(right) > 100:
            raise ValueError("Expoente fora do limite")
        return _OPERATORS[type(node.op)](left, right)
    raise ValueError("Expressão não permitida")

def calculate(text):
    expression = text.replace("×", "*").replace("÷", "/").replace("x", "*").replace("X", "*").replace(",", ".").strip()
    if not expression or len(expression) > 120 or not any(char.isdigit() for char in expression):
        return None
    try:
        tree = ast.parse(expression, mode="eval")
        if sum(1 for _ in ast.walk(tree)) > 64:
            return None
        value = _calculate_node(tree)
        if isinstance(value, complex) or not isinstance(value, (int, float)) or not math.isfinite(value):
            return None
    except (SyntaxError, ValueError, TypeError, ZeroDivisionError, OverflowError):
        return None
    if float(value).is_integer() and -(2**63) <= value < 2**63:
        result = str(int(value))
    else:
        result = format(value, ".12g")
    return result.replace(".", ",") if "," in text else result

def _usage_file():
    return Path.home() / ".local/share/wayck_uso.txt"

def read_usage():
    usage = {}
    try:
        for line in _usage_file().read_text(encoding="utf-8").splitlines():
            if "\t" not in line:
                continue
            name, count = line.rsplit("\t", 1)
            try:
                usage[name] = max(0, int(count))
            except ValueError:
                continue
    except OSError:
        pass
    return usage

def register_usage(name):
    if not name or len(name) > 512:
        return
    path = _usage_file()
    usage = read_usage()
    usage[name] = min(usage.get(name, 0) + 1, 2**31 - 1)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary.write_text("".join(f"{key}\t{count}\n" for key, count in usage.items()), encoding="utf-8")
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
    except OSError:
        temporary.unlink(missing_ok=True)
