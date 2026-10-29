import Foundation
var q = DownloadQueue()
let a = "https://example.com/a"
let b = "https://example.com/b"
let c = "https://example.com/c"
let parsed = try DownloadQueue.parse("\n \(a) \r\n\(b)\n")
assert(parsed == [a,b])
assert(q.add([a,a,b]) == 2)
assert(q.next() == a)
assert(q.next() == nil)
assert(q.add([b,c]) == 1)
q.finish(success: false, cancelled: false)
assert(q.jobs[0].state == "失败")
assert(q.next() == b)
q.paused = true
q.finish(success: false, cancelled: true)
assert(q.next() == nil)
assert(q.jobs[1].state == "等待")
q.paused = false
assert(q.next() == b)
q.finish(success: true, cancelled: false)
assert(q.next() == c)
q.finish(success: true, cancelled: false)
assert(q.next() == nil)
for bad in ["file:///tmp/video", "https://user:secret@example.com", "\(a) \(b)", "not-a-url"] {
    do { _ = try DownloadQueue.parse(bad); fatalError("accepted invalid URL") } catch {}
}
print("PASS: multiline parsing, validation, deduplication, sequential execution, add while active, failure continuation, pause/resume, completion")
