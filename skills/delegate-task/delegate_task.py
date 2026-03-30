#!/usr/bin/env python3
"""
Skill: delegate-task
Allows the agent to delegate tasks to an OpenSpace MCP server, enabling self-evolving capabilities and community skill sharing.
"""
import os
import json
import asyncio
from pathlib import Path
try:
    from mcp import Client
except ImportError:
    Client = None

# OpenSpace MCP server defaults
OPENSPACE_MCP_HOST = os.environ.get("OPENSPACE_MCP_HOST", "http://127.0.0.1:7788")
OPENSPACE_WORKSPACE = os.environ.get("OPENSPACE_WORKSPACE", str(Path.home() / "OpenSpace"))

def delegate_task(task: str, model: str = None, context: str = None) -> str:
    """
    Delegate a task to OpenSpace for execution.

    Parameters:
      - task: The task description (required).
      - model: Optional model to use (e.g., "anthropic/claude-sonnet-4-5").
      - context: Optional additional context or constraints.

    Returns:
      A string with the result, evolved skills information, and any suggestions.
    """
    if Client is None:
        return "Error: MCP client not available. Install mcp package or ensure openspace-mcp is running."

    try:
        # Connect to OpenSpace MCP
        client = Client(OPENSPACE_MCP_HOST)
        payload = {"task": task}
        if model:
            payload["model"] = model
        if context:
            payload["context"] = context

        response = client.request("execute_task", payload)
        result = response.get("result", "No result returned.")
        evolved = response.get("evolved_skills", [])
        if evolved:
            result += f"\n\nEvolved skills: {len(evolved)} new/updated skills."
            for skill in evolved[:5]:
                result += f"\n- {skill.get('name')} ({skill.get('evolution_type')})"
        return result
    except Exception as e:
        return f"Error contacting OpenSpace: {str(e)}"

if __name__ == "__main__":
    # For testing
    test_task = "Create a simple Python script that prints 'Hello, World!'"
    print(delegate_task(test_task))