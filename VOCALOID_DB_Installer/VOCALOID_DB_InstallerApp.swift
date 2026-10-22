import SwiftUI
import UniformTypeIdentifiers
import CryptoKit

@main
struct VOCALOID_DB_InstallerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    // 状态变量
    @State private var dbType: String = "Unknown"
    @State private var dbCompID: String = "Unknown"
    @State private var selectedPath: String = ""
    @State private var vdbName: String = ""
    @State private var vdbVer: String = ""
    @State private var vdbDrp: String = ""
    @State private var vdbKey: String = ""
    @State private var isDVQM: Bool = false
    @State private var isReadyToInstall: Bool = false
    @State private var statusMessage: String = "Please select a database component."
    
    @State private var showDDIPicker = false
    @State private var showDATPicker = false

    var body: some View {
        VStack(spacing: 16) {
            // 头部系统状态
            HStack {
                Text("CurOS:")
                    .fontWeight(.bold)
                Text(ProcessInfo.processInfo.operatingSystemVersionString)
                Spacer()
            }
            .padding(.bottom, 8)
            
            // 信息展示板
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("DBType:").frame(width: 90, alignment: .leading)
                    Text(dbType).foregroundColor(.secondary)
                }
                HStack {
                    Text("DBCompID:").frame(width: 90, alignment: .leading)
                    Text(dbCompID).foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // 功能按钮
            HStack(spacing: 12) {
                Button("Find VOCALOID DB") {
                    showDDIPicker = true
                }
                .fileImporter(
                    isPresented: $showDDIPicker,
                    allowedContentTypes: [UTType(filenameExtension: "ddi") ?? .data],
                    allowsMultipleSelection: false
                ) { result in
                    handleDDIPicked(result: result)
                }
                
                Button("Find AttackReleaseLib") {
                    showDATPicker = true
                }
                .fileImporter(
                    isPresented: $showDATPicker,
                    allowedContentTypes: [UTType(filenameExtension: "dat") ?? .data],
                    allowsMultipleSelection: false
                ) { result in
                    handleDATPicked(result: result)
                }
            }
            
            Divider()
            
            // 状态与安装
            VStack(spacing: 8) {
                Text(statusMessage)
                    .font(.callout)
                    .foregroundColor(isReadyToInstall ? .green : .red)
                    .multilineTextAlignment(.center)
                    .frame(height: 38)
                
                Button("Install Selected Components") {
                    executeInstallation()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isReadyToInstall)
            }
        }
        .padding(20)
        .frame(width: 420, height: 280)
    }

    // MARK: - 逻辑处理函数

    /// 运行 date2drp2 并在伪终端中进行容错解码
    func runDate2drp2(compId: String) -> String {
        guard let bundleURL = Bundle.main.url(forResource: "date2drp2", withExtension: nil) else {
            return "ERROR: date2drp2 not found in App Bundle. Please check Target Membership."
        }
        
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let tempExecURL = tempDir.appendingPathComponent("date2drp2_temp")
        
        do {
            if fileManager.fileExists(atPath: tempExecURL.path) {
                try fileManager.removeItem(at: tempExecURL)
            }
            try fileManager.copyItem(at: bundleURL, to: tempExecURL)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempExecURL.path)
        } catch {
            return "ERROR: Copy failed: \(error.localizedDescription)"
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/script")
        process.arguments = ["-q", "/dev/null", tempExecURL.path, compId]
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            try? fileManager.removeItem(at: tempExecURL)
            
            // 增量修正：使用容错型解码器，防止尾部溢出乱码导致解码返回 nil
            let rawOutput = String(decoding: data, as: UTF8.self)
            let cleaned = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if cleaned.count >= 14 {
                let decodedKey = String(cleaned.prefix(14))
                return decodedKey
            } else {
                return "ERROR: PTY output too short (\(cleaned.count)): '\(cleaned)'"
            }
        } catch {
            try? fileManager.removeItem(at: tempExecURL)
            return "LAUNCH_ERROR: \(error.localizedDescription)"
        }
    }

    /// 计算 MD5
    func md5Hash(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    /// 解析 DDI 结构
    func handleDDIPicked(result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let ddiURL = urls.first else { return }
        
        let parentDir = ddiURL.deletingLastPathComponent()
        let compID = parentDir.lastPathComponent
        
        if compID.count == 16 {
            self.dbCompID = compID
            self.selectedPath = parentDir.deletingLastPathComponent().path
            self.vdbName = ddiURL.deletingPathExtension().lastPathComponent
            self.dbType = "VocaloidDB \(self.vdbName)"
            self.isDVQM = false
            
            let decoded = runDate2drp2(compId: compID)
            
            if decoded.hasPrefix("ERROR") || decoded.hasPrefix("LAUNCH_ERROR") {
                self.isReadyToInstall = false
                self.statusMessage = decoded
            } else if decoded.count == 14 {
                self.vdbVer = String(decoded[decoded.index(decoded.startIndex, offsetBy: 9)])
                let drpPart1 = decoded.prefix(3).dropFirst()
                let drpPart2 = decoded.dropFirst(5).prefix(2)
                self.vdbDrp = "\(drpPart1)00\(drpPart2)"
                self.vdbKey = md5Hash(decoded)
                
                self.isReadyToInstall = true
                self.statusMessage = "Found VDB (Ver \(vdbVer)). Ready to install."
            } else {
                self.isReadyToInstall = false
                self.statusMessage = "Unexpected output: '\(decoded)'"
            }
        } else {
            self.isReadyToInstall = false
            self.statusMessage = "Invalid directory structure. Parent folder must be 16 chars."
        }
    }

    /// 解析 DVQM
    func handleDATPicked(result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let datURL = urls.first else { return }
        
        let filename = datURL.deletingPathExtension().lastPathComponent.lowercased()
        if filename == "dvqm" {
            let parentDir = datURL.deletingLastPathComponent()
            let compID = parentDir.lastPathComponent
            if compID.count == 16 {
                self.dbCompID = compID
                self.vdbVer = "5"
                self.selectedPath = parentDir.deletingLastPathComponent().path
                self.dbType = "VOCALOID DVQM"
                self.isDVQM = true
                self.isReadyToInstall = true
                self.statusMessage = "Found DVQM Component. Ready to install."
            } else {
                self.isReadyToInstall = false
                self.statusMessage = "Invalid DVQM folder. Parent folder must be 16 chars."
            }
        } else {
            self.isReadyToInstall = false
            self.statusMessage = "File must be named dvqm.dat."
        }
    }

    /// 执行提权写入
    func executeInstallation() {
        var commands = [String]()
        var plistFile = "/Library/Preferences/com.yamaha.VOCALOID\(vdbVer).system.plist"
        if vdbVer == "5" {
            plistFile = "/Library/Preferences/com.yamaha.VOCALOID5.plist"
        }
        
        let escapedPath = selectedPath.replacingOccurrences(of: "'", with: "'\\''")
        
        if isDVQM {
            let ppid = "AttackReleaseLib:Components:\(dbCompID)"
            commands.append("Delete \(ppid):Path")
            commands.append("Delete \(ppid):Version:Major")
            commands.append("Delete \(ppid):Version:Minor")
            commands.append("Delete \(ppid):Version:Revision")
            
            let segments = selectedPath.components(separatedBy: "/")
            for seg in segments {
                if seg.count == 16 && seg.hasPrefix("B") {
                    let decoded = runDate2drp2(compId: seg)
                    if decoded.count == 14 {
                        if decoded[decoded.index(decoded.startIndex, offsetBy: 9)] == "5" {
                            commands.append("Delete \(ppid):Voices:\(seg)")
                            commands.append("Add \(ppid):Voices:\(seg) integer 1")
                        }
                    }
                }
            }
            commands.append("Add \(ppid):Path string '\(escapedPath)'")
            commands.append("Add \(ppid):Version:Major integer 5")
            commands.append("Add \(ppid):Version:Minor integer 0")
            commands.append("Add \(ppid):Version:Revision integer 1")
            
        } else {
            var plRoot = ""
            if vdbVer == "3" { plRoot = "DATABASE:VOICE3" }
            else if vdbVer == "4" { plRoot = "DATABASE41" }
            else if vdbVer == "5" { plRoot = "Voice:Components" }
            
            if plRoot.isEmpty { return }
            let ppid = "\(plRoot):\(dbCompID)"
            
            if vdbVer == "5" {
                commands.append("Delete \(ppid):BankName")
                commands.append("Delete \(ppid):DRP")
                commands.append("Delete \(ppid):Name")
                commands.append("Delete \(ppid):Date")
                commands.append("Delete \(ppid):Key")
                
                commands.append("Add \(ppid):BankName string '\(vdbName)'")
                commands.append("Add \(ppid):DRP string '\(vdbDrp)'")
                commands.append("Add \(ppid):Name string '\(vdbName)'")
                commands.append("Add \(ppid):Date string 'BHMN74F9ED86FKAB'")
                commands.append("Add \(ppid):Key string '\(vdbKey)'")
                
                commands.append("Delete \(ppid):Path")
                commands.append("Delete \(ppid):Version:Major")
                commands.append("Delete \(ppid):Version:Minor")
                commands.append("Delete \(ppid):Version:Revision")
                
                commands.append("Add \(ppid):Path string '\(escapedPath)'")
                commands.append("Add \(ppid):Version:Major integer 5")
                commands.append("Add \(ppid):Version:Minor integer 0")
                commands.append("Add \(ppid):Version:Revision integer 1")
            } else {
                commands.append("Delete \(ppid):DRP")
                commands.append("Delete \(ppid):INSTALLED")
                commands.append("Delete \(ppid):NAME")
                commands.append("Delete \(ppid):PATH")
                commands.append("Delete \(ppid):TIME")
                commands.append("Delete \(ppid):KEYS:default")
                
                commands.append("Add \(ppid):DRP string '\(vdbDrp)'")
                commands.append("Add \(ppid):INSTALLED integer 1")
                commands.append("Add \(ppid):NAME string '\(vdbName)'")
                commands.append("Add \(ppid):PATH string '\(escapedPath)'")
                commands.append("Add \(ppid):TIME string 'BHMN74F9ED86FKAB'")
                commands.append("Add \(ppid):KEYS:default string '\(vdbKey)'")
            }
        }
        
        let success = runPrivilegedPlistBuddy(commands: commands, plistPath: plistFile)
        if success {
            mb.showinfo("Status", "Installation Completed Successfully!")
            statusMessage = "Installation Succeeded!"
        } else {
            statusMessage = "Installation Failed or Cancelled."
        }
    }

    /// 提权写入脚本
    func runPrivilegedPlistBuddy(commands: [String], plistPath: String) -> Bool {
        let tempScriptPath = "/tmp/v5db_install_script.sh"
        var scriptContent = "#!/bin/sh\n"
        for cmd in commands {
            scriptContent += "/usr/libexec/PlistBuddy -c \"\(cmd)\" \"\(plistPath)\"\n"
        }
        
        do {
            try scriptContent.write(toFile: tempScriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempScriptPath)
        } catch {
            return false
        }
        
        let appleScript = "do shell script \"\(tempScriptPath)\" with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]
        
        do {
            try process.run()
            process.waitUntilExit()
            try? FileManager.default.removeItem(atPath: tempScriptPath)
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

struct mb {
    static func showinfo(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}