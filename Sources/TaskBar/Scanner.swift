import Foundation

struct TaskItem: Identifiable {
    let id = UUID()
    let status: String
    let description: String
    let due: String?
    let priority: String?
    let tags: [String]
    let sourceFile: String
    let sourceLine: Int

    var isDone: Bool { status == "x" || status == "-" }

    var statusSymbol: String {
        switch status {
        case " ": return "○"
        case "/": return "◐"
        case "x": return "✓"
        case "-": return "—"
        default: return "○"
        }
    }

    var dueDate: Date? {
        guard let due else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: due)
    }

    var isOverdue: Bool {
        guard let d = dueDate else { return false }
        return d < Calendar.current.startOfDay(for: Date())
    }

    var isDueToday: Bool {
        guard let d = dueDate else { return false }
        return Calendar.current.isDateInToday(d)
    }

    var formattedDue: String? {
        guard let d = dueDate else { return nil }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: d)
    }

    var prioritySymbol: String? {
        switch priority {
        case "highest": return "▲▲"
        case "high": return "▲"
        case "medium": return "━"
        case "low": return "▼"
        case "lowest": return "▼▼"
        default: return nil
        }
    }
}

// MARK: - Scanner

class TaskScanner {
    let vaultPath: String

    init(vaultPath: String? = nil) {
        self.vaultPath = vaultPath ?? Self.resolveVaultPath()
    }

    static func resolveVaultPath() -> String {
        // 1. Environment variable
        if let env = ProcessInfo.processInfo.environment["TASKS_VAULT_PATH"] {
            return (env as NSString).expandingTildeInPath
        }
        // 2. Config file ~/.config/taskbar/config.json
        let configPath = NSHomeDirectory() + "/.config/taskbar/config.json"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let path = json["vault_path"] as? String
        {
            return (path as NSString).expandingTildeInPath
        }
        // 3. Default
        return (("~/vault") as NSString).expandingTildeInPath
    }

    func scan() -> [TaskItem] {
        guard let rg = Self.findRipgrep() else { return [] }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: rg)
        proc.arguments = [
            "--no-heading", "-n", "--no-messages",
            "#task", "--glob", "*.md", vaultPath,
        ]

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()

        do { try proc.run(); proc.waitUntilExit() } catch { return [] }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        return output
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { parseLine($0) }
    }

    // MARK: - Private

    private static func findRipgrep() -> String? {
        let candidates = [
            "/opt/homebrew/bin/rg",
            "/usr/local/bin/rg",
            "/usr/bin/rg",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        return nil
    }

    private func parseLine(_ line: String) -> TaskItem? {
        // rg output: filepath:linenum:content
        guard let r1 = line.firstIndex(of: ":") else { return nil }
        let filepath = String(line[..<r1])
        let after1 = line.index(after: r1)
        guard let r2 = line[after1...].firstIndex(of: ":") else { return nil }
        let lineNum = Int(line[after1..<r2]) ?? 0
        let content = String(line[line.index(after: r2)...])
        return parseTask(content, file: filepath, line: lineNum)
    }

    private func parseTask(_ line: String, file: String, line lineNum: Int) -> TaskItem? {
        guard let regex = try? NSRegularExpression(pattern: #"^\s*- \[(.)\]\s+#task\s+(.*)"#),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges >= 3,
              let statusRange = Range(match.range(at: 1), in: line),
              let restRange = Range(match.range(at: 2), in: line)
        else { return nil }

        let status = String(line[statusRange])
        var rest = String(line[restRange])

        // Extract metadata [key:: value]
        var meta: [String: String] = [:]
        if let re = try? NSRegularExpression(pattern: #"\[(\w+)::\s*([^\]]+)\]"#) {
            for m in re.matches(in: rest, range: NSRange(rest.startIndex..., in: rest)) {
                if let kr = Range(m.range(at: 1), in: rest),
                   let vr = Range(m.range(at: 2), in: rest)
                {
                    meta[String(rest[kr]).lowercased()] =
                        String(rest[vr]).trimmingCharacters(in: .whitespaces)
                }
            }
        }

        // Extract extra tags
        var tags = ["task"]
        if let re = try? NSRegularExpression(pattern: #"#(\S+)"#) {
            for m in re.matches(in: rest, range: NSRange(rest.startIndex..., in: rest)) {
                if let r = Range(m.range(at: 1), in: rest) {
                    let t = String(rest[r])
                    if t != "task" { tags.append(t) }
                }
            }
        }

        // Clean description
        let cleanPatterns = [
            #"\s*\[\w+::\s*[^\]]+\]"#, // metadata
            #"\s*\[\[[^\]]+\]\]"#, // wiki-links
            #"#\S+\s*"#, // tags
        ]
        for p in cleanPatterns {
            if let re = try? NSRegularExpression(pattern: p) {
                rest = re.stringByReplacingMatches(
                    in: rest, range: NSRange(rest.startIndex..., in: rest), withTemplate: "")
            }
        }
        rest = rest.trimmingCharacters(in: .whitespaces)

        return TaskItem(
            status: status,
            description: rest,
            due: meta["due"],
            priority: meta["priority"],
            tags: tags,
            sourceFile: file,
            sourceLine: lineNum
        )
    }
}
