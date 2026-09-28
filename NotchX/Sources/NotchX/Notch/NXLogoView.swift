import SwiftUI
import AppKit

/// Official NotchX "NX" Brand Logo component
public struct NXLogoView: View {
    private let height: CGFloat
    
    public init(height: CGFloat = 14) {
        self.height = height
    }
    
    public var body: some View {
        if let image = Self.loadedImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: height)
        } else {
            Text("NX")
                .font(.system(size: height, weight: .black, design: .rounded))
                .foregroundColor(.white)
        }
    }
    
    private static let loadedImage: NSImage? = {
        // 1. Try App Bundle Resources
        if let url = Bundle.main.url(forResource: "NXLogo", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        
        // 2. Try Workspace Source File Fallback
        let sourcePath = "/Users/vedant/Documents/Bleach/NotchX/Sources/NotchX/Resources/NXLogo.png"
        if let img = NSImage(contentsOfFile: sourcePath) {
            return img
        }
        
        return nil
    }()
}
