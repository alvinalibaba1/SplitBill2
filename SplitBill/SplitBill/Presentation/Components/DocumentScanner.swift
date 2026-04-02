//
//  DocumentScanner.swift
//  SplitBill
//

import SwiftUI
import Vision
import VisionKit

struct DocumentScanner: UIViewControllerRepresentable {
    var onScan: ([String]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) { }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var onScan: ([String]) -> Void

        init(onScan: @escaping ([String]) -> Void) {
            self.onScan = onScan
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var observed: [(text: String, y: CGFloat)] = []
            let request = VNRecognizeTextRequest { request, _ in
                guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
                for obs in observations {
                    if let candidate = obs.topCandidates(1).first {
                        observed.append((candidate.string, obs.boundingBox.origin.y))
                    }
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "id-ID"]
            let queue = DispatchQueue.global(qos: .userInitiated)
            let handlerGroup = DispatchGroup()

            for page in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: page)
                guard let cgImage = image.cgImage else { continue }
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                handlerGroup.enter()
                queue.async {
                    defer { handlerGroup.leave() }
                    try? handler.perform([request])
                }
            }

            handlerGroup.notify(queue: .main) {
                // Here is where we also implement LoadingState cleanup requested previously if needed
                controller.dismiss(animated: true) {
                    let sorted = observed.sorted { $0.y > $1.y }.map { $0.text }
                    self.onScan(sorted)
                }
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }
    }
}
