import SwiftUI
import UIKit

struct ViewControllerFinder: UIViewControllerRepresentable {
    let onFind: (UIViewController) -> Void
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        DispatchQueue.main.async { onFind(vc) }
        return vc
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
