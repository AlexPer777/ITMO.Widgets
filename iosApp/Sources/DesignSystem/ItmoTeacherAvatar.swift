import Shared
import SwiftUI
import UIKit

/// Resolves the photo when a teacher row appears, independently of navigation to the teacher's profile.
@MainActor
struct ItmoTeacherAvatar: View {
    let initials: String
    let isu: Int32?
    var size: CGFloat = 40
    @State private var image: UIImage?

    init(initials: String, isu: Int32?, size: CGFloat = 40) {
        self.initials = initials
        self.isu = isu
        self.size = size
        let url = isu.flatMap { IosTeacherPhotos.shared.cachedPhotoUrl(isu: $0) }.flatMap(URL.init(string:))
        _image = State(initialValue: url.flatMap { TeacherAvatarImages.cached($0) })
    }

    var body: some View {
        ItmoAvatarContent(
            initials: initials,
            phase: image.map { .success(Image(uiImage: $0)) } ?? .empty,
            size: size
        )
        .task(id: isu) {
            guard let isu, isu > 0 else { image = nil; return }
            let cachedUrl = IosTeacherPhotos.shared.cachedPhotoUrl(isu: isu).flatMap(URL.init(string:))
            image = cachedUrl.flatMap { TeacherAvatarImages.cached($0) }
            let address = try? await IosTeacherPhotos.shared.photoUrl(isu: isu)
            guard !Task.isCancelled, let address, let url = URL(string: address) else { return }
            let loaded = await TeacherAvatarImages.load(url)
            guard !Task.isCancelled else { return }
            image = loaded
        }
    }
}

/// Reused rows share the image and the request. URLSession also keeps normal HTTP disk-cache behaviour.
@MainActor
private enum TeacherAvatarImages {
    static let images: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 128
        cache.totalCostLimit = 20 * 1024 * 1024
        return cache
    }()
    static var pending: [URL: Task<UIImage?, Never>] = [:]

    static func cached(_ url: URL) -> UIImage? { images.object(forKey: url as NSURL) }

    static func load(_ url: URL) async -> UIImage? {
        if let image = cached(url) { return image }
        if let task = pending[url] { return await task.value }
        let task = Task<UIImage?, Never> {
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode),
                  let image = UIImage(data: data) else { return nil }
            let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? data.count
            images.setObject(image, forKey: url as NSURL, cost: cost)
            return image
        }
        pending[url] = task
        let image = await task.value
        pending[url] = nil
        return image
    }
}
