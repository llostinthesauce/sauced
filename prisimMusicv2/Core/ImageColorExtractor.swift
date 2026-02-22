import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

class ImageColorExtractor {
    static let shared = ImageColorExtractor()
    private let context = CIContext()
    
    func extractColors(from image: UIImage) -> [Color] {
        guard let inputImage = CIImage(image: image) else { return defaultColors }
        
        // This is a simplified "average color" extraction. 
        // A full palette extraction (like Vibrant.js) is more complex.
        // For MeshGradient, we want 3-9 diverse colors.
        
        // Approach: Crop image into 3x3 grid and take average of each sector
        var colors: [Color] = []
        let extent = inputImage.extent
        let width = extent.width / 3
        let height = extent.height / 3
        
        for y in 0..<3 {
            for x in 0..<3 {
                let rect = CGRect(x: CGFloat(x) * width, y: CGFloat(y) * height, width: width, height: height)
                if let color = getAverageColor(inputImage: inputImage, rect: rect) {
                    colors.append(color)
                } else {
                    colors.append(.black) // Fallback
                }
            }
        }
        
        // Ensure we have exactly 9 colors
        if colors.count < 9 {
            return defaultColors
        }
        
        return colors
    }
    
    private func getAverageColor(inputImage: CIImage, rect: CGRect) -> Color? {
        // let vectors = [CIVector(cgRect: rect)]
        let filter = CIFilter.areaAverage()
        filter.inputImage = inputImage
        filter.extent = rect
        
        guard let outputImage = filter.outputImage else { return nil }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        return Color(red: Double(bitmap[0]) / 255.0, 
                     green: Double(bitmap[1]) / 255.0, 
                     blue: Double(bitmap[2]) / 255.0)
    }
    
    private var defaultColors: [Color] {
        [.purple, .indigo, .blue, .blue, .black.opacity(0.8), .indigo, .black, .black, .purple]
    }
}
