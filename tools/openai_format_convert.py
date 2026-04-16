#!/usr/bin/env python3

import argparse
import base64
import hashlib
import json
import sys
from pathlib import Path


CHATGPT_REQUIRED_FIELDS = ["tokens.access_token", "tokens.id_token"]
CHATGPT_OPTIONAL_FIELDS = [
    "tokens.account_id",
    "tokens.refresh_token",
    "disabled",
    "last_refresh",
]
CODEX_REQUIRED_FIELDS = ["access_token", "id_token"]
CODEX_OPTIONAL_FIELDS = ["account_id", "refresh_token", "disabled", "last_refresh"]
KNOWN_PREFIXES = ("chatgpt-", "codex-")


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


def rename_for_target(input_path, target_format):
    filename = input_path.name
    for prefix in KNOWN_PREFIXES:
        if filename.startswith(prefix):
            return f"{target_format}-{filename[len(prefix):]}"
    return f"{target_format}-{filename}"


def extract_id_token(data):
    tokens = data.get("tokens")
    if isinstance(tokens, dict) and isinstance(tokens.get("id_token"), str):
        return tokens["id_token"]
    if isinstance(data.get("id_token"), str):
        return data["id_token"]
    return None


def decode_jwt_payload(id_token):
    parts = id_token.split(".")
    if len(parts) < 2:
        raise ValueError("id_token 不是合法的 JWT")

    payload_segment = parts[1]
    padding = "=" * (-len(payload_segment) % 4)
    normalized = (payload_segment + padding).replace("-", "+").replace("_", "/")

    try:
        payload_data = base64.b64decode(normalized)
        payload = json.loads(payload_data.decode("utf-8"))
    except (ValueError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ValueError("无法解析 id_token 载荷") from error

    if not isinstance(payload, dict):
        raise ValueError("id_token 载荷必须是对象")
    return payload


def normalize_email(value):
    value = normalize_string(value, "email").strip().lower()
    if not value:
        raise ValueError("无法从 JSON 中解析 email")
    return value


def resolve_tier(payload):
    openai_auth = payload.get("https://api.openai.com/auth")
    auth_plan = openai_auth.get("chatgpt_plan_type") if isinstance(openai_auth, dict) else None
    candidate = str(payload.get("tier") or payload.get("plan") or auth_plan or "unknown").strip().lower()

    if "team" in candidate:
        return "team"
    if "pro" in candidate:
        return "pro"
    if "plus" in candidate:
        return "plus"
    return candidate or "unknown"


def resolve_account_metadata(data, analysis):
    payload = None
    id_token = extract_id_token(data)
    if id_token:
        payload = decode_jwt_payload(id_token)

    if analysis["format"] == "chatgpt":
        account_id = get_nested_value(data, "tokens.account_id")
    else:
        account_id = data.get("account_id")

    if (not isinstance(account_id, str) or not account_id.strip()) and payload:
        account_id = payload.get("sub")
    if not isinstance(account_id, str) or not account_id.strip():
        raise ValueError("无法从 JSON 中解析 account_id")
    account_id = account_id.strip()

    raw_email = data.get("email")
    if (not isinstance(raw_email, str) or not raw_email.strip()) and payload:
        raw_email = payload.get("email")
    email = normalize_email(raw_email)

    tier = resolve_tier(payload or {})
    return {
        "account_id": account_id,
        "email": email,
        "tier": tier,
    }


def build_account_filename(data, analysis):
    metadata = resolve_account_metadata(data, analysis)
    account_hash = hashlib.sha256(metadata["account_id"].encode("utf-8")).hexdigest()[:8]
    return f"{analysis['target_format']}-{account_hash}-{metadata['email']}-{metadata['tier']}.json"


def resolve_single_output_path(input_path, analysis, data, output_path=None, force_account_filename=False):
    if force_account_filename:
        filename = build_account_filename(data, analysis)
    else:
        filename = rename_for_target(input_path, analysis["target_format"])

    if output_path is None:
        return input_path.with_name(filename)

    output_path = Path(output_path)
    if output_path.exists() and output_path.is_dir():
        return output_path / filename
    return output_path


def collect_json_files(input_path):
    if input_path.is_file():
        return [input_path]
    return sorted(path for path in input_path.iterdir() if path.is_file() and path.suffix.lower() == ".json")


def print_file_header(path):
    print(f"文件：{path}")


def detect_path(input_path):
    input_path = Path(input_path)
    if not input_path.exists():
        raise FileNotFoundError(f"输入路径不存在：{input_path}")

    json_files = collect_json_files(input_path)
    if not json_files:
        raise ValueError(f"未找到可处理的 JSON 文件：{input_path}")

    analyses = []
    for index, file_path in enumerate(json_files):
        if index > 0:
            print()
        print_file_header(file_path)
        analyses.append((file_path, detect_file(file_path)))
    return analyses


def convert_file(input_path, output_path=None, force_account_filename=False):
    input_path = Path(input_path)
    data = load_json(input_path)
    analysis = analyze_format(data)
    print_file_header(input_path)
    print_analysis(analysis)

    converted = convert_data(data, analysis)
    output_path = resolve_single_output_path(
        input_path,
        analysis,
        data,
        output_path,
        force_account_filename=force_account_filename,
    )
    print(f"正在转换：{analysis['format']} -> {analysis['target_format']}")
    save_json(output_path, converted)
    print(f"转换完成！已保存到：{output_path}")
    return analysis, output_path


def ensure_output_directory(output_path):
    output_path.mkdir(parents=True, exist_ok=True)


def build_batch_plan(input_dir, output_dir=None, force_account_filename=False):
    json_files = collect_json_files(input_dir)
    if not json_files:
        raise ValueError(f"未找到可处理的 JSON 文件：{input_dir}")

    plan = []
    for file_path in json_files:
        data = load_json(file_path)
        analysis = analyze_format(data)
        if output_dir is None:
            destination = resolve_single_output_path(
                file_path,
                analysis,
                data,
                force_account_filename=force_account_filename,
            )
        else:
            destination = resolve_single_output_path(
                file_path,
                analysis,
                data,
                output_dir,
                force_account_filename=force_account_filename,
            )
        plan.append((file_path, analysis, destination))

    destination_map = {}
    source_set = {path.resolve() for path in json_files}
    for source_path, _, destination in plan:
        destination_key = destination.resolve(strict=False)
        if destination_key in destination_map and destination_map[destination_key] != source_path:
            raise ValueError(f"批量转换输出路径冲突：{destination}")
        if destination_key in source_set and destination_key != source_path.resolve():
            raise ValueError(f"批量转换会覆盖其他输入文件：{destination}")
        destination_map[destination_key] = source_path
    return plan


def convert_directory(input_dir, output_dir=None, force_account_filename=False):
    input_dir = Path(input_dir)
    if not input_dir.exists():
        raise FileNotFoundError(f"输入路径不存在：{input_dir}")
    if not input_dir.is_dir():
        raise ValueError(f"目录转换需要文件夹输入：{input_dir}")

    output_dir_path = Path(output_dir) if output_dir is not None else None
    if output_dir_path is not None and output_dir_path.exists() and not output_dir_path.is_dir():
        raise ValueError(f"目录转换的输出路径必须是文件夹：{output_dir_path}")
    if output_dir_path is not None:
        ensure_output_directory(output_dir_path)

    plan = build_batch_plan(input_dir, output_dir_path, force_account_filename=force_account_filename)
    results = []
    for index, (file_path, _, destination) in enumerate(plan):
        if index > 0:
            print()
        results.append(convert_file(file_path, destination, force_account_filename=force_account_filename))
    return results


def convert_path(input_path, output_path=None, force_account_filename=False):
    input_path = Path(input_path)
    if input_path.is_dir():
        return convert_directory(input_path, output_path, force_account_filename=force_account_filename)
    if input_path.is_file():
        return [convert_file(input_path, output_path, force_account_filename=force_account_filename)]
    raise FileNotFoundError(f"输入路径不存在：{input_path}")


def build_parser():
    parser = argparse.ArgumentParser(
        description="探测并转换 chatgpt / codex 两种 auth.json 格式"
    )
    subparsers = parser.add_subparsers(dest="command")

    detect_parser = subparsers.add_parser("detect", help="只探测输入文件格式，不执行转换")
    detect_parser.add_argument("input_path", help="输入 JSON 文件或文件夹路径")

    convert_parser = subparsers.add_parser("convert", help="探测后执行双向转换")
    convert_parser.add_argument("input_path", help="输入 JSON 文件或文件夹路径")
    convert_parser.add_argument("output_path", nargs="?", help="输出 JSON 文件或文件夹路径")
    convert_parser.add_argument(
        "--force-account-filename",
        action="store_true",
        help="强制输出为 <类型>-<account_id的sha256前8位>-<email>-<tier>.json",
    )

    return parser


def parse_args(argv):
    if argv and argv[0] not in {"detect", "convert", "-h", "--help"}:
        if len(argv) == 1:
            return argparse.Namespace(command="convert", input_path=argv[0], output_path=None)
        if len(argv) == 2:
            return argparse.Namespace(command="convert", input_path=argv[0], output_path=argv[1])
    return build_parser().parse_args(argv)


def main(argv=None):
    args = parse_args(sys.argv[1:] if argv is None else argv)

    if not getattr(args, "command", None):
        build_parser().print_help()
        return 1

    try:
        if args.command == "detect":
            detect_path(args.input_path)
        else:
            convert_path(
                args.input_path,
                args.output_path,
                force_account_filename=getattr(args, "force_account_filename", False),
            )
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"错误：{error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
