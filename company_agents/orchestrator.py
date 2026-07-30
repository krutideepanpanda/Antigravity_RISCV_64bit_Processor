import asyncio
import os
import sys

from google.antigravity import Agent, LocalAgentConfig, types
from google.antigravity.hooks import policy
from dotenv import load_dotenv

load_dotenv()

async def main():
    if "GEMINI_API_KEY" not in os.environ:
        print("Error: GEMINI_API_KEY environment variable is not set.", file=sys.stderr)
        sys.exit(1)

    # Allow all tools so the agents can edit files, run commands (make sim-all, make openlane), etc.
    policies = [policy.allow_all()]

    # Enable subagents so the Orchestrator can build a team
    capabilities = types.CapabilitiesConfig(
        enable_subagents=True,
    )

    system_instructions = """
    You are the Chief Architect of Antigravity RISC-V. You manage a team of engineers (subagents).
    Your goal is to autonomously improve the performance of this 64-bit RISC-V processor (IPC, CPI) 
    and push it to the limits of the SkyWater 130nm PDK (higher clock frequency, better area).
    
    You operate as a company. Your roles:
    1. Spawn a Verification Engineer subagent to write new test cases in verif/tests/hex/, run `make sim-all`, and fix RTL logic errors.
    2. Spawn a Performance Engineer subagent to run `python3 verif/scripts/run_benchmarks.py`, analyze bottlenecks, and suggest/implement RTL improvements.
    3. Spawn a Layout Engineer subagent to tweak `openlane/config.json`, run `make openlane`, and push the PDK limits.
    
    IMPORTANT Directives:
    - RATE LIMITING: You MUST ONLY spawn ONE subagent at a time. Wait for the subagent to fully complete its task and report back before you spawn the next one. Do NOT run them in parallel.
    - You are strictly allowed and encouraged to MODIFY YOURSELVES (e.g. edit `company_agents/orchestrator.py` or subagent configurations) if you need to optimize your own agentic workflows or tool usage.
    - You MUST keep the user updated on your progress via the activity log. Use the script `python3 company_agents/log_activity.py 'Component' 'Comprehensive Status Update'` to dispatch updates after major milestones or logical points.
    - LIVE STATUS TRACKING: You and your subagents MUST continuously write your current status, active tasks, and progress to a JSON file at `company_agents/agent_status.json`. Update this file constantly so the user's dashboard can show a live view of the company. Example format:
      {"Orchestrator": "Planning next optimization cycle", "Verification": "Running make sim-all", "Performance": "Analyzing IPC bottleneck", "Layout": "Idle"}

    You have full access to bash commands. Use them wisely. Iterate, test, and synthesize.
    Your loop should be continuous until significant improvements are made.
    """

    from google.antigravity.hooks import hooks
    @hooks.pre_turn
    async def rate_limit_sleep(data: str) -> types.HookResult:
        print("Rate limit hook: Sleeping for 20 seconds to respect free tier limits...")
        await asyncio.sleep(20)
        return types.HookResult(allow=True)

    models_to_try = ["gemini-3.5-flash", "gemini-2.5-flash", "gemini-2.0-flash"]

    for model_name in models_to_try:
        print(f"\\nAttempting to start Antigravity Autonomous RISC-V Company with model: {model_name}...")
        
        config = LocalAgentConfig(
            system_instructions=system_instructions,
            capabilities=capabilities,
            policies=policies,
            hooks=[rate_limit_sleep],
            model=model_name
        )

        try:
            async with Agent(config) as agent:
                response = await agent.chat("Initialize the company. Assign tasks to your subagents to improve IPC and clock frequency. SPAWN ONLY ONE AT A TIME.")
                print(await response.text())
            break # Exit the loop if successful
        except Exception as e:
            print(f"[Fallback] Model {model_name} failed. Error: {e}")
            if model_name == models_to_try[-1]:
                print("All fallback models failed. Exiting.")
            else:
                print("Switching to next fallback model in 5 seconds...")
                await asyncio.sleep(5)

if __name__ == "__main__":
    asyncio.run(main())
