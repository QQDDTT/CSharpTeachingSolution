document.addEventListener("DOMContentLoaded", () => {
    const consoleTab = document.getElementById("consoleTab");
    const editorTab = document.getElementById("editorTab");
    const consoleInput = document.getElementById("consoleInput");
    const consoleOutput = document.getElementById("consoleOutput");
    const sleepOverlay = document.getElementById("sleepOverlay");
    const projectSelect = document.getElementById("projectSelect");
    const statusBar = document.getElementById("statusBar");
    const fileList = document.getElementById("fileList");


    const editor = document.getElementById("editor");

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
    document.getElementById("restartBtn").addEventListener("click", function() {systemAction("restart")});
    document.getElementById("closeBtn").addEventListener("click", function() {systemAction("close")});
    

    // --- 状态栏 ---
    function viewStatus(text, color = "white") {
        statusBar.style.color = color;
        statusBar.innerText = text;
    }
    document.addEventListener("keydown", (event) => {
        if (event.key === "Enter") {
            if (consoleTab.classList.contains("active"))
                startCommand();
        }
    });

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
        });
    });

    function viewStatus(text, color = "white") {
        statusBar.style.color = color;
        statusBar.innerText = text;
    }

    viewStatus("Welcome", "green");

    // --- 控制台 ---
    let current_dir = "."

    function appendConsole(text, type = "out") {
        const div = document.createElement("div");
        div.textContent = text;
        div.style.color = type === "err" ? "red" : "#0f0";
        consoleOutput.appendChild(div);
        consoleOutput.scrollTop = consoleOutput.scrollHeight;
    }

    document.getElementById("sendConsoleBtn").addEventListener("click", () => {
        startCommand();
    });

    let polling = false;
    let pollStartTime = 0;
    const pollTimeout = 30000;

    function startCommand() {
        const cmd = consoleInput.value.trim();
        if (!cmd) return;
        appendConsole(`~${current_dir} > ${cmd}`);

        fetch(`/terminal?action=start&cmd=${encodeURIComponent(cmd)}`)
            .then(res => res.json().then(data => ({ ...data, status: res.status })))
            .then(({ status, message, map }) => {
                if (status === 200) {
                    if (map.path == undefined || map.path == "") {current_dir == ".";}
                    else {current_dir = map.path;}
                    consoleInput.value = "";
                    polling = true;
                    pollStartTime = Date.now();
                    pollOutput();
                } else {
                    viewStatus(message, "red");
                }
            })
            .catch(err => console.error(`Start command failed: ${err}`, "red"));
    }


    function pollOutput() {
        if (!polling) return;
        // 超时检查
        if (Date.now() - pollStartTime > pollTimeout) {
            viewStatus("Terminal command timed out", "red");
            polling = false;
            return;
        }

        fetch(`/terminal?action=poll`)
            .then(res => res.json().then(data => ({ ...data, status: res.status })))
            .then(({ status, message, map }) => {
                if (status === 200) {
                    if (map.out) map.out.split("\n").forEach(line => line && appendConsole(line, "out"));
                    if (map.err) map.err.split("\n").forEach(line => line && appendConsole(line, "err"));
                    if (map.running === "1") {
                        viewStatus("Terminal is running...", "orange");
                        setTimeout(pollOutput, 100); // 0.1 秒轮询
                    } else {
                        viewStatus("Please input command", "green");
                        polling = false;
                    }
                } else {
                    viewStatus(message, "red");
                }
            })
            .catch(err => {
                // 遇到错误也停止轮询，避免无限报错
                polling = false;
                viewStatus(`Poll failed : ${err}`, "red");
            });
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
                        div.addEventListener("click", function() {
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
            .catch (err => viewStatus(`Get files list failed :${err}`, "red"));
    }
    projectSelect.addEventListener("change", () => listProjectFiles());

    function cleanEditor() {
        editor.innerHTML = "";
    }

    function readFile() {
        const projectName = projectSelect.value;
        fetch(`/project?action=read_file&path=${currentFilePath}&project=${projectName}`)
            .then(res => res.json().then(data => ({ ...data, status: res.status })))
            .then(({ status, message, map }) => {
                viewStatus(`${message}: ${map.file}`, status == 200 ? "green" : "red");
                cleanEditor();
                editor.value = map.content;
            })
            .catch (err => viewStatus(`Read file failed : ${err}`, "red"));
    }

    function writeFile() {
        const projectName = projectSelect.value;
        const content = editor.value;
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
    cancelProjectBtn.addEventListener("click", function(){
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
        editor.contentEditable = "false";
    }

    function exitSleep() {
        sleepOverlay.style.display = "none";
        editor.contentEditable = "true";
    }

    // --- 心跳机制 ---
    function sendHeartbeat() {
        fetch("/heartbeat")
            .then(res => res.text())
            .then(text => {
                if(text.trim() === "OK") {
                    failCount = 0;
                    exitSleep();
                } else {
                    failCount++;
                    if(failCount >= maxFail) enterSleep();
                }
            })
            .catch(err => {
                failCount++;
                if(failCount >= maxFail) enterSleep();
            });
    }

    // 初始化
    refreshProjectList();
    viewStatus("Welcome", "green");
    exitSleep();
    setInterval(sendHeartbeat, 3000);
});
