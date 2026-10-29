import Foundation
struct DownloadJob {
    let url: String
    var state = "等待"
}
struct DownloadQueue {
    var jobs: [DownloadJob] = []
    var active: Int?
    var paused = false
    static func parse(_ text: String) throws -> [String] {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        for (index, line) in lines.enumerated() {
            guard !line.contains(where: { $0.isWhitespace }), let url = URL(string: line), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else {
                throw NSError(domain: "Queue", code: 1, userInfo: [NSLocalizedDescriptionKey: "第 \(index + 1) 条链接格式不正确，请每行粘贴一个完整网页地址。"])
            }
        }
        return lines
    }
    mutating func add(_ urls: [String]) -> Int {
        var count = 0
        for url in urls where !jobs.contains(where: { $0.url == url && ["等待", "下载中"].contains($0.state) }) {
            jobs.append(DownloadJob(url: url)); count += 1
        }
        return count
    }
    mutating func next() -> String? {
        guard !paused, active == nil, let index = jobs.firstIndex(where: { $0.state == "等待" }) else { return nil }
        active = index; jobs[index].state = "下载中"; return jobs[index].url
    }
    mutating func finish(success: Bool, cancelled: Bool) {
        guard let index = active else { return }
        jobs[index].state = cancelled ? "等待" : (success ? "完成" : "失败")
        active = nil
    }
}
