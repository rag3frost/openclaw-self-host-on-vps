# OpenSpace Task Delegation

This skill lets me delegate complex tasks to the OpenSpace engine. OpenSpace provides a self-evolving execution environment that learns from failures and successes, continuously improves its skills, and can share improvements with a cloud community.

## Usage

When you give me a complex task that would benefit from OpenSpace's evolving skill library, I will invoke this skill to run:

```
openspace --query "<your task>"
```

OpenSpace will then:
- Search its local skill database (and optionally the cloud) for relevant skills
- Execute the task using a grounding agent with full tool access
- Record the execution, fix any issues automatically, and evolve new or improved skills
- Return the result

I will report back:
- The final response/output
- Any new or evolved skills that were created
- Potential upload opportunities (if cloud API key is set)

## Requirements

- The `openspace-mcp` Python package must be installed (or the `openspace` CLI available).
- The OpenSpace workspace should be initialized (` OPENSPACE_WORKSPACE` environment variable, default `~/OpenSpace`).

## Example Interaction

User: "Create a monitoring dashboard for my Docker containers"
Me: (uses openspace-task skill)
Result: A full dashboard with code, instructions, and possibly evolved skills for Docker monitoring.

## Notes

- Tasks may take several minutes for complex multi-step work.
- This skill enhances my capabilities by leveraging a collective intelligence that improves over time.
- If you have an OpenSpace API key, skill evolution can contribute to the community.