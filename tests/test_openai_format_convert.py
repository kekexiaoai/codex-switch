import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = ROOT / "tools" / "openai_format_convert.py"


def load_module():
    spec = importlib.util.spec_from_file_location("openai_format_convert", SCRIPT_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


MODULE = load_module()


class OpenAIFormatConvertTests(unittest.TestCase):
    def test_chatgpt_to_codex_accepts_minimal_payload(self):
        chatgpt_data = {
            "OPENAI_API_KEY": "",
            "auth_mode": "chatgpt",
            "tokens": {
                "access_token": "access-token",
                "id_token": "id-token",
            },
        }

        converted = MODULE.chatgpt_to_codex(chatgpt_data)

        self.assertEqual(
            converted,
            {
                "access_token": "access-token",
                "disabled": False,
                "email": "",
                "expired": "",
                "id_token": "id-token",
                "last_refresh": "",
                "type": "codex",
            },
        )

    def test_codex_to_chatgpt_keeps_empty_api_key_string(self):
        codex_data = {
            "access_token": "access-token",
            "id_token": "id-token",
            "type": "codex",
        }

        converted = MODULE.codex_to_chatgpt(codex_data)

        self.assertEqual(converted["OPENAI_API_KEY"], "")
        self.assertEqual(converted["auth_mode"], "chatgpt")
        self.assertEqual(converted["disabled"], False)
        self.assertEqual(converted["last_refresh"], "")
        self.assertEqual(
            converted["tokens"],
            {
                "access_token": "access-token",
                "id_token": "id-token",
            },
        )

    def test_detect_subcommand_reports_source_and_target(self):
        chatgpt_data = {
            "OPENAI_API_KEY": "",
            "auth_mode": "chatgpt",
            "tokens": {
                "access_token": "access-token",
                "id_token": "id-token",
            },
        }

        with tempfile.TemporaryDirectory() as temp_dir:
            input_path = Path(temp_dir) / "chatgpt.json"
            input_path.write_text(json.dumps(chatgpt_data), encoding="utf-8")

            result = subprocess.run(
                ["python3", str(SCRIPT_PATH), "detect", str(input_path)],
                capture_output=True,
                text=True,
                check=False,
            )

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertIn("识别格式：chatgpt", result.stdout)
        self.assertIn("可转换为：codex", result.stdout)

    def test_convert_subcommand_writes_detected_target_format(self):
        chatgpt_data = {
            "OPENAI_API_KEY": "",
            "auth_mode": "chatgpt",
            "tokens": {
                "access_token": "access-token",
                "id_token": "id-token",
            },
        }

        with tempfile.TemporaryDirectory() as temp_dir:
            input_path = Path(temp_dir) / "chatgpt.json"
            output_path = Path(temp_dir) / "codex.json"
            input_path.write_text(json.dumps(chatgpt_data), encoding="utf-8")

            result = subprocess.run(
                ["python3", str(SCRIPT_PATH), "convert", str(input_path), str(output_path)],
                capture_output=True,
                text=True,
                check=False,
            )

            if output_path.exists():
                converted = json.loads(output_path.read_text(encoding="utf-8"))
            else:
                converted = None

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertIsNotNone(converted)
        self.assertEqual(converted["type"], "codex")
        self.assertEqual(converted["access_token"], "access-token")
        self.assertEqual(converted["id_token"], "id-token")

    def test_convert_subcommand_uses_default_output_name_for_single_file(self):
        codex_data = {
            "access_token": "access-token",
            "id_token": "id-token",
            "type": "codex",
        }

        with tempfile.TemporaryDirectory() as temp_dir:
            input_path = Path(temp_dir) / "codex-demo.json"
            expected_output_path = Path(temp_dir) / "chatgpt-demo.json"
            input_path.write_text(json.dumps(codex_data), encoding="utf-8")

            result = subprocess.run(
                ["python3", str(SCRIPT_PATH), "convert", str(input_path)],
                capture_output=True,
                text=True,
                check=False,
            )

            if expected_output_path.exists():
                converted = json.loads(expected_output_path.read_text(encoding="utf-8"))
            else:
                converted = None

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertIn(str(expected_output_path), result.stdout)
        self.assertIsNotNone(converted)
        self.assertEqual(converted["auth_mode"], "chatgpt")

    def test_convert_subcommand_converts_directory_into_default_output_names(self):
        chatgpt_data = {
            "OPENAI_API_KEY": "",
            "auth_mode": "chatgpt",
            "tokens": {
                "access_token": "access-token",
                "id_token": "id-token",
            },
        }
        codex_data = {
            "access_token": "another-access-token",
            "id_token": "another-id-token",
            "type": "codex",
        }

        with tempfile.TemporaryDirectory() as temp_dir:
            input_dir = Path(temp_dir) / "inputs"
            input_dir.mkdir()
            (input_dir / "chatgpt-alpha.json").write_text(json.dumps(chatgpt_data), encoding="utf-8")
            (input_dir / "codex-beta.json").write_text(json.dumps(codex_data), encoding="utf-8")

            result = subprocess.run(
                ["python3", str(SCRIPT_PATH), "convert", str(input_dir)],
                capture_output=True,
                text=True,
                check=False,
            )

            output_one = input_dir / "codex-alpha.json"
            output_two = input_dir / "chatgpt-beta.json"

            converted_one = json.loads(output_one.read_text(encoding="utf-8")) if output_one.exists() else None
            converted_two = json.loads(output_two.read_text(encoding="utf-8")) if output_two.exists() else None

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertIsNotNone(converted_one)
        self.assertIsNotNone(converted_two)
        self.assertEqual(converted_one["type"], "codex")
        self.assertEqual(converted_two["auth_mode"], "chatgpt")


if __name__ == "__main__":
    unittest.main()
