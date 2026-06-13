//
//  NSImage+Resize.swift
//
//  ReClipt
//
//  Created by ReClipt on 2026/06/11.
//
//  Copyright © 2026 ReClipt Project.
//

import Foundation
import Cocoa

extension NSImage {
    func resizeImage(_ width: CGFloat, _ height: CGFloat) -> NSImage? {
        guard let data = self.tiffRepresentation,
              let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(width, height)
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
    }

    func aspectFitImage(_ width: CGFloat, _ height: CGFloat) -> NSImage? {
        guard let newSize = aspectFitSize(width, height, allowsUpscaling: true),
              let image = copy() as? NSImage else {
            return nil
        }

        image.size = newSize
        return image
    }

    private func aspectFitSize(_ width: CGFloat, _ height: CGFloat, allowsUpscaling: Bool) -> NSSize? {
        guard width > 0, height > 0, size.width > 0, size.height > 0 else {
            return nil
        }

        let scale = min(width / size.width, height / size.height)
        let ratio = allowsUpscaling ? scale : min(scale, 1)
        return NSSize(
            width: max(1, floor(size.width * ratio)),
            height: max(1, floor(size.height * ratio))
        )
    }
}
