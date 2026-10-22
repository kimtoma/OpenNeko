import AppKit
import Foundation
import OpenNekoKit

enum SpritePipelineCommand {
    static func run() throws {
        var arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first else {
            throw PipelineError.usage
        }
        arguments.removeFirst()

        switch command {
        case "extract":
            let options = try ExtractOptions(arguments: arguments)
            try SpriteSheetExtractor.extract(options: options)
        case "mask":
            let options = try MaskOptions(arguments: arguments)
            try SpriteVariantMasker.apply(options: options)
        case "validate":
            let options = try ValidateOptions(arguments: arguments)
            try SpriteBundleValidator.validate(options: options)
        case "contact-sheet":
            let options = try ContactSheetOptions(arguments: arguments)
            try SpriteContactSheet.generate(options: options)
        case "help", "--help", "-h":
            print(PipelineError.usage.errorDescription ?? "")
        default:
            throw PipelineError.unknownCommand(command)
        }
    }
}

do {
    try SpritePipelineCommand.run()
} catch {
    let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    Foundation.exit(EXIT_FAILURE)
}

struct ExtractOptions {
    let sheetURL: URL
    let outputDirectory: URL
    let states: [String]
    let columns: Int
    let rows: Int
    let removesCheckerboard: Bool

    init(arguments: [String]) throws {
        let values = try PipelineOptions.values(arguments)
        guard let sheet = values["--sheet"],
              let output = values["--output-dir"]
        else {
            throw PipelineError.usage
        }
        let stateValue = values["--states"] ?? values["--state"] ?? ""
        let states = stateValue.split(separator: ",").map(String.init).filter { !$0.isEmpty }
        guard !states.isEmpty else { throw PipelineError.usage }
        sheetURL = URL(fileURLWithPath: sheet)
        outputDirectory = URL(fileURLWithPath: output, isDirectory: true)
        self.states = states
        columns = Int(values["--columns"] ?? "2") ?? 0
        rows = Int(values["--rows"] ?? "2") ?? 0
        removesCheckerboard = values["--remove-checkerboard"] == "true"
        guard columns > 0, rows > 0 else { throw PipelineError.usage }
    }

}

enum PipelineOptions {
    static func values(_ arguments: [String]) throws -> [String: String] {
        guard arguments.count.isMultiple(of: 2) else { throw PipelineError.usage }
        var values: [String: String] = [:]
        for index in stride(from: 0, to: arguments.count, by: 2) {
            let key = arguments[index]
            guard key.hasPrefix("--") else { throw PipelineError.usage }
            values[key] = arguments[index + 1]
        }
        return values
    }
}

struct MaskOptions {
    let canonicalDirectory: URL
    let variantDirectory: URL

    init(arguments: [String]) throws {
        let values = try PipelineOptions.values(arguments)
        guard let canonical = values["--canonical-dir"], let variant = values["--variant-dir"] else {
            throw PipelineError.usage
        }
        canonicalDirectory = URL(fileURLWithPath: canonical, isDirectory: true)
        variantDirectory = URL(fileURLWithPath: variant, isDirectory: true)
    }
}

struct ValidateOptions {
    let spritesDirectory: URL
    let reportURL: URL

    init(arguments: [String]) throws {
        let values = try PipelineOptions.values(arguments)
        guard let sprites = values["--sprites"], let report = values["--report"] else {
            throw PipelineError.usage
        }
        spritesDirectory = URL(fileURLWithPath: sprites, isDirectory: true)
        reportURL = URL(fileURLWithPath: report)
    }
}

struct ContactSheetOptions {
    let spritesDirectory: URL
    let outputDirectory: URL

    init(arguments: [String]) throws {
        let values = try PipelineOptions.values(arguments)
        guard let sprites = values["--sprites"], let output = values["--output-dir"] else {
            throw PipelineError.usage
        }
        spritesDirectory = URL(fileURLWithPath: sprites, isDirectory: true)
        outputDirectory = URL(fileURLWithPath: output, isDirectory: true)
    }
}

enum PipelineError: LocalizedError {
    case usage
    case unknownCommand(String)
    case unreadableImage(URL)
    case sourceIsNotTransparent(URL)
    case invalidLayout(states: Int, columns: Int, rows: Int)
    case cropFailed(Int)
    case renderFailed(Int)
    case pngEncodingFailed(Int)
    case missingFile(URL)
    case invalidFrameCount(skin: String, expected: Int, actual: Int)
    case validationFailed(Int)

    var errorDescription: String? {
        switch self {
        case .usage:
            """
            Usage:
              SpritePipeline extract --sheet SHEET.png --output-dir DIR --states idle,hover,click --columns 4 --rows 3 --remove-checkerboard true
              SpritePipeline mask --canonical-dir DIR --variant-dir DIR
              SpritePipeline validate --sprites DIR --report REPORT.json
              SpritePipeline contact-sheet --sprites DIR --output-dir DIR
            """
        case let .unknownCommand(command):
            "Unknown command: \(command)"
        case let .unreadableImage(url):
            "Cannot read image: \(url.path)"
        case let .sourceIsNotTransparent(url):
            "Production source must contain real transparent pixels: \(url.path)"
        case let .invalidLayout(states, columns, rows):
            "Invalid state/grid layout: \(states) states for \(columns)x\(rows) cells"
        case let .cropFailed(index):
            "Cannot crop cell \(index)"
        case let .renderFailed(index):
            "Cannot render frame \(index)"
        case let .pngEncodingFailed(index):
            "Cannot encode frame \(index)"
        case let .missingFile(url):
            "Missing sprite frame: \(url.path)"
        case let .invalidFrameCount(skin, expected, actual):
            "Invalid frame count for \(skin): expected \(expected), got \(actual)"
        case let .validationFailed(count):
            "Sprite validation failed with \(count) issue(s)"
        }
    }
}
