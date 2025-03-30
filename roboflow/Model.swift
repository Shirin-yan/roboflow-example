//
//  Model.swift
//  roboflow
//
//  Created by  Shirin-Yan on 26.03.2025.
//

import Foundation
import UIKit

struct RoboflowResponse: Codable {
    let inference_id: String?
    let image: ImageSize?
    let predictions: [Prediction]
}

struct Prediction: Codable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let confidence: CGFloat
    let class_id: Int
    let `class`: String
}

struct ImageSize: Codable {
    let width: CGFloat
    let height: CGFloat
}

struct DetectedObject {
    let imgSize: ImageSize?
    let detectedRect: CGRect
    let `class`: String
    let color: UIColor
}
