
import argparse
import sys
import yaml

from jsonschema import Draft202012Validator, FormatChecker


def validate_config(config_file, schema_file):
    try:
        with open(config_file, "r", encoding="utf-8") as file:
            config = yaml.safe_load(file)

        with open(schema_file, "r", encoding="utf-8") as file:
            schema = yaml.safe_load(file)

        validator = Draft202012Validator(
            schema,
            format_checker=FormatChecker()
        )

        errors = sorted(
            validator.iter_errors(config),
            key=lambda error: list(error.absolute_path)
        )

        if errors:
            print("CONFIGURATION VALIDATION FAILED")

            for error in errors:
                path = ".".join(str(item) for item in error.absolute_path)
                print(f"- {path or 'root'}: {error.message}")

            return False

        print("CONFIGURATION VALIDATION SUCCESSFUL")
        print(f"Project: {config['project']['name']}")
        print(f"Build tool: {config['build']['tool']}")
        print(f"Java version: {config['build']['javaVersion']}")
        print(f"Database enabled: {config['database']['enabled']}")
        print(f"Namespace: {config['deployment']['namespace']}")

        return True

    except FileNotFoundError as error:
        print(f"FILE NOT FOUND: {error.filename}")
        return False

    except yaml.YAMLError as error:
        print(f"INVALID YAML: {error}")
        return False

    except Exception as error:
        print(f"VALIDATION ERROR: {error}")
        return False


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Validate generic Java project configuration"
    )

    parser.add_argument(
        "--config",
        required=True,
        help="Path to project YAML configuration"
    )

    parser.add_argument(
        "--schema",
        default="schemas/project-config.schema.json",
        help="Path to JSON schema"
    )

    args = parser.parse_args()

    success = validate_config(args.config, args.schema)
    sys.exit(0 if success else 1)
