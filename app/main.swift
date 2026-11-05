// NTFS Menu — v1.1 · 05/11/2026
// App menu-bar cho macOS: liệt kê ổ NTFS đang cắm, gắn để ghi bằng NTFS-3G
// qua macFUSE, gắn lại chỉ đọc, tháo ra, đẩy ổ ra, kiểm tra chỉ đọc.
// QUAN TRỌNG: app KHÔNG tự viết driver NTFS. Engine ghi là ntfs-3g
// (mã nguồn mở, dùng cả chục năm) chạy qua macFUSE. App không sandbox
// vì cần chạy diskutil / ntfs-3g. Chạy trên Apple Silicon, macOS 12+.

import AppKit
import Foundation

let kAppVersion = "v1.1 · 05/11/2026"
let kDiskutil = "/usr/sbin/diskutil"
let kMount = "/sbin/mount"

// MARK: - Nhật ký (log)

struct Logger {
    static var logURL: URL {
        let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return lib.appendingPathComponent("Logs/NTFSMenu/ntfs-menu.log")
    }

    static func log(_ action: String, _ ok: Bool, _ detail: String) {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let clean = detail.replacingOccurrences(of: "\n", with: " ")
        let line = "\(df.string(from: Date())) | \(action) | \(ok ? "OK" : "LOI") | \(clean)\n"
        do {
            let dir = logURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: logURL.path) {
                let h = try FileHandle(forWritingTo: logURL)
                h.seekToEndOfFile()
                h.write(Data(line.utf8))
                try h.close()
            } else {
                try line.write(to: logURL, atomically: true, encoding: .utf8)
            }
        } catch {
            // Không bao giờ crash chỉ vì ghi log lỗi.
        }
    }
}

// MARK: - Chạy lệnh shell

struct ShellResult {
    let code: Int32
    let out: String
    let err: String
}

func run(_ path: String, _ args: [String]) -> ShellResult {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    let outPipe = Pipe()
    let errPipe = Pipe()
    p.standardOutput = outPipe
    p.standardError = errPipe
    do {
        try p.run()
    } catch {
        return ShellResult(code: -1, out: "", err: "Không chạy được \(path): \(error.localizedDescription)")
    }
    p.waitUntilExit()
    let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return ShellResult(code: p.terminationStatus, out: out, err: err)
}

func shellEscape(_ s: String) -> String {
    return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

// Chạy lệnh với quyền quản trị (macOS tự hiện hộp thoại nhập mật khẩu).
func runWithAdmin(_ command: String) -> (Bool, String) {
    let escaped = command
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    let script = "do shell script \"\(escaped)\" with administrator privileges"
    guard let appleScript = NSAppleScript(source: script) else {
        return (false, "Không tạo được AppleScript")
    }
    var errDict: NSDictionary?
    _ = appleScript.executeAndReturnError(&errDict)
    if let e = errDict {
        return (false, "\(e)")
    }
    return (true, "")
}

// MARK: - Model ổ NTFS

enum MountState {
    case notMounted
    case nativeReadOnly
    case writableFuse
    case mountedOther
}

struct NTFSVolume {
    let device: String      // vd: disk4s1
    let disk: String        // vd: disk4
    let name: String
    let totalGB: Double
    let freeGB: Double
    let isInternal: Bool
    let mountPoint: String?
    let state: MountState
}

func stateText(_ s: MountState) -> String {
    switch s {
    case .notMounted: return "Chưa gắn"
    case .nativeReadOnly: return "Chỉ đọc (macOS)"
    case .writableFuse: return "Đang ghi (NTFS-3G)"
    case .mountedOther: return "Đã gắn (kiểu khác)"
    }
}

func plistDict(_ text: String) -> [String: Any]? {
    guard let data = text.data(using: .utf8) else { return nil }
    var format = PropertyListSerialization.PropertyListFormat.xml
    guard let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: &format) else {
        return nil
    }
    return obj as? [String: Any]
}

func listNTFSVolumes() -> [NTFSVolume] {
    let list = run(kDiskutil, ["list", "-plist"])
    guard list.code == 0, let root = plistDict(list.out),
          let disks = root["AllDisksAndPartitions"] as? [[String: Any]] else {
        Logger.log("Quét ổ", false, "diskutil list lỗi: \(list.err)")
        return []
    }
    let mountText = run(kMount, []).out
    var volumes: [NTFSVolume] = []
    for disk in disks {
        guard let diskID = disk["DeviceIdentifier"] as? String,
              let parts = disk["Partitions"] as? [[String: Any]] else { continue }
        for part in parts {
            guard let content = part["Content"] as? String, content == "Windows_NTFS",
                  let devID = part["DeviceIdentifier"] as? String else { continue }
            let info = run(kDiskutil, ["info", "-plist", devID])
            guard info.code == 0, let d = plistDict(info.out) else { continue }
            let name = (d["VolumeName"] as? String) ?? devID
            let mounted = (d["Mounted"] as? Bool) ?? false
            let mp = d["MountPoint"] as? String
            let total = (d["TotalSize"] as? NSNumber)?.doubleValue ?? 0
            let free = (d["FreeSpace"] as? NSNumber)?.doubleValue ?? 0
            let internalDisk = (d["Internal"] as? Bool) ?? false
            var state: MountState = .notMounted
            if mounted {
                state = .mountedOther
                for line in mountText.components(separatedBy: "\n") {
                    if line.hasPrefix("/dev/\(devID) on ") {
                        if line.contains("macfuse") { state = .writableFuse }
                        else if line.contains("read-only") { state = .nativeReadOnly }
                        break
                    }
                }
            }
            volumes.append(NTFSVolume(device: devID, disk: diskID, name: name,
                                      totalGB: total / 1_000_000_000,
                                      freeGB: free / 1_000_000_000,
                                      isInternal: internalDisk,
                                      mountPoint: mp, state: state))
        }
    }
    return volumes
}

func findBinary(_ name: String, _ dirs: [String]) -> String? {
    let which = run("/bin/sh", ["-c", "command -v \(name)"])
    let found = which.out.trimmingCharacters(in: .whitespacesAndNewlines)
    if which.code == 0 && !found.isEmpty && FileManager.default.isExecutableFile(atPath: found) {
        return found
    }
    for dir in dirs {
        let p = "\(dir)/\(name)"
        if FileManager.default.isExecutableFile(atPath: p) { return p }
    }
    return nil
}

func ntfs3gPath() -> String? {
    return findBinary("ntfs-3g", ["/opt/homebrew/bin", "/usr/local/bin"])
}

func ntfsfixPath() -> String? {
    return findBinary("ntfsfix", ["/opt/homebrew/bin", "/usr/local/bin"])
}

// Điểm gắn trống trong /Volumes (tránh trùng tên với ổ khác).
func freeMountPoint(for name: String) -> String {
    let fm = FileManager.default
    var candidate = "/Volumes/\(name)"
    for i in 0...9 {
        if i > 0 { candidate = "/Volumes/\(name) \(i)" }
        if !fm.fileExists(atPath: candidate) { return candidate }
        if let items = try? fm.contentsOfDirectory(atPath: candidate), items.isEmpty {
            return candidate
        }
    }
    return "/Volumes/\(name) \(Int(Date().timeIntervalSince1970))"
}

// MARK: - Các thao tác (chạy nền để không treo menu)

enum FuseBackend {
    case fskit, kernel
}

func mountWritable(_ v: NTFSVolume, useAdmin: Bool, onDone: @escaping (Bool, String) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        func fail(_ detail: String) {
            Logger.log("Gắn ghi \(v.name)", false, detail)
            DispatchQueue.main.async { onDone(false, detail) }
        }
        // 1) Tháo mount hiện tại (nếu có) trước khi gắn lại.
        if v.state != .notMounted {
            let um = run(kDiskutil, ["unmount", v.device])
            if um.code != 0 {
                fail("Không tháo được mount hiện tại (ổ đang bận?): \(um.err)")
                return
            }
        }
        guard let ntfs = ntfs3gPath() else {
            fail("Chưa tìm thấy ntfs-3g. Chạy lại file Cài đặt rồi thử lại.")
            return
        }
        let mp = freeMountPoint(for: v.name)
        do {
            try FileManager.default.createDirectory(atPath: mp, withIntermediateDirectories: true)
        } catch {
            fail("Không tạo được điểm gắn \(mp): \(error.localizedDescription)")
            return
        }
        // 2) Thử backend FSKit trước, rồi fallback backend kernel.
        let backends: [FuseBackend] = [.fskit, .kernel]
        var lastErr = ""
        for b in backends {
            var opts = "local,allow_other,auto_xattr"
            if b == .fskit { opts += ",backend=fskit" }
            let args = ["/dev/\(v.device)", mp, "-o", opts]
            let r: ShellResult
            if useAdmin {
                let cmd = ([ntfs] + args).map(shellEscape).joined(separator: " ")
                let (ok, msg) = runWithAdmin(cmd)
                r = ShellResult(code: ok ? 0 : 1, out: "", err: msg)
            } else {
                r = run(ntfs, args)
            }
            if r.code == 0 {
                Thread.sleep(forTimeInterval: 1.0)
                let vols = listNTFSVolumes()
                if let now = vols.first(where: { $0.device == v.device }),
                   now.state == .writableFuse {
                    let backendName = (b == .fskit) ? "FSKit" : "kernel (fallback)"
                    Logger.log("Gắn ghi \(v.name)", true, "backend \(backendName), điểm gắn \(mp)")
                    DispatchQueue.main.async {
                        onDone(true, "Đã gắn \(v.name) để ghi (backend \(backendName)).")
                    }
                    return
                }
                lastErr = "Lệnh chạy xong nhưng mount chưa lên. Mở lại menu sau vài giây."
            } else {
                lastErr = r.err.isEmpty ? r.out : r.err
            }
            Logger.log("Gắn ghi \(v.name) backend \(b == .fskit ? "fskit" : "kernel")", false, lastErr)
            if useAdmin { break }
        }
        // 3) Lỗi thiếu quyền -> để giao diện hỏi thử lại với quyền quản trị.
        let low = lastErr.lowercased()
        if !useAdmin && (low.contains("permitted") || low.contains("permission")) {
            DispatchQueue.main.async { onDone(false, "NEED_ADMIN::\(lastErr)") }
            return
        }
        DispatchQueue.main.async { onDone(false, lastErr) }
    }
}

func performAsync(_ title: String, _ work: @escaping () -> (Bool, String),
                  _ done: @escaping (Bool, String) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        let (ok, msg) = work()
        Logger.log(title, ok, msg)
        DispatchQueue.main.async { done(ok, msg) }
    }
}

func remountReadOnly(_ v: NTFSVolume) -> (Bool, String) {
    if v.state != .notMounted {
        let um = run(kDiskutil, ["unmount", v.device])
        if um.code != 0 {
            return (false, "Không tháo được mount hiện tại: \(um.err)")
        }
    }
    let m = run(kDiskutil, ["mount", v.device])
    if m.code != 0 {
        return (false, "Không gắn lại được: \(m.err)")
    }
    Thread.sleep(forTimeInterval: 1.0)
    let vols = listNTFSVolumes()
    if let now = vols.first(where: { $0.device == v.device }),
       now.state == .nativeReadOnly || now.state == .mountedOther {
        return (true, "Đã gắn \(v.name) ở chế độ chỉ đọc của macOS.")
    }
    return (true, "Đã gắn lại \(v.name). Kiểm tra trạng thái trong menu.")
}

func unmountVolume(_ v: NTFSVolume) -> (Bool, String) {
    var r = run(kDiskutil, ["unmount", v.device])
    if r.code != 0, let mp = v.mountPoint {
        r = run(kDiskutil, ["unmount", mp])
    }
    if r.code == 0 {
        return (true, "Đã tháo \(v.name). Rút cáp an toàn được rồi.")
    }
    return (false, "Không tháo được (ổ đang bận?): \(r.err)")
}

func ejectDisk(_ v: NTFSVolume) -> (Bool, String) {
    let r = run(kDiskutil, ["eject", v.disk])
    if r.code == 0 {
        return (true, "Đã đẩy ổ \(v.name) ra.")
    }
    return (false, "Không đẩy được: \(r.err)")
}

func checkOnly(_ v: NTFSVolume) -> (Bool, String) {
    guard let fix = ntfsfixPath() else {
        return (false, "Chưa tìm thấy ntfsfix (đi kèm gói ntfs-3g).")
    }
    let r = run(fix, ["--no-action", "/dev/\(v.device)"])
    let text = (r.out + "\n" + r.err).trimmingCharacters(in: .whitespacesAndNewlines)
    let shown = String(text.prefix(1500))
    return (r.code == 0, "Kết quả kiểm tra \(v.name) (chỉ đọc, không sửa gì):\n\(shown)")
}

// MARK: - Giao diện menu bar

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var menu = NSMenu()
    var currentVolumes: [NTFSVolume] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let img = NSImage(systemSymbolName: "externaldrive.fill",
                                 accessibilityDescription: "NTFS") {
                button.image = img
            } else {
                button.title = "NTFS"
            }
            button.toolTip = "NTFS Menu — gắn ổ NTFS để ghi"
        }
        menu.delegate = self
        statusItem.menu = menu
        Logger.log("Khởi động", true, "NTFS Menu \(kAppVersion)")
        buildMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        buildMenu()
    }

    func volume(for sender: NSMenuItem) -> NTFSVolume? {
        guard sender.tag >= 0 && sender.tag < currentVolumes.count else { return nil }
        return currentVolumes[sender.tag]
    }

    func showAlert(_ title: String, _ info: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = info
        a.addButton(withTitle: "OK")
        a.runModal()
    }

    func buildMenu() {
        menu.removeAllItems()
        currentVolumes = listNTFSVolumes()
        if currentVolumes.isEmpty {
            let item = NSMenuItem(title: "Không thấy ổ NTFS nào", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            let hint = NSMenuItem(title: "Cắm ổ NTFS vào rồi bấm Làm mới", action: nil, keyEquivalent: "")
            hint.isEnabled = false
            menu.addItem(hint)
        } else {
            for (idx, v) in currentVolumes.enumerated() {
                let title = "\(v.name) — \(stateText(v.state))"
                let volItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                let sub = NSMenu()
                let info = NSMenuItem(
                    title: "\(Int(v.freeGB)) GB trống / \(Int(v.totalGB)) GB\(v.isInternal ? " · Ổ trong" : "")",
                    action: nil, keyEquivalent: "")
                info.isEnabled = false
                sub.addItem(info)
                sub.addItem(NSMenuItem.separator())

                let mount = NSMenuItem(title: "Gắn để ghi (NTFS-3G)", action: #selector(mountAction(_:)), keyEquivalent: "")
                mount.target = self; mount.tag = idx
                mount.isEnabled = (v.state != .writableFuse)
                sub.addItem(mount)

                let ro = NSMenuItem(title: "Gắn lại chỉ đọc (macOS)", action: #selector(remountAction(_:)), keyEquivalent: "")
                ro.target = self; ro.tag = idx
                ro.isEnabled = (v.state == .writableFuse || v.state == .mountedOther)
                sub.addItem(ro)

                let um = NSMenuItem(title: "Tháo ra", action: #selector(unmountAction(_:)), keyEquivalent: "")
                um.target = self; um.tag = idx
                um.isEnabled = (v.state != .notMounted)
                sub.addItem(um)

                let ej = NSMenuItem(title: "Đẩy ổ ra", action: #selector(ejectAction(_:)), keyEquivalent: "")
                ej.target = self; ej.tag = idx
                sub.addItem(ej)

                let ck = NSMenuItem(title: "Kiểm tra ổ (chỉ đọc)", action: #selector(checkAction(_:)), keyEquivalent: "")
                ck.target = self; ck.tag = idx
                sub.addItem(ck)

                let fi = NSMenuItem(title: "Mở trong Finder", action: #selector(finderAction(_:)), keyEquivalent: "")
                fi.target = self; fi.tag = idx
                fi.isEnabled = (v.mountPoint != nil)
                sub.addItem(fi)

                volItem.submenu = sub
                menu.addItem(volItem)
            }
        }
        menu.addItem(NSMenuItem.separator())
        let refresh = NSMenuItem(title: "Làm mới", action: #selector(refreshAction(_:)), keyEquivalent: "")
        refresh.target = self
        menu.addItem(refresh)
        let logItem = NSMenuItem(title: "Mở file nhật ký", action: #selector(logAction(_:)), keyEquivalent: "")
        logItem.target = self
        menu.addItem(logItem)
        let about = NSMenuItem(title: "Giới thiệu NTFS Menu", action: #selector(aboutAction(_:)), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(NSMenuItem.separator())
        let footer = NSMenuItem(title: "NTFS Menu \(kAppVersion)", action: nil, keyEquivalent: "")
        footer.isEnabled = false
        menu.addItem(footer)
        let quit = NSMenuItem(title: "Thoát", action: #selector(quitAction(_:)), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc func mountAction(_ sender: NSMenuItem) {
        guard let v = volume(for: sender) else { return }
        mountWritable(v, useAdmin: false) { ok, msg in
            if msg.hasPrefix("NEED_ADMIN::") {
                let a = NSAlert()
                a.messageText = "Cần quyền quản trị"
                a.informativeText = "macOS không cho gắn ổ này với quyền thường. Thử lại với quyền quản trị?"
                a.addButton(withTitle: "Thử với quyền quản trị")
                a.addButton(withTitle: "Để sau")
                if a.runModal() == .alertFirstButtonReturn {
                    mountWritable(v, useAdmin: true) { ok2, msg2 in
                        self.showAlert(ok2 ? "Xong" : "Chưa gắn được", msg2)
                        self.buildMenu()
                    }
                }
            } else {
                self.showAlert(ok ? "Xong" : "Chưa gắn được", msg)
                self.buildMenu()
            }
        }
    }

    @objc func remountAction(_ sender: NSMenuItem) {
        guard let v = volume(for: sender) else { return }
        performAsync("Gắn lại chỉ đọc \(v.name)", { remountReadOnly(v) }) { ok, msg in
            self.showAlert(ok ? "Xong" : "Chưa gắn lại được", msg)
            self.buildMenu()
        }
    }

    @objc func unmountAction(_ sender: NSMenuItem) {
        guard let v = volume(for: sender) else { return }
        performAsync("Tháo \(v.name)", { unmountVolume(v) }) { ok, msg in
            self.showAlert(ok ? "Xong" : "Chưa tháo được", msg)
            self.buildMenu()
        }
    }

    @objc func ejectAction(_ sender: NSMenuItem) {
        guard let v = volume(for: sender) else { return }
        performAsync("Đẩy ổ \(v.name)", { ejectDisk(v) }) { ok, msg in
            self.showAlert(ok ? "Xong" : "Chưa đẩy được", msg)
            self.buildMenu()
        }
    }

    @objc func checkAction(_ sender: NSMenuItem) {
        guard let v = volume(for: sender) else { return }
        performAsync("Kiểm tra \(v.name)", { checkOnly(v) }) { ok, msg in
            self.showAlert(ok ? "Kiểm tra xong" : "Kiểm tra báo lỗi", msg)
        }
    }

    @objc func finderAction(_ sender: NSMenuItem) {
        guard let v = volume(for: sender), let mp = v.mountPoint else { return }
        _ = NSWorkspace.shared.open(URL(fileURLWithPath: mp))
    }

    @objc func refreshAction(_ sender: NSMenuItem) {
        buildMenu()
    }

    @objc func logAction(_ sender: NSMenuItem) {
        let url = Logger.logURL
        if FileManager.default.fileExists(atPath: url.path) {
            _ = NSWorkspace.shared.open(url)
        } else {
            showAlert("Chưa có nhật ký", "File nhật ký sẽ xuất hiện sau lần chạy đầu tiên.")
        }
    }

    @objc func aboutAction(_ sender: NSMenuItem) {
        showAlert("NTFS Menu \(kAppVersion)",
                  "Gắn ổ NTFS để đọc/ghi đầy đủ trên Mac Apple Silicon.\n\n" +
                  "Engine ghi: ntfs-3g (mã nguồn mở) qua macFUSE — app không tự viết driver NTFS.\n" +
                  "Nhật ký: ~/Library/Logs/NTFSMenu/ntfs-menu.log")
    }

    @objc func quitAction(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(nil)
    }
}

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
