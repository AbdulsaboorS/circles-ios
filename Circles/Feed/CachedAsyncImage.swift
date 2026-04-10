import SwiftUI
import UIKit

// MARK: - ImageCache

/// In-memory NSCache keyed by URL string. Auto-evicts under memory pressure.
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 80
        cache.totalCostLimit = 60 * 1024 * 1024 // 60 MB
    }

    subscript(key: String) -> UIImage? {
        get { cache.object(forKey: key as NSString) }
        set {
            guard let img = newValue else { return }
            let cost = Int(img.size.width * img.size.height * 4)
            cache.setObject(img, forKey: key as NSString, cost: cost)
        }
    }
}

// MARK: - CachedAsyncImage

/// Drop-in AsyncImage replacement with NSCache backing.
/// The download task is cancelled automatically when the view disappears.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: String
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var loaded: UIImage? = nil

    var body: some View {
        Group {
            if let loaded {
                content(Image(uiImage: loaded))
            } else {
                placeholder()
            }
        }
        .task(id: url) { await fetch() }
    }

    private func fetch() async {
        if let cached = ImageCache.shared[url] { loaded = cached; return }
        guard let urlObj = URL(string: url) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: urlObj)
            guard !Task.isCancelled, let img = UIImage(data: data) else { return }
            ImageCache.shared[url] = img
            loaded = img
        } catch { /* placeholder stays visible */ }
    }
}
