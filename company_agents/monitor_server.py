import http.server
import socketserver
import os
import json
import urllib.parse

PORT = 8000
LOG_FILE = "company_agents/activity.log"
STATUS_FILE = "company_agents/agent_status.json"
METRICS_FILE = "company_agents/processor_metrics.json"

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Autonomous RISC-V Company Dashboard</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap');
        
        :root {
            --bg-color: #0f172a;
            --text-color: #f8fafc;
            --card-bg: rgba(30, 41, 59, 0.65);
            --card-border: rgba(255, 255, 255, 0.08);
            --accent: #38bdf8;
            --success: #10b981;
            --warning: #f59e0b;
            --glow: 0 0 20px rgba(56, 189, 248, 0.4);
        }
        body { 
            font-family: 'Outfit', -apple-system, BlinkMacSystemFont, sans-serif; 
            margin: 0; 
            padding: 40px 20px; 
            background: linear-gradient(135deg, #0f172a 0%, #1e1b4b 100%);
            background-attachment: fixed;
            color: var(--text-color);
            min-height: 100vh;
        }
        h1 { 
            text-align: center; 
            font-weight: 700; 
            font-size: 2.5rem;
            letter-spacing: -1px; 
            margin-bottom: 50px;
            background: linear-gradient(to right, #38bdf8, #818cf8);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            text-shadow: var(--glow);
        }
        .dashboard {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 30px;
            max-width: 1400px;
            margin: 0 auto;
        }
        .card { 
            background: var(--card-bg); 
            backdrop-filter: blur(16px);
            -webkit-backdrop-filter: blur(16px);
            padding: 30px; 
            border-radius: 20px; 
            border: 1px solid var(--card-border);
            box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.3);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
        }
        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 12px 40px 0 rgba(0, 0, 0, 0.4), 0 0 20px rgba(56, 189, 248, 0.1);
            border: 1px solid rgba(255, 255, 255, 0.15);
        }
        .card h2 {
            margin-top: 0;
            font-size: 1.4rem;
            font-weight: 600;
            color: var(--text-color);
            border-bottom: 1px solid rgba(255,255,255,0.1);
            padding-bottom: 15px;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .agent-status {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            padding: 14px 0;
            border-bottom: 1px solid rgba(255,255,255,0.05);
            transition: background 0.2s ease;
        }
        .agent-status:hover {
            background: rgba(255,255,255,0.02);
            border-radius: 8px;
            padding-left: 10px;
            padding-right: 10px;
            margin-left: -10px;
            margin-right: -10px;
        }
        .agent-status:last-child { border-bottom: none; }
        .agent-name { font-weight: 500; font-size: 1.05rem; color: #cbd5e1; }
        .agent-task { color: var(--accent); font-size: 0.95rem; text-align: right; max-width: 60%; font-weight: 500; }
        
        .pulse {
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            background: var(--success);
            box-shadow: 0 0 12px var(--success);
            margin-right: 15px;
            animation: pulse 2s infinite;
            vertical-align: middle;
        }
        
        @keyframes pulse {
            0% { box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7); }
            70% { box-shadow: 0 0 0 15px rgba(16, 185, 129, 0); }
            100% { box-shadow: 0 0 0 0 rgba(16, 185, 129, 0); }
        }

        .log-container { 
            white-space: pre-wrap; 
            font-family: 'JetBrains Mono', monospace;
            font-size: 0.85rem;
            line-height: 1.5;
            color: #94a3b8;
            max-height: 500px;
            overflow-y: auto;
            background: rgba(15, 23, 42, 0.8);
            padding: 20px;
            border-radius: 12px;
            border: 1px solid rgba(255,255,255,0.05);
            box-shadow: inset 0 2px 10px rgba(0,0,0,0.5);
        }
        
        /* Custom Scrollbar */
        ::-webkit-scrollbar { width: 8px; }
        ::-webkit-scrollbar-track { background: rgba(0, 0, 0, 0.2); border-radius: 8px; }
        ::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.1); border-radius: 8px; }
        ::-webkit-scrollbar-thumb:hover { background: rgba(255, 255, 255, 0.2); }
    </style>
</head>
<body>
    <h1><span class="pulse"></span> Autonomous RISC-V Company Dashboard</h1>
    
    <div class="dashboard">
        <div class="card">
            <h2>Live Agent Status</h2>
            <div id="status-container">Loading status...</div>
        </div>
        
        <div class="card">
            <h2>Comprehensive Activity Log</h2>
            <div class="log-container" id="log-container">Loading activity log...</div>
        </div>
        
        <div class="card">
            <h2>Processor Metrics</h2>
            <div id="metrics-container" style="display: flex; flex-direction: column;">Loading metrics...</div>
        </div>
    </div>

    <script>
        async function fetchStatus() {
            try {
                const res = await fetch('/status');
                const text = await res.text();
                const data = JSON.parse(text);
                let html = '';
                
                if (Object.keys(data).length === 0) {
                    html = '<div style="color: #94a3b8; font-style: italic;">Agents are starting up or have not reported status yet...</div>';
                } else {
                    for (const [agent, task] of Object.entries(data)) {
                        html += `
                            <div class="agent-status">
                                <div class="agent-name">${agent}</div>
                                <div class="agent-task">${task}</div>
                            </div>
                        `;
                    }
                }
                document.getElementById('status-container').innerHTML = html;
            } catch (e) {
                document.getElementById('status-container').innerHTML = '<div style="color: #ef4444;">Waiting for agent status file...</div>';
            }
        }

        async function fetchActivity() {
            try {
                const res = await fetch('/activity');
                let text = await res.text();
                text = text.replace(/</g, '&lt;').replace(/>/g, '&gt;');
                const container = document.getElementById('log-container');
                const isScrolledToBottom = container.scrollHeight - container.clientHeight <= container.scrollTop + 1;
                
                container.innerHTML = text || 'No activity logged yet.';
                
                if (isScrolledToBottom) {
                    container.scrollTop = container.scrollHeight;
                }
            } catch (e) {
                document.getElementById('log-container').innerHTML = '<span style="color: #ef4444;">Error fetching activity log.</span>';
            }
        }

        async function fetchMetrics() {
            try {
                const res = await fetch('/metrics');
                const text = await res.text();
                const data = JSON.parse(text);
                let html = '';
                
                if (Object.keys(data).length === 0) {
                    html = '<div style="color: #94a3b8; font-style: italic;">No metrics available...</div>';
                } else {
                    for (const [key, value] of Object.entries(data)) {
                        html += `
                            <div class="agent-status" style="justify-content: flex-start; gap: 20px; align-items: flex-start;">
                                <div class="agent-name" style="min-width: 200px;">${key}</div>
                                <div class="agent-task" style="color: var(--success); text-align: left; word-break: break-word; max-width: 100%;">${value}</div>
                            </div>
                        `;
                    }
                }
                document.getElementById('metrics-container').innerHTML = html;
            } catch (e) {
                document.getElementById('metrics-container').innerHTML = '<div style="color: #ef4444;">Waiting for metrics file...</div>';
            }
        }

        function poll() {
            fetchStatus();
            fetchActivity();
            fetchMetrics();
        }

        poll();
        setInterval(poll, 2000);
    </script>
</body>
</html>
"""

class MonitorHandler(http.server.SimpleHTTPRequestHandler):
    def get_file_path(self, target_file):
        log_path = target_file
        if not os.path.exists(log_path):
            basename = os.path.basename(target_file)
            if os.path.exists(basename):
                log_path = basename
        return log_path

    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            self.wfile.write(HTML_TEMPLATE.encode("utf-8"))
        elif self.path == '/status':
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            
            path = self.get_file_path(STATUS_FILE)
            try:
                with open(path, 'r') as f:
                    content = f.read()
            except FileNotFoundError:
                content = "{}"
            
            self.wfile.write(content.encode("utf-8"))
        elif self.path == '/activity':
            self.send_response(200)
            self.send_header("Content-type", "text/plain")
            self.end_headers()
            
            path = self.get_file_path(LOG_FILE)
            try:
                with open(path, 'r') as f:
                    content = f.read()
            except FileNotFoundError:
                content = ""
            self.wfile.write(content.encode("utf-8"))
        elif self.path == '/metrics':
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            
            path = self.get_file_path(METRICS_FILE)
            try:
                with open(path, 'r') as f:
                    content = f.read()
            except FileNotFoundError:
                content = "{}"
            self.wfile.write(content.encode("utf-8"))
        else:
            super().do_GET()

if __name__ == "__main__":
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), MonitorHandler) as httpd:
        print(f"Starting monitoring server at http://localhost:{PORT}")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\\nShutting down server.")
