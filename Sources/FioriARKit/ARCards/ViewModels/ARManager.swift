//
//  ARManager.swift
//
//
//  Created by O'Brien, Patrick on 5/21/21.
//

import ARKit
import Combine
import RealityKit
import SwiftUI

/// Stores and manages common functional for the ARView
///
/// - Parameters:
///  - arView: The RealityKit ARView which provides the scene and ARSession for the AR Experience
///  - sceneRoot: The root for a strategy which uses a single Anchor
///  - onSceneUpate: Closure which is called on every frame update
///  - worldMap: Optional stored reference for a ARWorldMap
///  - referenceImages: List of current ARReferenceImages which have been loaded into the configuration
///  - detectionObjects: List of current ARReferenceImages which have been loaded into the configuration
/// ```
public class ARManager {
    internal var arView: ARView?
    public var sceneRoot: HasAnchoring?
    public var onSceneUpate: ((SceneEvents.Update) -> Void)?
    
    var worldMap: ARWorldMap?
    var referenceImages: Set<ARReferenceImage> = []
    var detectionObjects: Set<ARReferenceObject> = []
    
    var subscription: Cancellable!

    public init() {
        self.setup(canBeFatal: true)
    }

    internal init(canBeFatal: Bool) {
        self.setup(canBeFatal: canBeFatal)
    }
    
    internal func setup(canBeFatal: Bool = true) {
        self.arView = ARView(frame: .zero)

        do {
            try self.configureSession(with: ARWorldTrackingConfiguration())
        } catch {
            if canBeFatal {
                fatalError(error.localizedDescription)
            } else {
                print(error)
            }
        }
        self.subscription = self.arView?.scene.subscribe(to: SceneEvents.Update.self) { [unowned self] in
            onSceneUpate?($0)
        }
    }
    
    /// Cleans up the arView which is necessary for SwiftUI navigation
    internal func tearDown() {
        self.arView = nil
        self.subscription = nil
    }
    
    /// Set the configuration for the ARView's session with run options
    public func configureSession(with configuration: ARConfiguration, options: ARSession.RunOptions = []) throws {
        #if !targetEnvironment(simulator)
            self.arView?.session.run(configuration, options: options)
        #else
            throw ARManagerError.fioriARKitDoesNotSupportSimulatorError
        #endif
    }
    
    /// Set the session for automatic configuration
    public func setAutomaticConfiguration() {
        #if !targetEnvironment(simulator)
            self.arView?.automaticallyConfigureSession = true
        #endif
    }

    internal func setDelegate(to delegate: ARSessionDelegate) {
        #if !targetEnvironment(simulator)
            self.arView?.session.delegate = delegate
        #endif
    }

    internal func addARKitAnchor(for anchor: ARAnchor, children: [Entity] = []) {
        #if !targetEnvironment(simulator)
            let anchorEntity = AnchorEntity(anchor: anchor)
            children.forEach { anchorEntity.addChild($0) }
            self.addAnchor(for: anchorEntity)
        #endif
    }
    
    // An image should use world tracking so we set the configuration to prevent automatic switching to Image Tracking
    // Object Detection inherently uses world tracking so an automatic configuration can be used
    internal func setupScene(anchorImage: UIImage?, physicalWidth: CGFloat?, scene: HasAnchoring) throws {
        #if !targetEnvironment(simulator)
            switch scene.anchoring.target {
            case .image:
                guard let image = anchorImage, let width = physicalWidth else { return }
                self.sceneRoot = scene
                self.addReferenceImage(for: image, with: width)
            case .object:
                self.setAutomaticConfiguration()
                self.addAnchor(for: scene)
            default:
                throw LoadingStrategyError.anchorTypeNotSupportedError
            }
        #endif
    }
    
    /// Adds a Entity which conforms to HasAnchoring to the arView.scene
    public func addAnchor(for entity: HasAnchoring) {
        self.arView?.scene.addAnchor(entity)
    }
    
    /// Adds an ARReferenceImage to the configuration for the session to discover
    /// Optionally can set the configuration to ARImageTrackingConfiguration
    public func addReferenceImage(for image: UIImage, _ name: String? = nil, with physicalWidth: CGFloat, configuration: ARConfiguration = ARWorldTrackingConfiguration()) {
        guard let referenceImage = createReferenceImage(image, name, physicalWidth) else { return }
        self.referenceImages.insert(referenceImage)
        
        if let worldConfig = configuration as? ARWorldTrackingConfiguration {
            worldConfig.detectionImages = self.referenceImages
            do { try self.configureSession(with: worldConfig) } catch { print(error.localizedDescription) }
        } else if let imageConfig = configuration as? ARImageTrackingConfiguration {
            imageConfig.trackingImages = self.referenceImages
            do { try self.configureSession(with: imageConfig) } catch { print(error.localizedDescription) }
        }
    }
    
    private func createReferenceImage(_ uiImage: UIImage, _ name: String? = nil, _ physicalWidth: CGFloat) -> ARReferenceImage? {
        guard let cgImage = createCGImage(uiImage: uiImage) else { return nil }
        let image = ARReferenceImage(cgImage, orientation: .up, physicalWidth: physicalWidth)
        image.name = name
        return image
    }
    
    private func createCGImage(uiImage: UIImage) -> CGImage? {
        guard let ciImage = CIImage(image: uiImage) else { return nil }
        let context = CIContext(options: nil)
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}

private enum ARManagerError: Error, LocalizedError {
    case fioriARKitDoesNotSupportSimulatorError
    
    public var errorDescription: String? {
        switch self {
        case .fioriARKitDoesNotSupportSimulatorError:
            return NSLocalizedString("FioriARKit does not support the Simulator", comment: "")
        }
    }
}
