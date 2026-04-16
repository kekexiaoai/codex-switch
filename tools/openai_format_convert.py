#!/usr/bin/env python3

import argparse
import json
import sys


CHATGPT_REQUIRED_FIELDS = ["tokens.access_token", "tokens.id_token"]
CHATGPT_OPTIONAL_FIELDS = [
    "tokens.account_id",
    "tokens.refresh_token",
    "disabled",
    "last_refresh",
]
CODEX_REQUIRED_FIELDS = ["access_token", "id_token"]
CODEX_OPTIONAL_FIELDS = ["account_id", "refresh_token", "disabled", "last_refresh"]


def detect_format(data):
    """
    自动判断 JSON 格式。
    返回：'chatgpt' 或 'codex'
    无法识别则抛出错误。
    """
    if not isinstance(data, dict):
        raise ValueError("JSON 根节点必须是对象")

    tokens = data.get("tokens")
    if data.get("auth_mode") == "chatgpt" and isinstance(tokens, dict):
        return "chatgpt"

    if data.get("type") == "codex":
        return "codex"

    raise ValueError("无法识别的格式，不是 chatgpt 或 codex 结构")


def get_nested_value(data, path):
    current = data
    for part in path.split("."):
        if not isinstance(current, dict) or part not in current:
            return None
        current = current[part]
    return current


def has_meaningful_value(data, path):
    value = get_nested_value(data, path)
    if value is None:
        return False
    if isinstance(value, str):
        return value != ""
    return True


def require_string(data, path):
    value = get_nested_value(data, path)
    if not isinstance(value, str) or value == "":
        raise ValueError(f"缺少必填字段：{path}")
    return value


def normalize_string(value, field_name, default=""):
    if value is None:
        return default
    if isinstance(value, str):
        return value
    raise ValueError(f"字段 {field_name} 必须是字符串")


def copy_optional_string(source, source_path, target, target_key):
    value = get_nested_value(source, source_path)
    if isinstance(value, str) and value != "":
        target[target_key] = value


def analyze_format(data):
    fmt = detect_format(data)
    if fmt == "chatgpt":
        required_fields = CHATGPT_REQUIRED_FIELDS
        optional_fields = CHATGPT_OPTIONAL_FIELDS
        target_format = "codex"
    else:
        required_fields = CODEX_REQUIRED_FIELDS
        optional_fields = CODEX_OPTIONAL_FIELDS
        target_format = "chatgpt"

    missing_required = [field for field in required_fields if not has_meaningful_value(data, field)]
    missing_optional = [field for field in optional_fields if not has_meaningful_value(data, field)]

    return {
        "format": fmt,
        "target_format": target_format,
        "missing_required": missing_required,
        "missing_optional": missing_optional,
        "convertible": not missing_required,
    }


def chatgpt_to_codex(chatgpt_data):
    """chatgpt 格式 -> codex 格式"""
    codex = {
        "access_token": require_string(chatgpt_data, "tokens.access_token"),
        "disabled": bool(chatgpt_data.get("disabled", False)),
        "email": "",
        "expired": "",
        "id_token": require_string(chatgpt_data, "tokens.id_token"),
        "last_refresh": normalize_string(chatgpt_data.get("last_refresh", ""), "last_refresh"),
        "type": "codex",
    }
    copy_optional_string(chatgpt_data, "tokens.account_id", codex, "account_id")
    copy_optional_string(chatgpt_data, "tokens.refresh_token", codex, "refresh_token")
    return codex


def codex_to_chatgpt(codex_data):
    """codex 格式 -> chatgpt 格式"""
    tokens = {
        "access_token": require_string(codex_data, "access_token"),
        "id_token": require_string(codex_data, "id_token"),
    }
    copy_optional_string(codex_data, "account_id", tokens, "account_id")
    copy_optional_string(codex_data, "refresh_token", tokens, "refresh_token")

    return {
        "OPENAI_API_KEY": "",
        "auth_mode": "chatgpt",
        "disabled": bool(codex_data.get("disabled", False)),
        "last_refresh": normalize_string(codex_data.get("last_refresh", ""), "last_refresh"),
        "tokens": tokens,
    }


def convert_data(data, analysis=None):
    analysis = analysis or analyze_format(data)
    if not analysis["convertible"]:
        missing = "、".join(analysis["missing_required"])
        raise ValueError(f"{analysis['format']} 格式缺少必填字段，无法转换：{missing}")

    if analysis["format"] == "chatgpt":
        return chatgpt_to_codex(data)
    return codex_to_chatgpt(data)


def load_json(input_path):
    with open(input_path, "r", encoding="utf-8") as file:
        return json.load(file)


def save_json(output_path, data):
    with open(output_path, "w", encoding="utf-8") as file:
        json.dump(data, file, indent=2, ensure_ascii=False)
        file.write("\n")


def print_analysis(analysis):
    print(f"识别格式：{analysis['format']}")
    print(f"可转换为：{analysis['target_format']}")
    if analysis["missing_required"]:
        print(f"缺少必填字段：{'、'.join(analysis['missing_required'])}")
        print("当前状态：不可转换")
    else:
        print("当前状态：可转换")
    if analysis["missing_optional"]:
        print(f"缺少可选字段：{'、'.join(analysis['missing_optional'])}")


def detect_file(input_path):
    data = load_json(input_path)
    analysis = analyze_format(data)
    print_analysis(analysis)
    return analysis


def convert_file(input_path, output_path):
    data = load_json(input_path)
    analysis = analyze_format(data)
    print_analysis(analysis)

    converted = convert_data(data, analysis)
    print(f"正在转换：{analysis['format']} -> {analysis['target_format']}")
    save_json(output_path, converted)
    print(f"转换完成！已保存到：{output_path}")
    return analysis


def build_parser():
    parser = argparse.ArgumentParser(
        description="探测并转换 chatgpt / codex 两种 auth.json 格式"
    )
    subparsers = parser.add_subparsers(dest="command")

    detect_parser = subparsers.add_parser("detect", help="只探测输入文件格式，不执行转换")
    detect_parser.add_argument("input_file", help="输入 JSON 文件路径")

    convert_parser = subparsers.add_parser("convert", help="探测后执行双向转换")
    convert_parser.add_argument("input_file", help="输入 JSON 文件路径")
    convert_parser.add_argument("output_file", help="输出 JSON 文件路径")

    return parser


def parse_args(argv):
    if len(argv) == 2 and argv[0] not in {"detect", "convert", "-h", "--help"}:
        return argparse.Namespace(command="convert", input_file=argv[0], output_file=argv[1])
    return build_parser().parse_args(argv)


def main(argv=None):
    args = parse_args(sys.argv[1:] if argv is None else argv)

    if not getattr(args, "command", None):
        build_parser().print_help()
        return 1

    try:
        if args.command == "detect":
            detect_file(args.input_file)
        else:
            convert_file(args.input_file, args.output_file)
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"错误：{error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
