import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Limite le nombre de téléchargements d'images simultanés
/// pour éviter de saturer le CPU/réseau lors du scroll rapide.
actor ImageLoader {
    static let shared = ImageLoader()
    
    private let maxConcurrent = 4  // Réduit de 8 à 4
    private var active = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    /// Session dédiée aux images avec limites de connexions
    nonisolated let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 2
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        // Pas de cache URLCache pour éviter la RAM
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: config)
    }()

    func prefetch(urls: [URL], size: CGFloat) async {
        let uniqueUrls = Array(Set(urls))
        for url in uniqueUrls {
            if await ImageCache.shared.image(for: url) != nil { continue }
            await acquire()
            defer { release() }

            if await ImageCache.shared.image(for: url) != nil { continue }

            do {
                let (data, _) = try await session.data(from: url)
                
                // Essayer le downsampling
                let options = [kCGImageSourceShouldCache: false] as CFDictionary
                if let source = CGImageSourceCreateWithData(data as CFData, options),
                   CGImageSourceGetCount(source) > 0,
                   CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete {
                    let maxDimension = max(size * 3.0, 1)
                    let downsampleOptions = [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceShouldCacheImmediately: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: maxDimension
                    ] as CFDictionary

                    if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) {
                        #if canImport(UIKit)
                        let uiImg = UIImage(cgImage: cgImage)
                        await ImageCache.shared.storeNative(uiImg, for: url)
                        #elseif canImport(AppKit)
                        let nsImg = NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
                        await ImageCache.shared.storeNative(nsImg, for: url)
                        #endif
                        continue
                    }
                }
                
                // Si downsampling échoue, charger l'image brute
                #if canImport(UIKit)
                if let uiImg = UIImage(data: data) {
                    await ImageCache.shared.storeNative(uiImg, for: url)
                }
                #elseif canImport(AppKit)
                if let nsImg = NSImage(data: data) {
                    await ImageCache.shared.storeNative(nsImg, for: url)
                }
                #endif
            } catch {
                continue
            }
        }
    }
    
    func acquire() async {
        if active < maxConcurrent {
            active += 1
            return
        }
        await withCheckedContinuation { cont in
            waiters.append(cont)
        }
    }
    
    func release() {
        if let next = waiters.first {
            waiters.removeFirst()
            next.resume()
        } else {
            active -= 1
        }
    }

    private func prefetchSingle(url: URL, size: CGFloat) async {
        if await ImageCache.shared.image(for: url) != nil { return }

        await acquire()
        defer { release() }

        if await ImageCache.shared.image(for: url) != nil { return }

        do {
            let (data, _) = try await session.data(from: url)

            let options = [kCGImageSourceShouldCache: false] as CFDictionary
            guard let source = CGImageSourceCreateWithData(data as CFData, options),
                  CGImageSourceGetCount(source) > 0,
                  CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete else { return }

            let maxDimension = max(size * 3.0, 1)
            let downsampleOptions = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension
            ] as CFDictionary

            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else { return }

            #if canImport(UIKit)
            let uiImg = UIImage(cgImage: cgImage)
            await ImageCache.shared.storeNative(uiImg, for: url)
            #elseif canImport(AppKit)
            let nsImg = NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
            await ImageCache.shared.storeNative(nsImg, for: url)
            #endif
        } catch {
        }
    }
    
    /// Précharge des URLs en arrière-plan (fire-and-forget, ne bloque pas)
    nonisolated func prefetchAhead(urls: [URL], size: CGFloat) {
        for url in urls {
            Task(priority: .utility) {
                await ImageLoader.shared.prefetchSingle(url: url, size: size)
            }
        }
    }
}

/// Cache d'images en mémoire utilisant NSCache pour la gestion automatique de la mémoire.
/// Marqué @MainActor pour simplifier l'utilisation avec UIImage/SwiftUI.
@MainActor
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    
    #if canImport(UIKit)
    private let cache = NSCache<NSURL, UIImage>()
    #elseif canImport(AppKit)
    private let cache = NSCache<NSURL, NSImage>()
    #endif
    
    private init() {
        // Cache modéré : assez pour couvrir les images visibles + un buffer,
        // sans gonfler la RAM. NSCache purge automatiquement sous pression mémoire.
        cache.countLimit = 100
        cache.totalCostLimit = 25 * 1024 * 1024 // 25 MB      
        #if canImport(UIKit)
        // Écouter les memory warnings et vider le cache automatiquement
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.clearCache()
            }
        }
        
        // Vider le cache quand l'app passe en arrière-plan
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.clearCache()
            }
        }
        #endif
    }
    
    /// Vide complètement le cache pour libérer la RAM
    func clearCache() {
        // Force le nettoyage dans un autorelease pool pour libérer immédiatement
        autoreleasepool {
            cache.removeAllObjects()
        }
        
        // Force le compactage mémoire si disponible (iOS 13+)
        #if canImport(UIKit)
        if #available(iOS 13.0, *) {
            // Trigger memory pressure simulation pour forcer iOS à libérer
            Task { @MainActor in
                // Petit hack: recréer le cache force la libération des anciennes références
                let oldLimit = cache.countLimit
                let oldCost = cache.totalCostLimit
                cache.countLimit = 0
                cache.totalCostLimit = 0
                cache.countLimit = oldLimit
                cache.totalCostLimit = oldCost
            }
        }
        #endif
    }
    
    func image(for url: URL) -> Image? {
        #if canImport(UIKit)
        guard let uiImg = cache.object(forKey: url as NSURL) else { return nil }
        return Image(uiImage: uiImg)
        #elseif canImport(AppKit)
        guard let nsImg = cache.object(forKey: url as NSURL) else { return nil }
        return Image(nsImage: nsImg)
        #else
        return nil
        #endif
    }
    
    #if canImport(UIKit)
    func uiImage(for url: URL) -> UIImage? {
        return cache.object(forKey: url as NSURL)
    }
    #endif
    
    #if canImport(UIKit)
    func storeNative(_ image: UIImage, for url: URL) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
    #elseif canImport(AppKit)
    func storeNative(_ image: NSImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
    #endif
}

/// Vue d'image avec cache. Résout le problème d'AsyncImage qui échoue
/// lors du scroll rapide dans LazyVGrid.
struct CachedAsyncImage: View {
    let url: URL?
    let size: CGFloat
    let contentMode: ContentMode
    
    @State private var phase: LoadPhase
    @State private var lastImage: Image? = nil
    
    @AppStorage("app_store_mode") private var isAppStoreMode: Bool = false
    
    init(url: URL?, size: CGFloat, contentMode: ContentMode = .fit) {
        self.url = url
        self.size = size
        self.contentMode = contentMode
        
        if let url = url, let cached = ImageCache.shared.image(for: url) {
            _phase = State(initialValue: .success(cached))
            _lastImage = State(initialValue: cached)
        } else {
            _phase = State(initialValue: .loading)
            _lastImage = State(initialValue: nil)
        }
    }
    
    enum LoadPhase {
        case loading
        case success(Image)
        case failure
    }

    private var phaseKey: Int {
        switch phase {
        case .loading: return 0
        case .success: return 1
        case .failure: return 2
        }
    }
    
    var body: some View {
        ZStack {
            if case .loading = phase, let lastImage {
                lastImage
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            }

            if case .success(let image) = phase {
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
                    #if canImport(UIKit)
                    .modifier(PixelatedImageModifier(url: url, isAppStoreMode: isAppStoreMode))
                    #endif
            } else if case .failure = phase {
                Image(systemName: "photo")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            } else if case .loading = phase, lastImage == nil {
                Color.clear
            }
        }
        .animation(.easeInOut(duration: 0.25), value: phaseKey)
        .frame(width: size, height: size)
        .onDisappear {
            // Libérer IMMÉDIATEMENT (pas d'animation) → RAM descend
            phase = .loading
            lastImage = nil
        }
        .task(id: url) {
            // Toujours check si la nouvelle URL est en cache
            if let url = url, let cached = ImageCache.shared.image(for: url) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    phase = .success(cached)
                    lastImage = cached
                }
                return
            }
            
            // Si pas en cache, reset à loading et charge asynchrone
            if case .success = phase {
                phase = .loading
            }
            
            // Débounce court pour les téléchargements réseau
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let url = url else {
            phase = .failure
            return
        }
        
        // Re-check cache
        if let cached = ImageCache.shared.image(for: url) {
            phase = .success(cached)
            return
        }
        
        await ImageLoader.shared.acquire()
        
        guard !Task.isCancelled else {
            await ImageLoader.shared.release()
            return
        }
        
        let targetSize = size
        
        do {
            let (data, _) = try await ImageLoader.shared.session.data(from: url)
            
            guard !Task.isCancelled else {
                await ImageLoader.shared.release()
                return
            }
            
            let image: Image? = autoreleasepool {
                let options = [kCGImageSourceShouldCache: false] as CFDictionary
                if let source = CGImageSourceCreateWithData(data as CFData, options),
                   CGImageSourceGetCount(source) > 0,
                   CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete {
                    let maxDimension = max(targetSize * 3.0, 1)
                    let downsampleOptions = [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceShouldCacheImmediately: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: maxDimension
                    ] as CFDictionary
                    
                    if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) {
                        #if canImport(UIKit)
                        let uiImg = UIImage(cgImage: cgImage)
                        ImageCache.shared.storeNative(uiImg, for: url)
                        return Image(uiImage: uiImg)
                        #elseif canImport(AppKit)
                        let nsImg = NSImage(cgImage: cgImage, size: NSSize(width: targetSize, height: targetSize))
                        ImageCache.shared.storeNative(nsImg, for: url)
                        return Image(nsImage: nsImg)
                        #else
                        return nil
                        #endif
                    }
                }
                
                // Si downsampling échoue, charger l'image brute
                #if canImport(UIKit)
                if let uiImg = UIImage(data: data) {
                    ImageCache.shared.storeNative(uiImg, for: url)
                    return Image(uiImage: uiImg)
                }
                #elseif canImport(AppKit)
                if let nsImg = NSImage(data: data) {
                    ImageCache.shared.storeNative(nsImg, for: url)
                    return Image(nsImage: nsImg)
                }
                #endif
                
                return nil
            }
            
            await ImageLoader.shared.release()
            
            if let image = image {
                withAnimation(.easeInOut(duration: 0.25)) {
                    phase = .success(image)
                }
                lastImage = image
            } else {
                withAnimation(.easeInOut(duration: 0.25)) {
                    phase = .failure
                }
            }
        } catch {
            await ImageLoader.shared.release()
            if !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.25)) {
                    phase = .failure
                }
            }
        }
    }
}

#if canImport(UIKit)
import CoreImage
import CoreImage.CIFilterBuiltins

/// Singleton pour appliquer un filtre de pixellisation
class PixelationFilter {
    static let shared = PixelationFilter()
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    func pixelate(image: UIImage, scale: Float = 12.0) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        let filter = CIFilter.pixellate()
        filter.inputImage = ciImage
        filter.scale = scale
        guard let outputCIImage = filter.outputImage,
              let cgImage = context.createCGImage(outputCIImage, from: outputCIImage.extent) else {
            return image
        }
        return UIImage(cgImage: cgImage)
    }
}

struct PixelatedImageModifier: ViewModifier {
    let url: URL?
    let isAppStoreMode: Bool
    
    @State private var pixelatedImage: Image? = nil
    
    func body(content: Content) -> some View {
        if isAppStoreMode, let u = url {
            Group {
                if let pix = pixelatedImage {
                    pix
                        .resizable()
                        .interpolation(.none) // Anti-blur pour les gros pixels
                } else {
                    // Masqué le temps de générer le filtre
                    content
                        .opacity(0.1)
                        .overlay { ProgressView() }
                }
            }
            .task(id: u.absoluteString + "\(isAppStoreMode)") {
                guard isAppStoreMode else { return }
                
                var imageToProcess: UIImage? = nil
                
                if let uiImg = ImageCache.shared.uiImage(for: u) {
                    imageToProcess = uiImg
                } else {
                    // Fallback pour AsyncImage classique (ex: header HD)
                    if let data = try? await URLSession.shared.data(from: u).0,
                       let downloaded = UIImage(data: data) {
                        imageToProcess = downloaded
                    }
                }
                
                if let img = imageToProcess {
                    let pixelated = PixelationFilter.shared.pixelate(image: img, scale: 15.0)
                    pixelatedImage = Image(uiImage: pixelated)
                }
            }
        } else {
            content
        }
    }
}
#endif
