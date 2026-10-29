import Cocoa
import Darwin

final class DownloadApp: NSObject, NSApplicationDelegate, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    var window: NSWindow!
    let urlField = LinkEditor()
    let queueView = NSTableView()
    var queue = DownloadQueue()
    let startButton = NSButton(title: "加入队列并下载", target: nil, action: nil)
    let cancelButton = NSButton(title: "暂停队列", target: nil, action: nil)
    let folderButton = NSButton(title: "更改保存位置…", target: nil, action: nil)
    let openButton = NSButton(title: "打开下载文件夹", target: nil, action: nil)
    let status = NSTextField(labelWithString: "准备就绪")
    let location = NSTextField(labelWithString: "")
    let spinner = NSProgressIndicator()
    let log = NSTextView()
    var process: Process?
    var pipe: Pipe?
    var cancelled = false
    var outputFolder: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let saved = UserDefaults.standard.string(forKey: "outputFolder") { outputFolder = URL(fileURLWithPath: saved, isDirectory: true) }
        setupMenu()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 800), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "视频下载助手"
        window.minSize = NSSize(width: 700, height: 780)
        window.delegate = self
        window.center()
        let root = NSStackView()
        root.orientation = .vertical; root.alignment = .leading; root.spacing = 10
        root.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24),
            root.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24),
            root.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 24),
            root.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor, constant: -22)
        ])
        let heading = NSTextField(labelWithString: "把想看的视频，留在本机")
        heading.font = .systemFont(ofSize: 22, weight: .semibold)
        root.addArrangedSubview(heading)
        let subtitle = NSTextField(wrappingLabelWithString: "每行一个链接，按顺序下载；下载过程中也可以继续添加。")
        subtitle.textColor = .secondaryLabelColor
        root.addArrangedSubview(subtitle)
        urlField.font = .systemFont(ofSize: 14)
        urlField.isRichText = false; urlField.isAutomaticQuoteSubstitutionEnabled = false
        urlField.isAutomaticDashSubstitutionEnabled = false; urlField.allowsUndo = true
        urlField.configure()
        urlField.autoresizingMask = [.width]; urlField.isVerticallyResizable = true
        urlField.isHorizontallyResizable = false; urlField.textContainer?.widthTracksTextView = true
        root.addArrangedSubview(sectionLabel("视频链接"))
        let inputScroll = NSScrollView(); inputScroll.hasVerticalScroller = true; inputScroll.borderType = .noBorder; stylePanel(inputScroll)
        inputScroll.documentView = urlField
        root.addArrangedSubview(inputScroll)
        inputScroll.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        inputScroll.heightAnchor.constraint(equalToConstant: 128).isActive = true
        startButton.target = self; startButton.action = #selector(startDownload); startButton.bezelStyle = .rounded; startButton.bezelColor = NSColor(calibratedRed: 0.12, green: 0.42, blue: 0.33, alpha: 1); startButton.contentTintColor = .white
        cancelButton.target = self; cancelButton.action = #selector(cancelDownload); cancelButton.bezelStyle = .rounded; cancelButton.isEnabled = false
        folderButton.target = self; folderButton.action = #selector(chooseFolder); folderButton.bezelStyle = .rounded
        openButton.target = self; openButton.action = #selector(openFolder); openButton.bezelStyle = .rounded
        let buttons = NSStackView(views: [startButton, cancelButton, folderButton, openButton]); buttons.spacing = 8
        root.addArrangedSubview(buttons)
        location.font = .systemFont(ofSize: 11); location.textColor = .secondaryLabelColor
        location.lineBreakMode = .byTruncatingMiddle
        root.addArrangedSubview(location); location.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        updateLocation()
        spinner.style = .spinning; spinner.controlSize = .small; spinner.isDisplayedWhenStopped = false
        status.font = .systemFont(ofSize: 13, weight: .medium)
        let stateRow = NSStackView(views: [spinner, status]); stateRow.spacing = 8
        root.addArrangedSubview(stateRow)
        root.addArrangedSubview(sectionLabel("下载队列"))
        let queueScroll = NSScrollView(); queueScroll.hasVerticalScroller = true; queueScroll.borderType = .noBorder; stylePanel(queueScroll)
        queueView.delegate = self; queueView.dataSource = self
        queueView.rowHeight = 36
        queueView.usesAlternatingRowBackgroundColors = true
        queueView.gridStyleMask = []
        queueView.gridColor = .separatorColor
        queueView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        for (key, title, width) in [("number", "序号", 48.0), ("state", "状态", 72.0), ("url", "视频链接", 500.0)] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(key))
            column.title = title; column.width = width
            column.minWidth = key == "url" ? 180 : width
            if key != "url" { column.maxWidth = width }
            queueView.addTableColumn(column)
        }
        queueScroll.hasHorizontalScroller = true
        queueScroll.documentView = queueView
        root.addArrangedSubview(queueScroll)
        queueScroll.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        queueScroll.heightAnchor.constraint(equalToConstant: 110).isActive = true
        refreshQueue()
        root.addArrangedSubview(sectionLabel("下载详情"))
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.borderType = .noBorder; stylePanel(scroll)
        log.isEditable = false; log.isSelectable = true; log.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        log.textContainerInset = NSSize(width: 10, height: 10)
        log.autoresizingMask = [.width]; log.isVerticallyResizable = true; log.isHorizontallyResizable = false
        log.textContainer?.widthTracksTextView = true
        scroll.documentView = log
        root.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 110).isActive = true
        let footnote = NSTextField(wrappingLabelWithString: "下载需要联网，合并在本机完成。仅保存有权下载的内容；不读取浏览器登录信息，不绕过 DRM。")
        footnote.font = .systemFont(ofSize: 11); footnote.textColor = .secondaryLabelColor
        root.addArrangedSubview(footnote)
        appendLog("下载进度会显示在这里。\n")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func sectionLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }
    func stylePanel(_ view: NSScrollView) {
        view.wantsLayer = true
        view.layer?.cornerRadius = 10
        view.layer?.borderWidth = 0.5
        view.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        view.layer?.masksToBounds = true
        view.scrollerStyle = .overlay
    }
    func setupMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem(); menu.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        appMenu.addItem(withTitle: "退出视频下载助手", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem(); menu.addItem(editItem)
        let edit = NSMenu(title: "编辑"); editItem.submenu = edit
        edit.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = menu
    }
    func appendLog(_ text: String) {
        log.textStorage?.append(NSAttributedString(string: text, attributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular), .foregroundColor: NSColor.labelColor]))
        if log.string.count > 80000 { log.string = String(log.string.suffix(60000)) }
        log.scrollToEndOfDocument(nil)
    }
    func updateLocation() { location.stringValue = "保存位置：" + outputFolder.path; location.toolTip = outputFolder.path }
    @objc func chooseFolder() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
        panel.prompt = "保存到这里"
        panel.beginSheetModal(for: window) { response in
            if response == .OK, let url = panel.url {
                self.outputFolder = url; UserDefaults.standard.set(url.path, forKey: "outputFolder"); self.updateLocation()
            }
        }
    }
    @objc func openFolder() {
        do { try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true); NSWorkspace.shared.open(outputFolder) }
        catch { status.stringValue = "无法打开文件夹：" + error.localizedDescription }
    }
    func refreshQueue() { queueView.reloadData() }
    func numberOfRows(in tableView: NSTableView) -> Int { queue.jobs.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let job = queue.jobs[row]
        let field = NSTextField(labelWithString: "")
        field.font = .systemFont(ofSize: 12)
        switch tableColumn?.identifier.rawValue {
        case "number":
            field.stringValue = String(format: "%02d", row + 1)
            field.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            field.textColor = .secondaryLabelColor
        case "state":
            field.stringValue = job.state
            field.font = .systemFont(ofSize: 12, weight: .medium)
            field.textColor = job.state == "完成" ? .systemGreen : job.state == "失败" ? .systemRed : job.state == "下载中" ? .systemBlue : .secondaryLabelColor
        default:
            field.stringValue = job.url; field.lineBreakMode = .byTruncatingMiddle
            field.toolTip = job.url
        }
        let cell = NSTableCellView()
        cell.addSubview(field); field.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8), field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8), field.centerYAnchor.constraint(equalTo: cell.centerYAnchor)])
        return cell
    }
    @objc func startDownload() {
        if cancelled && process != nil { status.stringValue = "正在暂停，请稍候…"; return }
        do {
            let urls = try DownloadQueue.parse(urlField.string)
            _ = queue.add(urls)
            urlField.string = ""
            queue.paused = false
            refreshQueue()
            if process == nil { startNext() }
        } catch { status.stringValue = error.localizedDescription }
    }
    func startNext() {
        guard process == nil else { return }
        guard let input = queue.next() else {
            spinner.stopAnimation(nil); cancelButton.isEnabled = false; folderButton.isEnabled = true
            let completed = queue.jobs.filter { $0.state == "完成" }.count
            let failed = queue.jobs.filter { $0.state == "失败" }.count
            status.stringValue = queue.paused ? "队列已暂停，点击「加入队列并下载」继续" : "队列结束：完成 \(completed) 个，失败 \(failed) 个"
            refreshQueue(); return
        }
        cancelled = false
        refreshQueue()
        guard let resources = Bundle.main.resourceURL else { queue.finish(success: false, cancelled: false); queue.paused = true; startNext(); return }
        let python = "/opt/homebrew/bin/python3"
        guard FileManager.default.isExecutableFile(atPath: python), FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/ffmpeg") else {
            queue.finish(success: false, cancelled: true); queue.paused = true; startNext(); status.stringValue = "缺少本机 Python 或 FFmpeg，请检查 Homebrew 安装。"; return
        }
        do { try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true) }
        catch { queue.finish(success: false, cancelled: true); queue.paused = true; startNext(); status.stringValue = "保存位置不可写：" + error.localizedDescription; return }
        let task = Process(); let output = Pipe()
        task.executableURL = URL(fileURLWithPath: python)
        task.arguments = [resources.appendingPathComponent("download.py").path, outputFolder.path, input]
        var env = ProcessInfo.processInfo.environment
        env["PYTHONPATH"] = resources.appendingPathComponent("runtime").path
        env["PYTHONUNBUFFERED"] = "1"
        env["PATH"] = "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        task.environment = env; task.standardOutput = output; task.standardError = output
        task.standardInput = FileHandle.nullDevice
        appendLog("\n—— 开始任务 \((queue.active ?? 0) + 1) ——\n"); pipe = output; process = task
        let decoder = OutputDecoder()
        output.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { handle.readabilityHandler = nil; return }
            let text = decoder.decode(data)
            DispatchQueue.main.async { self.appendLog(text) }
        }
        task.terminationHandler = { finished in
            DispatchQueue.main.async {
                self.process = nil; self.pipe = nil
                self.queue.finish(success: finished.terminationStatus == 0, cancelled: self.cancelled)
                self.appendLog(self.cancelled ? "\n任务已暂停，下次继续。\n" : (finished.terminationStatus == 0 ? "\n任务完成。\n" : "\n任务失败，继续下一条。\n"))
                self.cancelled = false
                self.startNext()
            }
        }
        do {
            try task.run()
            cancelButton.isEnabled = true; folderButton.isEnabled = false
            status.stringValue = "正在下载第 \((queue.active ?? 0) + 1) / \(queue.jobs.count) 个，进度见下方日志…"; spinner.startAnimation(nil)
        } catch {
            output.fileHandleForReading.readabilityHandler = nil; process = nil; pipe = nil
            appendLog("启动失败：" + error.localizedDescription + "\n")
            queue.finish(success: false, cancelled: false)
            DispatchQueue.main.async { self.startNext() }
        }
    }
    @objc func cancelDownload() {
        guard let task = process, task.isRunning else { return }
        queue.paused = true; cancelled = true; cancelButton.isEnabled = false; status.stringValue = "正在停止…"
        let pid = task.processIdentifier
        if kill(-pid, SIGINT) != 0 { task.interrupt() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if self.process === task && task.isRunning { if kill(-pid, SIGTERM) != 0 { task.terminate() } }
        }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if process != nil {
            let alert = NSAlert(); alert.messageText = "下载还在进行"; alert.informativeText = "先点击「暂停队列」，再退出应用。"; alert.runModal(); return .terminateCancel
        }
        if queue.jobs.contains(where: { $0.state == "等待" }) {
            let alert = NSAlert(); alert.messageText = "退出并清空未完成队列？"
            alert.informativeText = "下载文件会保留，但等待中的链接不会保存。"
            alert.addButton(withTitle: "继续使用"); alert.addButton(withTitle: "退出")
            if alert.runModal() != .alertSecondButtonReturn { return .terminateCancel }
        }
        return .terminateNow
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if process != nil { _ = applicationShouldTerminate(NSApp); return false }
        NSApp.terminate(nil); return false
    }
}
// Preserve UTF-8 characters split across pipe reads.
final class OutputDecoder {
    private var pending = Data()
    func decode(_ data: Data) -> String {
        pending.append(data)
        for tail in 0...min(3, pending.count) {
            let end = pending.count - tail
            if let text = String(data: pending.prefix(end), encoding: .utf8) {
                pending = Data(pending.suffix(tail)); return text
            }
        }
        let text = String(decoding: pending, as: UTF8.self); pending.removeAll(); return text
    }
}
let app = NSApplication.shared
let delegate = DownloadApp()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
