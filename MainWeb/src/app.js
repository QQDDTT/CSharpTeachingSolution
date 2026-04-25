document.addEventListener("DOMContentLoaded", () => {
    const consoleTab = document.getElementById("consoleTab");
    const editorTab = document.getElementById("editorTab");
    const terminalContainer = document.getElementById("terminal-container");
    const sleepOverlay = document.getElementById("sleepOverlay");
    const statusBar = document.getElementById("statusBar");
    const projectSelect = document.getElementById("projectSelect");

    let editorInstance = null;
    require(['vs/editor/editor.main'], function () {
        editorInstance = monaco.editor.create(document.getElementById('editor'), {
            value: '',
            language: 'csharp',
            theme: 'vs', // 白色背景主题
            automaticLayout: true
        });
        window.editorInstance = editorInstance;
    });

    let currentMarkers = [];
    let currentProjectName = "";
    let currentFilePath = "";

    const newProjectModal = document.getElementById("newProjectModal");
    const createProjectBtn = document.getElementById("createProjectBtn");
    const cancelProjectBtn = document.getElementById("cancelProjectBtn");

    const newFileModal = document.getElementById("newFileModal");
    const createFileBtn = document.getElementById("createFileBtn");
    const cancelFileBtn = document.getElementById("cancelFileBtn");

    let isSleeping = false;
    let failCount = 0;
    const maxFail = 5;

    // --- 状态栏 ---
    function viewStatus(text, color = "white") {
        statusBar.style.color = color;
        statusBar.innerText = text;
    }

    // --- 系统操作 ---
    async function systemAction(action) {
        if (!['restart', 'close'].includes(action)) {
            viewStatus("Unknow action", "red");
            return;
        }

        const res = await fetch(`/system?action=${encodeURIComponent(action)}`);
        const data = await res.json().then(data => ({ ...data, status: res.status }));

        if (data.status === 200) {
            viewStatus(data.message, "orange");
            if (confirm(`Are you sure you want to ${action === 'restart' ? 'restart' : 'shut down'} the system now?`)) {
                await fetch(`/system?action=${encodeURIComponent(action)}&code=${encodeURIComponent(data.code)}`, {
                    method: 'POST',
                    headers: { "Content-Type": "text/plain; charset=UTF-8" }
                });
                if (action === "close") {
                    setTimeout(() => window.close(), 500);
                }
            }
        } else {
            viewStatus(data.message, "red");
        }
    }
    document.getElementById("restartBtn").addEventListener("click", () => systemAction("restart"));
    document.getElementById("closeBtn").addEventListener("click", () => systemAction("close"));

    // --- 选项卡切换 ---
    const tabs = [
        { btn: document.getElementById("consoleBtn"), content: consoleTab },
        { btn: document.getElementById("editorBtn"), content: editorTab }
    ];

    tabs.forEach(t => {
        t.btn.addEventListener("click", () => {
            tabs.forEach(x => {
                x.btn.classList.remove("active");
                x.content.classList.remove("active");
            });
            t.btn.classList.add("active");
            t.content.classList.add("active");
            if (t.content.id === "consoleTab" && window.fitAddon) {
                setTimeout(() => window.fitAddon.fit(), 10);
            }
        });
    });

    // --- 控制台 (Terminal) ---
    let current_dir = ".";
    let absolute_dir = "";
    let terminalInput = "";

    const term = new Terminal({
        cursorBlink: true,
        fontFamily: 'monospace',
        theme: { background: '#000000' }
    });
    const fitAddon = new FitAddon.FitAddon();
    window.fitAddon = fitAddon;
    term.loadAddon(fitAddon);
    term.open(terminalContainer);
    fitAddon.fit();

    window.addEventListener('resize', () => fitAddon.fit());

    function prompt() {
        term.write(`\r\n\x1b[32m${current_dir}\x1b[0m $ `);
    }

    term.writeln('Welcome to MainWeb Terminal.');

    fetch(`/terminal?action=poll`)
        .then(res => res.json())
        .then(data => {
            if (data.Map) {
                if (data.Map.path) current_dir = data.Map.path;
                if (data.Map.absolute_path) absolute_dir = data.Map.absolute_path;
            }
            prompt();
        }).catch(() => prompt());

    term.onData(e => {
        if (polling) return;
        switch (e) {
            case '\r':
                if (terminalInput.trim().length > 0) {
                    term.write('\r\n');
                    startCommand(terminalInput.trim());
                } else prompt();
                terminalInput = "";
                break;
            case '\x7F':
                if (terminalInput.length > 0) {
                    term.write('\b \b');
                    terminalInput = terminalInput.substring(0, terminalInput.length - 1);
                }
                break;
            default:
                if (e >= ' ' && e <= '~' || e >= '\u00a0') {
                    terminalInput += e;
                    term.write(e);
                }
                break;
        }
    });

    let polling = false;
    let pollStartTime = 0;
    const pollTimeout = 30000;

    function startCommand(cmd) {
        if (!cmd) return;
        if (cmd.startsWith("dotnet build") || cmd.startsWith("dotnet run")) {
            currentMarkers = [];
            if (window.editorInstance) monaco.editor.setModelMarkers(window.editorInstance.getModel(), "csharp", []);
        }

        fetch(`/terminal?action=start&cmd=${encodeURIComponent(cmd)}`)
            .then(res => res.json())
            .then(data => {
                if (data.Status === 200) {
                    if (data.Map.path) current_dir = data.Map.path;
                    if (data.Map.running === "1") {
                        polling = true;
                        pollStartTime = Date.now();
                        pollOutput();
                    } else prompt();
                } else {
                    term.write(`\r\n\x1b[31m${data.Message}\x1b[0m`);
                    prompt();
                }
            });
    }

    function pollOutput() {
        if (!polling || Date.now() - pollStartTime > pollTimeout) {
            if (polling) {
                term.write(`\r\n\x1b[31mTerminal command timed out\x1b[0m`);
                polling = false;
                prompt();
            }
            return;
        }

        fetch(`/terminal?action=poll`)
            .then(res => res.json())
            .then(data => {
                if (data.Status === 200) {
                    if (data.Map.out) term.write(data.Map.out.replace(/\n/g, '\r\n'));
                    if (data.Map.err) term.write(`\x1b[31m${data.Map.err.replace(/\n/g, '\r\n')}\x1b[0m`);
                    parseAndRenderErrors(data.Map.out + "\n" + data.Map.err);

                    if (data.Map.running === "1") {
                        setTimeout(pollOutput, 100);
                    } else {
                        polling = false;
                        prompt();
                    }
                }
            });
    }

    function parseAndRenderErrors(output) {
        if (!output || !window.editorInstance) return;
        const regex = /([^\s\(\)]+)\((\d+),(\d+)\):\s+(error|warning)\s+([A-Z0-9]+):\s+(.+?)\s+\[/g;
        let match;
        let markersUpdated = false;
        while ((match = regex.exec(output)) !== null) {
            const filePath = match[1];
            if (currentFilePath && filePath.replace(/\\/g, '/').endsWith(currentFilePath.replace(/\\/g, '/'))) {
                currentMarkers.push({
                    severity: match[4] === "error" ? monaco.MarkerSeverity.Error : monaco.MarkerSeverity.Warning,
                    message: `[${match[5]}] ${match[6]}`,
                    startLineNumber: parseInt(match[2]),
                    startColumn: parseInt(match[3]),
                    endLineNumber: parseInt(match[2]),
                    endColumn: parseInt(match[3]) + 1
                });
                markersUpdated = true;
            }
        }
        if (markersUpdated) monaco.editor.setModelMarkers(window.editorInstance.getModel(), "csharp", currentMarkers);
    }

    // --- 项目与树状侧边栏逻辑 ---
    function refreshProjectList() {
        fetch("/project?action=projects")
            .then(res => res.json())
            .then(res => {
                console.log("Projects response:", res);
                const map = res.map || res.Map;
                
                while (projectSelect.firstChild) projectSelect.removeChild(projectSelect.firstChild);
                
                if (map) {
                    Object.keys(map).forEach(name => {
                        const opt = document.createElement("option");
                        opt.textContent = name;
                        opt.value = name;
                        projectSelect.appendChild(opt);
                    });
                }

                if (projectSelect.value) {
                    currentProjectName = projectSelect.value;
                    listProjectFiles();
                }
            })
            .catch(err => viewStatus(`Get project list failed :${err}`, "red"));
    }

    projectSelect.addEventListener("change", () => {
        currentProjectName = projectSelect.value;
        listProjectFiles();
    });

    function buildTree(map) {
        const root = { name: "root", children: {}, type: "Dir" };
        for (const [path, type] of Object.entries(map)) {
            const parts = path.split('/');
            let current = root;
            for (let i = 0; i < parts.length; i++) {
                const part = parts[i];
                if (!current.children[part]) {
                    current.children[part] = { 
                        name: part, children: {}, 
                        type: (i === parts.length - 1) ? type : "Dir",
                        fullPath: parts.slice(0, i + 1).join('/')
                    };
                }
                current = current.children[part];
            }
        }
        return root;
    }

    function renderTree(node, container, level = 0) {
        const sorted = Object.values(node.children).sort((a,b) => (a.type === b.type ? a.name.localeCompare(b.name) : (a.type === "Dir" ? -1 : 1)));
        sorted.forEach(child => {
            const item = document.createElement("div");
            item.className = `tree-item ${child.type === "Dir" ? "tree-folder" : "tree-file"}`;
            item.style.paddingLeft = `${level * 12 + 10}px`;
            const icon = child.type === "Dir" ? "▼" : "📄";
            item.innerHTML = `<span class="tree-icon">${icon}</span> ${child.name}`;
            container.appendChild(item);

            if (child.type === "Dir") {
                const childContainer = document.createElement("div");
                childContainer.className = "tree-children";
                container.appendChild(childContainer);
                item.addEventListener("click", (e) => {
                    e.stopPropagation();
                    const collapsed = item.classList.toggle("collapsed");
                    item.querySelector(".tree-icon").innerText = collapsed ? "▶" : "▼";
                });
                renderTree(child, childContainer, level + 1);
            } else {
                item.addEventListener("click", (e) => {
                    e.stopPropagation();
                    document.querySelectorAll(".tree-file").forEach(f => f.classList.remove("active"));
                    item.classList.add("active");
                    currentFilePath = child.fullPath;
                    readFile();
                });
            }
        });
    }

    function listProjectFiles() {
        const fileTree = document.getElementById("fileTree");
        if (!currentProjectName) return;
        fileTree.innerHTML = "<div style='padding:10px; color:#666;'>Loading...</div>";
        fetch(`/project?action=list&project=${encodeURIComponent(currentProjectName)}`)
            .then(res => res.json())
            .then(res => {
                console.log("Files list response:", res);
                fileTree.innerHTML = "";
                const map = res.map || res.Map;
                const status = res.status || res.Status;
                if ((status === 200 || res.Status === 200) && map) {
                    renderTree(buildTree(map), fileTree);
                }
            });
    }

    function readFile() {
        if (!currentProjectName || !currentFilePath) return;
        const url = `/project?action=read_file&path=${encodeURIComponent(currentFilePath)}&project=${encodeURIComponent(currentProjectName)}`;
        fetch(url).then(res => res.json()).then(res => {
            console.log("Read file response:", res);
            const map = res.map || res.Map;
            const status = res.status || res.Status;
            const msg = res.message || res.Message;
            if ((status === 200 || res.Status === 200) && map) {
                if (window.editorInstance) window.editorInstance.setValue(map.content);
                viewStatus(`Read success: ${map.file}`, "green");
            }
        }).catch(err => viewStatus(`Read failed: ${err}`, "red"));
    }

    function writeFile() {
        if (!currentProjectName || !currentFilePath) return;
        const content = window.editorInstance ? window.editorInstance.getValue() : "";
        fetch(`/project?action=write_file&path=${encodeURIComponent(currentFilePath)}&project=${encodeURIComponent(currentProjectName)}`, {
            method: "POST", headers: { "Content-Type": "text/plain; charset=UTF-8" }, body: content
        }).then(res => res.json()).then(res => viewStatus(res.Message, res.Status === 200 ? "green" : "red"));
    }

    document.getElementById("refreshBtn").addEventListener("click", readFile);
    document.getElementById("saveBtn").addEventListener("click", writeFile);

    // --- 心跳与休眠 ---
    function enterSleep() {
        sleepOverlay.style.display = "flex";
        if (window.editorInstance) window.editorInstance.updateOptions({ readOnly: true });
        term.options.disableStdin = true;
    }
    function exitSleep() {
        sleepOverlay.style.display = "none";
        if (window.editorInstance) window.editorInstance.updateOptions({ readOnly: false });
        term.options.disableStdin = false;
    }
    setInterval(() => {
        fetch("/heartbeat").then(res => res.text()).then(t => (t.trim()==="OK" ? exitSleep() : enterSleep())).catch(enterSleep);
    }, 3000);

    refreshProjectList();
    exitSleep();
});
