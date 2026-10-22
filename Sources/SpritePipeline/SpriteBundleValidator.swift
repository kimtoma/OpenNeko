import Foundation
import OpenNekoKit

enum SpriteBundleValidator {
    static let skins = ["default", "black", "calico", "orange", "pink"]
    static let states = [
        "idle", "hover", "click", "coding", "typing", "thinking", "lunch", "yawn",
        "nap", "success", "error", "dragging", "walk", "jump", "punch",
    ]

    static func validate(options: ValidateOptions) throws {
        var descriptors: [SpriteFrameDescriptor] = []
        var counts: [String: Int] = [:]
        for skin in skins {
            let nestedDirectory = options.spritesDirectory.appendingPathComponent(skin, isDirectory: true)
            let directory = skin == "default" && !FileManager.default.fileExists(atPath: nestedDirectory.path)
                ? options.spritesDirectory
                : nestedDirectory
            let pngCount = (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension.lowercased() == "png" }.count) ?? 0
            counts[skin] = pngCount
            guard pngCount == states.count * 4 else {
                try writeReport(
                    options: options,
                    counts: counts,
                    issues: [[
                        "code": "invalidFrameCount",
                        "message": "Expected 60 PNG files for \(skin), got \(pngCount)",
                        "skin": skin,
                    ]]
                )
                throw PipelineError.invalidFrameCount(skin: skin, expected: 60, actual: pngCount)
            }
            for state in states {
                for index in 0..<4 {
                    let url = directory.appendingPathComponent("\(state)_\(index).png")
                    guard FileManager.default.fileExists(atPath: url.path) else {
                        throw PipelineError.missingFile(url)
                    }
                    descriptors.append(SpriteFrameDescriptor(
                        skinID: skin,
                        state: state,
                        frameIndex: index,
                        url: url
                    ))
                }
            }
        }

        let report = SpriteAssetQuality.validate(frames: descriptors)
        let issues = report.issues.map { issue -> [String: Any] in
            var value: [String: Any] = [
                "code": issue.code.rawValue,
                "message": issue.message,
            ]
            if let frame = issue.frame {
                value["skin"] = frame.skinID
                value["state"] = frame.state
                value["frame"] = frame.frameIndex
                value["file"] = frame.url.path
            }
            return value
        }
        try writeReport(options: options, counts: counts, issues: issues)
        print("validated \(descriptors.count) frames; issues: \(issues.count)")
        guard issues.isEmpty else { throw PipelineError.validationFailed(issues.count) }
    }

    private static func writeReport(
        options: ValidateOptions,
        counts: [String: Int],
        issues: [[String: Any]]
    ) throws {
        try FileManager.default.createDirectory(
            at: options.reportURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let payload: [String: Any] = [
            "valid": issues.isEmpty,
            "expectedFrameCount": 300,
            "actualFrameCount": counts.values.reduce(0, +),
            "countsBySkin": counts,
            "issues": issues,
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: options.reportURL, options: .atomic)
    }
}
