import sys
import json

def main():
    # Read the JSON input from stdin
    try:
        input_json = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(json.dumps({"error": f"JSON decode error: {str(e)}"}))
        sys.exit(1)

    # Extract the original .env content and env vars to merge from the input JSON
    original_env_content = input_json.get("original_env_content", "")
    env_vars_to_merge = json.loads(input_json.get("env_vars_to_merge", "{}"))

    # Convert the original .env content into a dictionary, ignoring lines without "="
    original_env_dict = {}
    for line in original_env_content.splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            original_env_dict[key.strip()] = value.strip()

    # Merge the dictionaries
    merged_env_dict = {**original_env_dict, **env_vars_to_merge}

    # Output the merged content as a JSON object
    output = {"result": "\n".join(f"{key}={value}" for key, value in merged_env_dict.items())}
    print(json.dumps(output))

if __name__ == "__main__":
    main()
