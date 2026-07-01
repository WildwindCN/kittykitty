import Flutter
import UIKit
import Vision
import CoreImage
import ImageIO

/// KittyKitty 猫咪检测插件 — iOS Vision Framework 实现
/// VNRecognizeAnimalsRequest: 识别图片中的猫
/// VNGenerateForegroundInstanceMask: 前景分割抠图
class CatDetectorPlugin: NSObject, FlutterPlugin {

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.kittykitty/detector",
            binaryMessenger: registrar.messenger()
        )
        let instance = CatDetectorPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSupported":
            // iOS 14.0+ 支持 VNRecognizeAnimalsRequest
            if #available(iOS 14.0, *) {
                result(true)
            } else {
                result(false)
            }

        case "detectFromPath":
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "path required", details: nil))
                return
            }
            detectCat(from: path, result: result)

        case "detectFromBytes":
            guard let args = call.arguments as? [String: Any],
                  let flutterData = args["bytes"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGS", message: "bytes required", details: nil))
                return
            }
            let tempPath = NSTemporaryDirectory() + "kittykitty_detect_\(UUID().uuidString).jpg"
            do {
                try flutterData.data.write(to: URL(fileURLWithPath: tempPath))
                detectCat(from: tempPath, result: result)
            } catch {
                result(FlutterError(code: "IO_ERROR", message: error.localizedDescription, details: nil))
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// 检测猫咪并返回 mask + 抠图
    private func detectCat(from imagePath: String, result: @escaping FlutterResult) {
        guard let ciImage = CIImage(contentsOf: URL(fileURLWithPath: imagePath)) else {
            result(["hasCat": false, "confidence": 0.0, "message": "无法加载图片"])
            return
        }

        // Step 1: 猫识别 (VNRecognizeAnimalsRequest)
        let animalRequest = VNRecognizeAnimalsRequest { [weak self] request, error in
            guard let self = self else { return }
            if let error = error {
                result(FlutterError(code: "VISION_ERROR", message: error.localizedDescription, details: nil))
                return
            }

            guard let observations = request.results as? [VNRecognizedObjectObservation],
                  !observations.isEmpty else {
                result(["hasCat": false, "confidence": 0.0, "message": "未检测到动物"])
                return
            }

            // 找到置信度最高的猫
            var bestCat: VNRecognizedObjectObservation?
            var bestConfidence: Float = 0
            for obs in observations {
                for label in obs.labels where label.identifier == "Cat" {
                    if label.confidence > bestConfidence {
                        bestConfidence = label.confidence
                        bestCat = obs
                    }
                }
            }

            guard let catObs = bestCat, bestConfidence > 0.3 else {
                result(["hasCat": false, "confidence": Double(bestConfidence), "message": "未检测到猫咪"])
                return
            }

            // Step 2: 前景分割 (VNGenerateForegroundInstanceMask)
            let maskRequest = VNGenerateForegroundInstanceMaskRequest { maskReq, maskErr in
                guard let maskResults = maskReq.results as? [VNInstanceMaskObservation],
                      !maskResults.isEmpty else {
                    // 只有检测结果，没有 mask
                    result([
                        "hasCat": true,
                        "confidence": Double(bestConfidence),
                        "maskImage": nil as FlutterStandardTypedData?,
                        "cutoutImage": nil as FlutterStandardTypedData?,
                        "metadata": ["message": "mask not available in this iOS version"]
                    ])
                    return
                }

                // 取第一个 mask (通常也是猫的)
                guard let mask = maskResults.first else {
                    result(["hasCat": true, "confidence": Double(bestConfidence)])
                    return
                }

                // 生成 mask 图像
                let maskPixelBuffer = mask.generateScaledMaskForImage(
                    forInstances: mask.allInstances,
                    from: self.handlerForImage(ciImage)
                )

                guard let maskPB = maskPixelBuffer else {
                    result(["hasCat": true, "confidence": Double(bestConfidence)])
                    return
                }

                let maskImage = CIImage(cvPixelBuffer: maskPB)
                let maskContext = CIContext()
                guard let maskCG = maskContext.createCGImage(maskImage, from: maskImage.extent) else {
                    result(["hasCat": true, "confidence": Double(bestConfidence)])
                    return
                }

                let maskData = NSMutableData()
                let maskDest = CGImageDestinationCreateWithData(maskData, "public.png" as CFString, 1, nil)!
                CGImageDestinationAddImage(maskDest, maskCG, nil)
                CGImageDestinationFinalize(maskDest)
                let maskBytes = FlutterStandardTypedData(bytes: maskData as Data)

                // 抠图: 原图与 mask 合成
                let ciCtx = CIContext()
                let maskedImage = maskImage.composited(over: CIImage(color: .clear))
                guard let cutoutCG = ciCtx.createCGImage(maskedImage, from: maskImage.extent) else {
                    result(["hasCat": true, "confidence": Double(bestConfidence)])
                    return
                }

                let cutoutData = NSMutableData()
                let cutoutDest = CGImageDestinationCreateWithData(cutoutData, "public.png" as CFString, 1, nil)!
                CGImageDestinationAddImage(cutoutDest, cutoutCG, nil)
                CGImageDestinationFinalize(cutoutDest)
                let cutoutBytes = FlutterStandardTypedData(bytes: cutoutData as Data)

                result([
                    "hasCat": true,
                    "confidence": Double(bestConfidence),
                    "maskImage": maskBytes,
                    "cutoutImage": cutoutBytes,
                    "metadata": ["method": "VNRecognizeAnimals + VNGenerateForegroundInstanceMask"]
                ])
            }

            // 需要 handler 来运行
            let handler = VNSequenceRequestHandler()
            do {
                try handler.perform([maskRequest], on: ciImage)
            } catch {
                // Mask 不可用，返回检测结果
                result([
                    "hasCat": true,
                    "confidence": Double(bestConfidence),
                    "maskImage": nil as FlutterStandardTypedData?,
                    "cutoutImage": nil as FlutterStandardTypedData?,
                ])
            }
        }

        let handler = VNImageRequestHandler(ciImage: ciImage)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([animalRequest])
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "VISION_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func handlerForImage(_ image: CIImage) -> VNImageRequestHandler {
        return VNImageRequestHandler(ciImage: image)
    }
}
