# Antigravity RISC-V Processor (With Agentic Dashboard)

Welcome to the Antigravity RISC-V Processor! 

If you are a five-year-old (or just someone who wants things explained simply), imagine you have a very fast, very smart robot brain (the RISC-V processor) that can do lots of math super quickly. But this isn't just any robot brain - it comes with a team of tiny helper robots (AI Agents) that constantly monitor, test, and improve the brain while it works.

## What is this?
This project is a 1 GHz, 64-bit Processor designed to do heavy lifting. But the coolest part is the Agentic Framework:
- The Brain: A custom-built, super-fast processor (`rtl/`).
- The Dashboard: A beautiful web page that shows you exactly what the processor is doing in real-time.
- The AI Agents: Smart scripts that run in the background, check for errors, run tests, and report everything to the dashboard!

## How to use it

1. Start the Helper Robots (Agents):
   Open your terminal and tell the main robot boss to start working:
   ```bash
   python3 company_agents/orchestrator.py
   ```
   This starts the AI Agents. They will begin checking the code and running tests.

2. Start the Dashboard:
   Open another terminal and start the web server so you can see what is happening:
   ```bash
   python3 company_agents/monitor_server.py
   ```

3. View the Dashboard:
   Open your web browser and go to: http://localhost:8000
   You will see a beautiful screen showing:
   - What the agents are doing right now.
   - A log of all their activity.
   - Comprehensive metrics about how fast and small the processor is.

## Want to learn more?
If you are an engineer or just want to see the complicated stuff, check out the:
**[Technical Reference Manual](docs/TECHNICAL_REFERENCE.md)**

---
*Created by the Antigravity Team.*
