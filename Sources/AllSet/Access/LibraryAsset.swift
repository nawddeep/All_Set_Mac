import AllSetCore
import AVFoundation

extension AVURLAsset {
    /// A wallpaper's asset. Today every one plays from its downloaded file; one
    /// streamed from the library's host would carry the access token, as every
    /// other request there does (`LibraryAuthorization`).
    static func library(_ url: URL) -> AVURLAsset {
        let headers = LibraryAuthorization.shared.headers(for: url)
        guard !headers.isEmpty else { return AVURLAsset(url: url) }
        // AVURLAssetHTTPHeaderFieldsKey: honoured by AVFoundation but not in the macOS SDK.
        return AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
    }
}
