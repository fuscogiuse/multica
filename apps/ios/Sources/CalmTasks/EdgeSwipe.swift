import SwiftUI
import UIKit

/// A real left-edge pan recognizer, the same one the system uses for "back". It starts the sidebar drag
/// and reports the finger, so the drawer follows it without SwiftUI gesture conflicts.
struct EdgeSwipe: UIViewRepresentable {
    var onChanged: (CGFloat) -> Void
    var onEnded: (_ translation: CGFloat, _ velocity: CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let pan = UIScreenEdgePanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handle(_:)))
        pan.edges = .left
        view.addGestureRecognizer(pan)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject {
        var parent: EdgeSwipe
        init(_ parent: EdgeSwipe) { self.parent = parent }

        @objc func handle(_ gesture: UIScreenEdgePanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view).x
            switch gesture.state {
            case .changed:
                parent.onChanged(translation)
            case .ended, .cancelled, .failed:
                parent.onEnded(translation, gesture.velocity(in: gesture.view).x)
            default:
                break
            }
        }
    }
}
