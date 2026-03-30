#!/usr/bin/env python3
"""
Skill: openspace-task
Delegate a task to OpenSpace's self-evolving engine.
"""

import os
import subprocess
import json
from pathlib import Path

def run_openspace_task(task: str, model: str = None) -> str:
    """
    Run a task using the OpenSpace CLI.

    Parameters:
        task: The task description (required).
        model: Optional model override (e.g., "anthropic/claude-sonnet-4-5").

    Returns:
        A string summarizing the result, including any evolved skills info.
    """
    # Build command
    cmd = ["openspace", "--query", task]
    if model:
        cmd.extend(["--model", model])

    try:
        # Execute openspace command
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=600,  # 10 minute default timeout
            env=os.environ.copy()
        )

        if result.returncode != 0:
            return f"OpenSpace failed (exit {result.returncode}):\n{result.stderr}"

        output = result.stdout.strip()

        # Try to extract evolved skills count if JSON output available
        # OpenSpace may output structured logs; we can look for "evolved" markers
        evolved_count = output.lower().count("evolved")
        if evolved_count > 0:
            output += f"\n\n(Detected {evolved_count} evolution event(s) in the logs.)"

        return output

    except subprocess.TimeoutExpired:
        return "OpenSpace task timed out after 10 minutes."
    except FileNotFoundError:
        return "Error: 'openspace' command not found. Ensure OpenSpace is installed and in PATH."
    except Exception as e:
        return f"Error running OpenSpace: {str(e)}"

if __name__ == "__main__":
    # Simple test
    test_task = "Write a Python script that prints 'Hello from OpenSpace'"
    print(run_openspace_task(test_task))