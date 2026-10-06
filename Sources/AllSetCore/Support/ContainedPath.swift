import Foundation

/// Paths that must stay inside a folder All Set owns. Used wherever a path that
/// came from a file (a catalog entry, a saved item) is read, written or deleted,
/// so `../`, an absolute path, a symlink or a sibling folder whose name merely
/// starts the same (`Dropped-Other` next to `Dropped`) can't reach anything else.
public enum ContainedPath {
    /// `relative` inside `root`, or nil if it's empty, absolute, contains `..`,
    /// or resolves (symlinks included) outside `root`.
    public static func resolve(_ relative: String, in root: URL) -> URL? {
        guard !relative.isEmpty, !relative.hasPrefix("/"), !relative.hasPrefix("~"),
              !relative.split(separator: "/").contains("..") else { return nil }
        let candidate = root.appendingPathComponent(relative)
        return contains(candidate, in: root) ? candidate : nil
    }

    /// Whether `url` lies strictly inside `root`: compared path component by path
    /// component after resolving symlinks, never as a string prefix.
    public static func contains(_ url: URL, in root: URL) -> Bool {
        let base = resolved(root).pathComponents
        let path = resolved(url).pathComponents
        return path.count > base.count && Array(path.prefix(base.count)) == base
    }

    /// The path with every symlink resolved, including in its existing parent
    /// folders when the file itself doesn't exist yet (`resolvingSymlinksInPath`
    /// leaves a path alone then, so a link in a parent would go unnoticed).
    static func resolved(_ url: URL, realpath resolver: Resolver = { Darwin.realpath($0, $1) }) -> URL {
        var existing = url.standardizedFileURL
        var rest: [String] = []
        var real = realPath(existing.path, resolver)
        while real == nil, existing.path != "/" {
            rest.insert(existing.lastPathComponent, at: 0)
            existing.deleteLastPathComponent()
            real = realPath(existing.path, resolver)
        }
        guard let real else { return url.standardizedFileURL }
        return rest.reduce(URL(fileURLWithPath: real)) { $0.appendingPathComponent($1) }
    }

    /// libc's `realpath(path, buffer)`: replaceable so a test can see every call
    /// made and whether any of them asked libc to allocate the result.
    typealias Resolver = (_ path: UnsafePointer<CChar>, _ buffer: UnsafeMutablePointer<CChar>?) -> UnsafeMutablePointer<CChar>?

    /// `realpath` into a buffer of our own: asking libc to allocate the result
    /// (a nil buffer) hands back memory the caller must free, and a call made
    /// only to see whether the path exists leaked it every time.
    private static func realPath(_ path: String, _ resolver: Resolver) -> String? {
        withUnsafeTemporaryAllocation(of: CChar.self, capacity: Int(PATH_MAX) + 1) { buffer in
            guard let base = buffer.baseAddress, resolver(path, base) != nil else { return nil }
            return String(cString: base)
        }
    }
}
