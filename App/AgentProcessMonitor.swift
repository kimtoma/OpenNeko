import Foundation
import OpenNekoKit

final class AgentProcessMonitor {
    private let queue = DispatchQueue(label: "openneko.agent-process-monitor", qos: .utility)
    private var isScanning = false

    func scan(completion: @escaping ([AgentProcessActivity]) -> Void) {
        guard !isScanning else { return }
        isScanning = true
        queue.async { [weak self] in
            defer {
                DispatchQueue.main.async {
                    self?.isScanning = false
                }
            }

            let output = Self.psOutput()
            let activities = AgentProcessDetector.detect(psOutput: output)
            DispatchQueue.main.async {
                completion(activities)
            }
        }
    }

    private static func psOutput() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pcpu=,command="]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(decoding: data, as: UTF8.self)
        } catch {
            NSLog("[openNeko] failed to scan agent processes: \(error)")
            return ""
        }
    }
}
