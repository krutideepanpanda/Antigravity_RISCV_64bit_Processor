#!/usr/bin/env python3
import sys
import datetime

def log_activity(component, message):
    log_path = "company_agents/activity.log"
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    log_content = f"[{timestamp}] [COMPONENT: {component}]\n{message}\n{'-'*60}\n"
    with open(log_path, "a") as f:
        f.write(log_content)
    
    print(f"Comprehensive activity successfully logged for {component}.")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: ./log_activity.py 'Component' 'Comprehensive Status Update'")
        sys.exit(1)
    log_activity(sys.argv[1], sys.argv[2])
