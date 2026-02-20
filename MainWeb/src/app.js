document.addEventListener("DOMContentLoaded", () => {
    const consoleTab = document.getElementById("consoleTab");
    const editorTab = document.getElementById("editorTab");
    const terminalContainer = document.getElementById("terminal-container");
    const sleepOverlay = document.getElementById("sleepOverlay");
    const projectSelect = document.getElementById("projectSelect");
    const statusBar = document.getElementById("statusBar");
    const fileList = document.getElementById("fileList");

    let editorInstance = null;
    require(['vs/editor/editor.main'], function () {
        editorInstance = monaco.editor.create(document.getElementById('editor'), {
            value: '',
            language: 'csharp',
            theme: 'vs-dark',
            automaticLayout: true
        });
        window.editorInstance = editorInstance;
    });

    let currentMarkers = [];

    const newProjectModal = document.getElementById("newProjectModal");
    const createProjectBtn = document.getElementById("createProjectBtn");
    const cancelProjectBtn = document.getElementById("cancelProjectBtn");

    const newFileModal = document.getElementById("newFileModal");
    const createFileBtn = document.getElementById("createFileBtn");
    const cancelFileBtn = document.getElementById("cancelFileBtn");

    let isSleeping = false;
    let failCount = 0;
    const maxFail = 5;
    let currentFilePath = "";

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

            // 再次确认执行
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
    document.getElementById("restartBtn").addEventListener("click", function () { systemAction("restart") });
    document.getElementById("closeBtn").addEventListener("click", function () { systemAction("close") });


    // --- 状态栏 ---
    function viewStatus(text, color = "white") {
        statusBar.style.color = color;
        statusBar.innerText = text;
    }
    // Removed global enter key listener since Xterm handles inputs.

    // --- 选项卡 ---
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

    function viewStatus(text, color = "white") {
        statusBar.style.color = color;
        statusBar.innerText = text;
    }

    viewStatus("Welcome", "green");

    // --- 控制台 ---
    let current_dir = ".";
    let absolute_dir = "";
    let terminalInput = "";

    const term = new Terminal({
        cursorBlink: true,
        fontFamily: 'monospace',
        theme: {
            background: '#000000'
        }
    });
    const fitAddon = new FitAddon.FitAddon();
    window.fitAddon = fitAddon;
    term.loadAddon(fitAddon);
    term.open(terminalContainer);
    fitAddon.fit();

    window.addEventListener('resize', () => {
        fitAddon.fit();
    });

    function prompt() {
        term.write(`\r\n\x1b[32m${current_dir}\x1b[0m $ `);
    }

    term.writeln('Welcome to MainWeb Terminal.');

    // 初始化获取当前后端所处的目录
    fetch(`/terminal?action=poll`)
        .then(res => res.json().then(data => ({ ...data, status: res.status })))
        .then(({ status, map }) => {
            if (status === 200 && map) {
                if (map.path !== undefined && map.path !== "") {
                    current_dir = map.path;
                }
                if (map.absolute_path !== undefined && map.absolute_path !== "") {
                    absolute_dir = map.absolute_path;
                }
            }
            prompt();
        })
        .catch(() => {
            prompt();
        });

    term.onData(e => {
        if (polling) return; // Ignore input while command is running

        switch (e) {
            case '\r': // Enter
                if (terminalInput.trim().length > 0) {
                    term.write('\r\n');
                    startCommand(terminalInput.trim());
                } else {
                    prompt();
                }
                terminalInput = "";
                break;
            case '\x7F': // Backspace
                if (terminalInput.length > 0) {
                    term.write('\b \b');
                    terminalInput = terminalInput.substring(0, terminalInput.length - 1);
                }
                break;
            case '\t': // Tab
                if (terminalInput.length > 0) {
                    fetch(`/terminal?action=autocomplete&input=${encodeURIComponent(terminalInput)}`)
                        .then(res => res.json())
                        .then(res => {
                            if (res.Status === 200 && res.Map) {
                                if (res.Map.addition) {
                                    terminalInput += res.Map.addition;
                                    term.write(res.Map.addition);
                                }
                                if (res.Map.isMultiple === "true" && res.Map.matches) {
                                    const matches = JSON.parse(res.Map.matches);
                                    term.write('\r\n' + matches.join('  '));
                                    prompt();
                                    term.write(terminalInput);
                                }
                            }
                        })
                        .catch(err => console.error("Autocomplete error:", err));
                }
                break;
            default: // Print all other characters
                if (e >= String.fromCharCode(0x20) && e <= String.fromCharCode(0x7E) || e >= '\u00a0') {
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
            if (window.editorInstance) {
                monaco.editor.setModelMarkers(window.editorInstance.getModel(), "csharp", []);
            }
        }

        fetch(`/terminal?action=start&cmd=${encodeURIComponent(cmd)}`)
            .then(res => res.json().then(data => ({ ...data, status: res.status })))
            .then(({ status, message, map }) => {
                if (status === 200) {
                    if (map.path !== undefined && map.path !== "") {
                        current_dir = map.path;
                    }
                    if (map.absolute_path !== undefined && map.absolute_path !== "") {
                        absolute_dir = map.absolute_path;
                    }
                    if (map.running === "0") {
                        prompt();
                    } else {
                        polling = true;
                        pollStartTime = Date.now();
                        pollOutput();
                    }
                } else {
                    term.write(`\r\n\x1b[31m${message}\x1b[0m`);
                    prompt();
                }
            })
            .catch(err => {
                term.write(`\r\n\x1b[31mStart command failed: ${err}\x1b[0m`);
                prompt();
            });
    }


    function pollOutput() {
        if (!polling) return;
        // 超时检查
        if (Date.now() - pollStartTime > pollTimeout) {
            term.write(`\r\n\x1b[31mTerminal command timed out\x1b[0m`);
            polling = false;
            prompt();
            return;
        }

        fetch(`/terminal?action=poll`)
            .then(res => res.json().then(data => ({ ...data, status: res.status })))
            .then(({ status, message, map }) => {
                if (status === 200) {
                    if (map.out) {
                        term.write(map.out.replace(/\n/g, '\r\n'));
                    }
                    if (map.err) {
                        let errLines = map.err.split('\n');
                        errLines.forEach(line => {
                            if (line) {
                                term.write(`\x1b[31m${line}\x1b[0m\r\n`);
                            }
                        });
                    }

                    parseAndRenderErrors(map.out + "\n" + map.err);

                    if (map.running === "1") {
                        viewStatus("Terminal is running...", "orange");
                        setTimeout(pollOutput, 100); // 100 ms poll
                    } else {
                        viewStatus("Please input command", "green");
                        polling = false;
                        prompt();
                    }
                } else {
                    term.write(`\r\n\x1b[31m${message}\x1b[0m`);
                    polling = false;
                    prompt();
                }
            })
            .catch(err => {
                polling = false;
                term.write(`\r\n\x1b[31mPoll failed : ${err}\x1b[0m`);
                prompt();
            });
    }

    function parseAndRenderErrors(output) {
        if (!output || !window.editorInstance) return;

        // 匹配 C# 编译错误格式，例如：
        // Program.cs(10,15): error CS1002: ; expected [/project/path.csproj]
        // 匹配组: [1]文件路径, [2]行号, [3]列号, [4]类型(error/warning), [5]错误码, [6]信息
        const regex = /([^\s\(\)]+)\((\d+),(\d+)\):\s+(error|warning)\s+([A-Z0-9]+):\s+(.+?)\s+\[/g;

        let match;
        let markersUpdated = false;

        while ((match = regex.exec(output)) !== null) {
            const filePath = match[1];
            const line = parseInt(match[2], 10);
            const col = parseInt(match[3], 10);
            const severityStr = match[4];
            const errorCode = match[5];
            const errorMsg = match[6];

            // 简单判断报错的文件路径是否包含当前打开的文件相对路径
            if (currentFilePath && filePath.replace(/\\/g, '/').endsWith(currentFilePath.replace(/\\/g, '/'))) {
                const severity = severityStr === "error" ? monaco.MarkerSeverity.Error : monaco.MarkerSeverity.Warning;

                currentMarkers.push({
                    severity: severity,
                    message: `[${errorCode}] ${errorMsg}`,
                    startLineNumber: line,
                    startColumn: col,
                    endLineNumber: line,
                    endColumn: col + 1
                });
                markersUpdated = true;
            }
        }

        if (markersUpdated) {
            monaco.editor.setModelMarkers(window.editorInstance.getModel(), "csharp", currentMarkers);
        }
    }

    // --- 编辑器按钮 ---
    document.getElementById("refreshBtn").addEventListener("click", () => readFile());
    document.getElementById("saveBtn").addEventListener("click", () => writeFile());

    // --- 项目管理 ---
    function refreshProjectList() {
        fetch("/project?action=projects")
            .then(res => res.json().then(data => ({ ...data, status: res.status })))
            .then(({ status, message, map }) => {
                viewStatus(message, status == 200 ? "green" : "red");
                while (projectSelect.firstChild) projectSelect.removeChild(projectSelect.firstChild);
                // 添加项目
                Object.keys(map).forEach(item => {
                    const option = document.createElement("option");
                    option.textContent = item;
                    option.value = item;
                    projectSelect.appendChild(option);
                });
                const add = document.createElement("option");
                add.textContent = "+";
                add.value = "create_project";
                projectSelect.appendChild(add);
                listProjectFiles();
            })
            .catch(err => viewStatus(`Get project list failed :${err}`, "red"));
    }

    function listProjectFiles() {
        const projectName = projectSelect.value;
        if (projectName == "create_project") {
            newProjectModal.style.display = "flex";
            return
        }
        cleanEditor();
        fetch(`/project?action=list&project=${projectName}`)
            .then(res => res.json().then(data => ({ ...data, status: res.status })))
            .then(({ status, message, map }) => {
                viewStatus(message, status == 200 ? "green" : "red");
                while (fileList.firstChild) fileList.removeChild(fileList.firstChild);
                Object.entries(map).forEach(([key, value]) => {
                    if (value == "File") {
                        const div = document.createElement("div");
                        div.innerHTML = key;
                        div.addEventListener("click", function () {
                            currentFilePath = key;
                            readFile();
                        });
                        fileList.appendChild(div);
                    }
                });
                const add = document.createElement("div");
                add.innerHTML = "+";
                add.addEventListener("click", function () {
                    newFileModal.style.display = "flex";
                });
                fileList.appendChild(add);
            })
            .catch(err => viewStatus(`Get files list failed :${err}`, "red"));
    }
    projectSelect.addEventListener("change", () => listProjectFiles());

    function cleanEditor() {
        if (window.editorInstance) {
            window.editorInstance.setValue("");
            monaco.editor.setModelMarkers(window.editorInstance.getModel(), "csharp", []);
            currentMarkers = [];
        }
    }

    function readFile() {
        const projectName = projectSelect.value;
        fetch(`/project?action=read_file&path=${currentFilePath}&project=${projectName}`)
            .then(res => res.json().then(data => ({ ...data, status: res.status })))
            .then(({ status, message, map }) => {
                viewStatus(`${message}: ${map.file}`, status == 200 ? "green" : "red");
                cleanEditor();
                if (window.editorInstance) {
                    window.editorInstance.setValue(map.content);
                }
            })
            .catch(err => viewStatus(`Read file failed : ${err}`, "red"));
    }

    function writeFile() {
        const projectName = projectSelect.value;
        const content = window.editorInstance ? window.editorInstance.getValue() : "";
        fetch(`/project?action=write_file&path=${currentFilePath}&project=${projectName}`, {
            method: "POST",
            headers: {
                "Content-Type": "text/plain; charset=UTF-8"
            },
            body: content
        })
            .then(res => res.json().then(data => ({ ...data, status: res.status })))
            .then(({ status, message }) => {
                viewStatus(message, status === 200 ? "green" : "red");
            })
            .catch(err => viewStatus(`Write file failed: ${err}`, "red"));
    }

    createProjectBtn.addEventListener("click", () => {
        const projectType = document.getElementById("projectType").value;
        const projectName = document.getElementById("projectName").value;
        viewStatus(`Create project : ${projectType} ${projectName}`);
    });
    cancelProjectBtn.addEventListener("click", function () {
        newProjectModal.style.display = "none";
        document.getElementById("projectName").value = "";
    });


    createFileBtn.addEventListener("click", () => {
        const fileType = document.getElementById("fileType").value;
        const filePath = document.getElementById("filePath").value;
        viewStatus(`Create file : ${fileType} ${filePath}`);
    });
    cancelFileBtn.addEventListener("click", function () {
        newFileModal.style.display = "none";
        document.getElementById("filePath").value = "";
    });

    // --- 休眠控制 ---
    function enterSleep() {
        sleepOverlay.style.display = "flex";
        if (window.editorInstance) {
            window.editorInstance.updateOptions({ readOnly: true });
        }
        if (typeof term !== 'undefined') {
            term.options.disableStdin = true;
            term.options.cursorBlink = false;
        }
    }

    function exitSleep() {
        sleepOverlay.style.display = "none";
        if (window.editorInstance) {
            window.editorInstance.updateOptions({ readOnly: false });
        }
        if (typeof term !== 'undefined') {
            term.options.disableStdin = false;
            term.options.cursorBlink = true;
        }
    }

    // --- 心跳机制 ---
    function sendHeartbeat() {
        fetch("/heartbeat")
            .then(res => res.text())
            .then(text => {
                if (text.trim() === "OK") {
                    failCount = 0;
                    exitSleep();
                } else {
                    failCount++;
                    if (failCount >= maxFail) enterSleep();
                }
            })
            .catch(err => {
                failCount++;
                if (failCount >= maxFail) enterSleep();
            });
    }

    // 初始化
    refreshProjectList();
    viewStatus("Welcome", "green");
    exitSleep();
    setInterval(sendHeartbeat, 3000);
});
