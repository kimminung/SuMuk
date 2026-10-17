// On-device analysis with Apple Vision (runs on this Mac; the same requests ship on iPhone).
// Usage: swift vision_ondevice.swift <input.jpg> <out.json>
// Emits: person-segmentation mask polygon(s), face landmark polylines, Vision contours, timings.
import Foundation
import Vision
import CoreImage
import ImageIO

struct Poly: Codable { let name: String; let closed: Bool; let points: [[Double]] } // normalized, origin bottom-left (Vision)
struct Output: Codable {
    var width: Int; var height: Int
    var timingsMs: [String: Double]
    var faceLandmarks: [Poly]
    var contours: [Poly]
    var personMaskPNGBase64: String?
    var contourCount: Int
}

func now() -> Double { Date().timeIntervalSince1970 * 1000 }

let args = CommandLine.arguments
guard args.count >= 3 else { print("usage: swift vision_ondevice.swift in.jpg out.json"); exit(1) }
let url = URL(fileURLWithPath: args[1])
guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
      let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { print("cannot load"); exit(1) }

var out = Output(width: cg.width, height: cg.height, timingsMs: [:], faceLandmarks: [], contours: [], personMaskPNGBase64: nil, contourCount: 0)

// 1) Face landmarks
do {
    let t0 = now()
    let req = VNDetectFaceLandmarksRequest()
    req.revision = VNDetectFaceLandmarksRequest.currentRevision
    let handler = VNImageRequestHandler(cgImage: cg, options: [:])
    try handler.perform([req])
    out.timingsMs["faceLandmarks"] = now() - t0
    if let face = (req.results ?? []).first, let lm = face.landmarks {
        let bb = face.boundingBox
        func conv(_ region: VNFaceLandmarkRegion2D?, _ name: String, closed: Bool) {
            guard let r = region else { return }
            let pts = r.normalizedPoints.map { p -> [Double] in
                [Double(bb.origin.x + p.x * bb.size.width), Double(bb.origin.y + p.y * bb.size.height)]
            }
            out.faceLandmarks.append(Poly(name: name, closed: closed, points: pts))
        }
        conv(lm.faceContour, "faceContour", closed: false)
        conv(lm.leftEyebrow, "leftEyebrow", closed: false)
        conv(lm.rightEyebrow, "rightEyebrow", closed: false)
        conv(lm.leftEye, "leftEye", closed: true)
        conv(lm.rightEye, "rightEye", closed: true)
        conv(lm.nose, "nose", closed: false)
        conv(lm.noseCrest, "noseCrest", closed: false)
        conv(lm.medianLine, "medianLine", closed: false)
        conv(lm.outerLips, "outerLips", closed: true)
        conv(lm.innerLips, "innerLips", closed: true)
        conv(lm.leftPupil, "leftPupil", closed: true)
        conv(lm.rightPupil, "rightPupil", closed: true)
    }
} catch { FileHandle.standardError.write("landmarks failed: \(error)\n".data(using: .utf8)!) }

// 2) Person segmentation (silhouette)
do {
    let t0 = now()
    let req = VNGeneratePersonSegmentationRequest()
    req.qualityLevel = .accurate
    req.outputPixelFormat = kCVPixelFormatType_OneComponent8
    let handler = VNImageRequestHandler(cgImage: cg, options: [:])
    try handler.perform([req])
    out.timingsMs["personSegmentation"] = now() - t0
    if let pb = req.results?.first?.pixelBuffer {
        let ci = CIImage(cvPixelBuffer: pb)
        let ctx = CIContext()
        if let maskCG = ctx.createCGImage(ci, from: ci.extent) {
            let data = NSMutableData()
            if let dest = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) {
                CGImageDestinationAddImage(dest, maskCG, nil)
                CGImageDestinationFinalize(dest)
                out.personMaskPNGBase64 = (data as Data).base64EncodedString()
            }
        }
    }
} catch { FileHandle.standardError.write("segmentation failed: \(error)\n".data(using: .utf8)!) }

// 3) Contours
do {
    let t0 = now()
    let req = VNDetectContoursRequest()
    req.contrastAdjustment = 1.5
    req.detectsDarkOnLight = true
    req.maximumImageDimension = 1024
    let handler = VNImageRequestHandler(cgImage: cg, options: [:])
    try handler.perform([req])
    out.timingsMs["contours"] = now() - t0
    if let obs = req.results?.first {
        out.contourCount = obs.contourCount
        // keep top-level contours with enough points, sorted by point count
        var polys: [Poly] = []
        for i in 0..<obs.contourCount {
            if let c = try? obs.contour(at: i), c.pointCount >= 40 {
                let pts = c.normalizedPoints.map { [Double($0.x), Double($0.y)] }
                polys.append(Poly(name: "contour\(i)", closed: true, points: pts))
            }
        }
        polys.sort { $0.points.count > $1.points.count }
        out.contours = Array(polys.prefix(40))
    }
} catch { FileHandle.standardError.write("contours failed: \(error)\n".data(using: .utf8)!) }

let enc = JSONEncoder()
let json = try enc.encode(out)
try json.write(to: URL(fileURLWithPath: args[2]))
print("ok landmarks=\(out.faceLandmarks.count) contours=\(out.contours.count)/\(out.contourCount) mask=\(out.personMaskPNGBase64 != nil) timings=\(out.timingsMs)")
