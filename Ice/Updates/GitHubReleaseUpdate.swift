//
//  GitHubReleaseUpdate.swift
//  Ice
//

import Foundation

/// Numeric version from a marketing string or a `vX.Y.Z` git tag.
struct ReleaseVersion: Comparable {
    let components: [Int]

    /// Dotted numbers, without a leading `v` or a pre-release suffix.
    var display: String {
        components.map(String.init).joined(separator: ".")
    }

    init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        var body = trimmed
        if body.first == "v" || body.first == "V" {
            body.removeFirst()
        }
        if let dash = body.firstIndex(of: "-") {
            body = String(body[..<dash])
        }
        let parts = body.split(separator: ".")
        guard !parts.isEmpty else {
            return nil
        }
        var numbers: [Int] = []
        for part in parts {
            guard let number = Int(part), number >= 0 else {
                return nil
            }
            numbers.append(number)
        }
        components = numbers
    }

    static func < (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }

    /// `1.0` and `1.0.0` are the same release.
    static func == (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}

/// One GitHub release, as returned by `releases/latest`.
struct GitHubRelease: Decodable, Sendable {
    let tagName: String
    let htmlURL: URL
    let assets: [Asset]
    let prerelease: Bool
    let draft: Bool

    /// Release that uses the stable download names when the API is unavailable.
    static func standardDownloads(tag: String) -> GitHubRelease? {
        guard ReleaseVersion(tag) != nil else {
            return nil
        }
        let encoded = tag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tag
        let root = "https://github.com/\(GitHubUpdates.owner)/\(GitHubUpdates.repo)"
        guard
            let page = URL(string: "\(root)/releases/tag/\(encoded)"),
            let zip = URL(string: "\(root)/releases/download/\(encoded)/\(GitHubUpdates.zipAssetName)"),
            let dmg = URL(string: "\(root)/releases/download/\(encoded)/\(GitHubUpdates.dmgAssetName)")
        else {
            return nil
        }
        return GitHubRelease(
            tagName: tag,
            htmlURL: page,
            assets: [
                Asset(name: GitHubUpdates.zipAssetName, browserDownloadURL: zip, size: 0),
                Asset(name: GitHubUpdates.dmgAssetName, browserDownloadURL: dmg, size: 0),
            ],
            prerelease: false,
            draft: false
        )
    }

    struct Asset: Decodable, Sendable {
        let name: String
        let browserDownloadURL: URL
        let size: Int

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
            case size
        }
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
        case prerelease
        case draft
    }
}

/// Why a release could not be read or installed.
enum UpdateFailure: LocalizedError {
    case noRelease
    case badResponse(Int)
    case notAppleSilicon
    case missingAsset
    case invalidBundle
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .noRelease:
            return Self.text("No published release yet.")
        case .badResponse(let code):
            return Self.text("GitHub returned an unexpected response (%@).", String(code))
        case .notAppleSilicon:
            return Self.text("The published build is not an Apple silicon app.")
        case .missingAsset:
            return Self.text("The release has no Apple silicon download.")
        case .invalidBundle:
            return Self.text("The download is not an Ice app.")
        case .commandFailed(let output):
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return Self.text("The update could not be installed.")
            }
            return trimmed
        }
    }

    private static func text(_ key: String, _ arguments: CVarArg...) -> String {
        let template = Bundle.main.localizedString(forKey: key, value: key, table: nil)
        guard !arguments.isEmpty else {
            return template
        }
        return String(format: template, arguments: arguments)
    }
}

/// Reads `itworksig/IcePlusPlus` releases and prepares an Apple silicon app.
enum GitHubUpdates {
    static let owner = "itworksig"
    static let repo = "IcePlusPlus"
    /// Zip of `Ice.app`, produced by `.github/workflows/release.yml`.
    static let zipAssetName = "Ice.zip"
    /// Disk image for a manual install. Same app, arm64 only.
    static let dmgAssetName = "Ice-arm64.dmg"

    /// Latest non-draft release, or `UpdateFailure.noRelease` when the repo has none.
    ///
    /// `api.github.com` allows 60 unauthenticated calls per hour for the whole
    /// network. A 403 or 429 falls through to the public releases page, which
    /// is not on that quota, and then uses the known `Ice.zip` download URL.
    static func latest() async throws -> GitHubRelease {
        do {
            return try await latestFromAPI()
        } catch UpdateFailure.badResponse(let code) where code == 403 || code == 429 {
            return try await latestFromWebsite()
        }
    }

    private static func latestFromAPI() async throws -> GitHubRelease {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.github.com"
        components.path = "/repos/\(owner)/\(repo)/releases/latest"
        guard let url = components.url else {
            throw UpdateFailure.badResponse(-1)
        }
        var request = URLRequest(url: url)
        request.setValue("IcePlusPlus", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UpdateFailure.badResponse(-1)
        }
        if http.statusCode == 404 {
            throw UpdateFailure.noRelease
        }
        guard (200..<300).contains(http.statusCode) else {
            throw UpdateFailure.badResponse(http.statusCode)
        }
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        if release.draft || release.prerelease {
            throw UpdateFailure.noRelease
        }
        return release
    }

    /// `https://github.com/.../releases/latest` redirects to `/releases/tag/vX.Y.Z`.
    private static func latestFromWebsite() async throws -> GitHubRelease {
        guard let url = URL(string: "https://github.com/\(owner)/\(repo)/releases/latest") else {
            throw UpdateFailure.badResponse(-1)
        }
        var request = URLRequest(url: url)
        request.setValue("IcePlusPlus", forHTTPHeaderField: "User-Agent")
        let redirect = ReleaseRedirectStop()
        let session = URLSession(configuration: .ephemeral, delegate: redirect, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UpdateFailure.badResponse(-1)
        }
        if http.statusCode == 404 {
            throw UpdateFailure.noRelease
        }
        guard let tagURL = redirect.location ?? http.url else {
            throw UpdateFailure.badResponse(http.statusCode)
        }
        let parts = tagURL.path.split(separator: "/").map(String.init)
        guard parts.count >= 2, parts[parts.count - 2] == "tag" else {
            throw UpdateFailure.noRelease
        }
        let tag = parts[parts.count - 1].removingPercentEncoding ?? parts[parts.count - 1]
        guard let release = GitHubRelease.standardDownloads(tag: tag) else {
            throw UpdateFailure.noRelease
        }
        return release
    }

    /// Zip used to install, then the arm64 disk image, then any other zip or disk image.
    static func preferredAsset(in release: GitHubRelease) -> GitHubRelease.Asset? {
        let assets = release.assets
        if let zip = assets.first(where: { $0.name == zipAssetName }) {
            return zip
        }
        if let dmg = assets.first(where: { $0.name == dmgAssetName }) {
            return dmg
        }
        if let zip = assets.first(where: { $0.name.hasSuffix(".zip") }) {
            return zip
        }
        return assets.first(where: { $0.name.hasSuffix(".dmg") })
    }

    /// Downloads the release and returns a checked `Ice.app` that is newer than `installed`.
    static func downloadApp(
        from release: GitHubRelease,
        expectedBundleIdentifier: String,
        newerThan installed: ReleaseVersion
    ) async throws -> URL {
        guard let asset = preferredAsset(in: release) else {
            throw UpdateFailure.missingAsset
        }
        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent("ice-plusplus-update", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        do {
            let stored = work.appendingPathComponent(asset.name)
            let (downloaded, response) = try await URLSession.shared.download(from: asset.browserDownloadURL)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw UpdateFailure.badResponse(code)
            }
            try FileManager.default.moveItem(at: downloaded, to: stored)
            let app = try extractApp(at: stored, into: work)
            try validate(
                app: app,
                expectedBundleIdentifier: expectedBundleIdentifier,
                newerThan: installed
            )
            return app
        } catch {
            try? FileManager.default.removeItem(at: work)
            throw error
        }
    }

    /// Waits until `pid` exits, replaces `destination` with `app`, and opens it.
    ///
    /// When the signing identity "Ice Dev" is on this Mac, the new copy is
    /// re-signed with it so the existing Accessibility grant still matches.
    static func spawnReplacement(
        app: URL,
        destination: URL,
        waitFor pid: Int32 = ProcessInfo.processInfo.processIdentifier,
        launch: Bool = true,
        resignWithIceDev: Bool = true
    ) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ice-plusplus-update", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let scriptURL = root.appendingPathComponent("update.sh")
        let entitlementsURL = root.appendingPathComponent("update.entitlements")
        if resignWithIceDev {
            try entitlements().write(to: entitlementsURL, atomically: true, encoding: .utf8)
        }
        try replacementScript().write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: scriptURL.path
        )
        let launchFlag = launch ? "1" : "0"
        let entitlementsPath = resignWithIceDev ? entitlementsURL.path : ""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            scriptURL.path,
            app.path,
            destination.path,
            String(pid),
            entitlementsPath,
            launchFlag,
        ]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UpdateFailure.commandFailed("Could not start the installer.")
        }
    }

    private static func extractApp(at archive: URL, into work: URL) throws -> URL {
        let name = archive.lastPathComponent.lowercased()
        if name.hasSuffix(".zip") {
            try run("/usr/bin/ditto", ["-x", "-k", archive.path, work.path])
        } else if name.hasSuffix(".dmg") {
            let listed = try run(
                "/usr/bin/hdiutil",
                ["attach", "-nobrowse", "-readonly", "-plist", archive.path]
            )
            let mount = try mountPoint(plist: Data(listed.utf8))
            defer {
                _ = try? run("/usr/bin/hdiutil", ["detach", mount])
            }
            let source = URL(fileURLWithPath: mount).appendingPathComponent("Ice.app")
            guard FileManager.default.fileExists(atPath: source.path) else {
                throw UpdateFailure.invalidBundle
            }
            let copied = work.appendingPathComponent("Ice.app")
            try run("/usr/bin/ditto", [source.path, copied.path])
        } else {
            throw UpdateFailure.missingAsset
        }
        guard let app = findApp(in: work) else {
            throw UpdateFailure.invalidBundle
        }
        return app
    }

    private static func findApp(in directory: URL) -> URL? {
        let manager = FileManager.default
        let direct = directory.appendingPathComponent("Ice.app")
        if manager.fileExists(atPath: direct.path) {
            return direct
        }
        guard let children = try? manager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }
        for child in children {
            let nested = child.appendingPathComponent("Ice.app")
            if manager.fileExists(atPath: nested.path) {
                return nested
            }
        }
        return nil
    }

    private static func validate(
        app: URL,
        expectedBundleIdentifier: String,
        newerThan installed: ReleaseVersion
    ) throws {
        guard let bundle = Bundle(url: app),
              bundle.bundleIdentifier == expectedBundleIdentifier,
              let raw = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              let remote = ReleaseVersion(raw),
              remote > installed
        else {
            throw UpdateFailure.invalidBundle
        }
        let binary = app.appendingPathComponent("Contents/MacOS/Ice")
        let arches = try run("/usr/bin/lipo", ["-archs", binary.path])
        let tokens = arches.split { $0.isWhitespace }.map(String.init)
        guard tokens.contains("arm64") else {
            throw UpdateFailure.notAppleSilicon
        }
        #if !arch(arm64)
        throw UpdateFailure.notAppleSilicon
        #endif
    }

    private static func mountPoint(plist: Data) throws -> String {
        guard let root = try PropertyListSerialization.propertyList(
            from: plist,
            options: [],
            format: nil
        ) as? [String: Any],
              let entities = root["system-entities"] as? [[String: Any]]
        else {
            throw UpdateFailure.commandFailed("Could not read the disk image.")
        }
        for entity in entities {
            if let mount = entity["mount-point"] as? String, !mount.isEmpty {
                return mount
            }
        }
        throw UpdateFailure.commandFailed("Could not mount the disk image.")
    }

    @discardableResult
    private static func run(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        let outText = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errText = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw UpdateFailure.commandFailed(errText.isEmpty ? outText : errText)
        }
        return outText
    }

    private static func entitlements() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>com.apple.security.app-sandbox</key>
            <false/>
            <key>com.apple.security.cs.disable-library-validation</key>
            <true/>
        </dict>
        </plist>
        """
    }

    private static func replacementScript() -> String {
        """
        #!/bin/bash
        # Copies a downloaded Ice.app over the running copy after that process exits.
        if [ -z "${ICE_UPDATE_DAEMON:-}" ]; then
          export ICE_UPDATE_DAEMON=1
          /bin/bash "$0" "$@" >>/tmp/ice-plusplus-update.log 2>&1 &
          exit 0
        fi
        trap '' HUP
        set -u
        SRC="$1"
        DEST="$2"
        PID="$3"
        ENT="${4:-}"
        LAUNCH="${5:-1}"
        i=0
        while [ "$i" -lt 150 ]; do
          if ! kill -0 "$PID" 2>/dev/null; then
            break
          fi
          sleep 0.2
          i=$((i + 1))
        done
        if kill -0 "$PID" 2>/dev/null; then
          echo "timed out waiting for $PID"
          exit 1
        fi
        set -e
        # Copy aside first. The running app is already gone, so a failed
        # ditto must not be the step that deletes it.
        NEXT="$DEST.new"
        rm -rf "$NEXT"
        ditto "$SRC" "$NEXT"
        rm -rf "$DEST"
        mv "$NEXT" "$DEST"
        set +e
        if [ -n "$ENT" ] && security find-identity -p codesigning -v 2>/dev/null | grep -F '"Ice Dev"' >/dev/null; then
          codesign --force --sign "Ice Dev" --timestamp=none --options runtime --entitlements "$ENT" "$DEST" || echo "codesign failed"
        fi
        if [ "$LAUNCH" = "1" ]; then
          open "$DEST"
        fi
        rm -rf "$(dirname "$SRC")"
        """
    }
}

/// Stops the first redirect so a release check can read the tag without the API.
private final class ReleaseRedirectStop: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: URL?

    var location: URL? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        lock.lock()
        stored = request.url
        lock.unlock()
        completionHandler(nil)
    }
}

#if DEBUG
enum ReleaseVersionTests {
    static func run() {
        func version(_ raw: String) -> ReleaseVersion {
            guard let parsed = ReleaseVersion(raw) else {
                fatalError("rejected \(raw)")
            }
            return parsed
        }
        precondition(version("27.0.1") < version("v27.0.2"))
        precondition(version("v27.0.1") == version("27.0.1"))
        precondition(!(version("27.0.2") < version("27.0.1")))
        precondition(version("1.0") < version("1.0.1"))
        precondition(version("1.0") == version("1.0.0"))
        precondition(version("27.0.2-beta") == version("27.0.2"))
        precondition(ReleaseVersion("nope") == nil)
        precondition(ReleaseVersion("") == nil)
        precondition(ReleaseVersion("v") == nil)

        let json = """
        {"tag_name":"v27.0.2","html_url":"https://github.com/itworksig/IcePlusPlus/releases/tag/v27.0.2","draft":false,"prerelease":false,"assets":[{"name":"Ice-arm64.dmg","browser_download_url":"https://example.com/Ice.dmg","size":11},{"name":"Ice.zip","browser_download_url":"https://example.com/Ice.zip","size":10}]}
        """
        guard let data = json.data(using: .utf8) else {
            fatalError("utf8")
        }
        guard let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) else {
            fatalError("decode")
        }
        precondition(release.tagName == "v27.0.2")
        precondition(GitHubUpdates.preferredAsset(in: release)?.name == "Ice.zip")

        let made = GitHubRelease.standardDownloads(tag: "v27.0.2")
        precondition(made?.tagName == "v27.0.2")
        precondition(
            GitHubUpdates.preferredAsset(in: made!)?.browserDownloadURL.absoluteString
                == "https://github.com/itworksig/IcePlusPlus/releases/download/v27.0.2/Ice.zip"
        )
        precondition(GitHubRelease.standardDownloads(tag: "nope") == nil)
    }
}
#endif
