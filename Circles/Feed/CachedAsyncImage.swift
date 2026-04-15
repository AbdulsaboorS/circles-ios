import SwiftUI
import UIKit

// MARK: - ImageCache

/// In-memory NSCache keyed by a caller-supplied cache identity. Auto-evicts under memory pressure.
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
    let cacheKey: String
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var loaded: UIImage? = nil

    init(
        url: String,
        cacheKey: String? = nil,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.cacheKey = cacheKey ?? url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let loaded {
                content(Image(uiImage: loaded))
            } else {
                placeholder()
            }
        }
        .task(id: taskID) { await fetch() }
    }

    private var taskID: String {
        "\(cacheKey)|\(url)"
    }

    private func fetch() async {
        if let cached = ImageCache.shared[cacheKey] {
            loaded = cached
            return
        }

        loaded = nil
        guard let urlObj = URL(string: url) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: urlObj)
            guard !Task.isCancelled, let img = UIImage(data: data) else { return }
            ImageCache.shared[cacheKey] = img
            loaded = img
        } catch { /* placeholder stays visible */ }
    }
}

enum CachedImagePrefetcher {
    static func prefetch(url: String, cacheKey: String) async {
        if ImageCache.shared[cacheKey] != nil { return }
        guard let urlObject = URL(string: url) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: urlObject)
            guard let image = UIImage(data: data) else { return }
            ImageCache.shared[cacheKey] = image
        } catch {
            return
        }
    }
}
