//
//  Model.swift
//  roboflow
//
//  Created by  Shirin-Yan on 26.03.2025.
//

import Foundation

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
}

struct ImageSize: Codable {
    let width: CGFloat
    let height: CGFloat
}

struct DetectedObject: Codable {
    let imgSize: ImageSize?
    let detectedRect: CGRect
}
