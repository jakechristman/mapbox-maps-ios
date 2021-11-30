import UIKit

internal protocol PanGestureHandlerProtocol: GestureHandler {
    var decelerationFactor: CGFloat { get set }

    var panMode: PanMode { get set }
}

/// `PanGestureHandler` updates the map camera in response to a single-touch pan gesture
internal final class PanGestureHandler: GestureHandler, PanGestureHandlerProtocol {

    /// A constant factor that influences how long a pan gesture takes to decelerate
    internal var decelerationFactor: CGFloat = UIScrollView.DecelerationRate.normal.rawValue

    /// A setting configures the direction in which the map is allowed to move
    /// during a pan gesture
    internal var panMode: PanMode = .horizontalAndVertical

    /// The touch location in the gesture's view when the gesture began
    private var previousTouchLocation: CGPoint?

    /// The date when the most recent gesture changed event was handled
    private var lastChangedDate: Date?

    private let mapboxMap: MapboxMapProtocol

    private let cameraAnimationsManager: CameraAnimationsManagerProtocol

    /// Provides access to the current date in a way that can be mocked
    /// for unit testing
    private let dateProvider: DateProvider

    private var isPanning = false

    internal init(gestureRecognizer: UIPanGestureRecognizer,
                  mapboxMap: MapboxMapProtocol,
                  cameraAnimationsManager: CameraAnimationsManagerProtocol,
                  dateProvider: DateProvider) {
        gestureRecognizer.maximumNumberOfTouches = 1
        self.mapboxMap = mapboxMap
        self.cameraAnimationsManager = cameraAnimationsManager
        self.dateProvider = dateProvider
        super.init(gestureRecognizer: gestureRecognizer)
        gestureRecognizer.addTarget(self, action: #selector(handleGesture(_:)))
    }

    @objc private func handleGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let view = gestureRecognizer.view else {
            return
        }

        let touchLocation = gestureRecognizer.location(in: view)

        switch gestureRecognizer.state {
        case .began:
            guard !pointIsAboveHorizon(touchLocation) else {
                return
            }
            previousTouchLocation = touchLocation
            mapboxMap.dragStart(for: touchLocation)
            delegate?.gestureBegan(for: .pan)
            isPanning = true
        case .changed:
            guard let previousTouchLocation = previousTouchLocation else {
                if !pointIsAboveHorizon(touchLocation) {
                    self.previousTouchLocation = touchLocation
                    mapboxMap.dragStart(for: touchLocation)
                    delegate?.gestureBegan(for: .pan)
                    isPanning = true
                }
                return
            }
            lastChangedDate = dateProvider.now
            let clampedTouchLocation = clampTouchLocation(
                touchLocation,
                previousTouchLocation: previousTouchLocation)
            handleChange(
                withTouchLocation: clampedTouchLocation,
                previousTouchLocation: previousTouchLocation)
            self.previousTouchLocation = clampedTouchLocation
        case .ended:
            // Only decelerate if the gesture ended quickly. Otherwise,
            // you get a deceleration in situations where you drag, then
            // hold the touch in place for several seconds, then release
            // it without further dragging. This specific time interval
            // is just the result of manual tuning.
            let decelerationTimeout: TimeInterval = 1.0 / 30.0
            guard let lastChangedDate = lastChangedDate,
                  isPanning,
                  !pointIsAboveHorizon(touchLocation),
                  dateProvider.now.timeIntervalSince(lastChangedDate) < decelerationTimeout else {
                      previousTouchLocation = nil
                      self.lastChangedDate = nil
                      if isPanning {
                          mapboxMap.dragEnd()
                          delegate?.gestureEnded(for: .pan, willAnimate: false)
                      }
                      isPanning = false
                      return
                  }
            isPanning = false
            // Set the dragging origin always to the bottom of screen.
            let velocity = gestureRecognizer.velocity(in: view)
            // Tilted map horizontal movement needs to be adjusted to behave similar
            // to platform scroll UIScrollView.DecelerationRate
            // Here, we adjust it only for upward fling
            var adjustedDecelerationFactor = decelerationFactor
            if (velocity.y < 0.0) {
                adjustedDecelerationFactor -= sin(mapboxMap.cameraState.pitch * Double.pi / 180) * 0.0035
            }
            var previousDecelerationLocation = touchLocation
            previousDecelerationLocation.y = mapboxMap.size.height
            cameraAnimationsManager.decelerate(
                location: previousDecelerationLocation,
                velocity: velocity,
                decelerationFactor: adjustedDecelerationFactor,
                locationChangeHandler: { (touchLocation) in
                    self.handleChange(
                        withTouchLocation: touchLocation,
                        previousTouchLocation: previousDecelerationLocation)
                    previousDecelerationLocation = touchLocation
                },
                completion: { [mapboxMap] in
                    mapboxMap.dragEnd()
                    self.delegate?.animationEnded(for: .pan)
                })
            self.previousTouchLocation = nil
            self.lastChangedDate = nil
            delegate?.gestureEnded(for: .pan, willAnimate: true)
        case .cancelled:
            // no deceleration
            previousTouchLocation = nil
            lastChangedDate = nil
            if isPanning {
                mapboxMap.dragEnd()
                delegate?.gestureEnded(for: .pan, willAnimate: false)
            }
            isPanning = false
        default:
            break
        }
    }

    private func clampTouchLocation(_ touchLocation: CGPoint, previousTouchLocation: CGPoint) -> CGPoint {
        switch panMode {
        case .horizontal:
            return CGPoint(x: touchLocation.x, y: previousTouchLocation.y)
        case .vertical:
            return CGPoint(x: previousTouchLocation.x, y: touchLocation.y)
        case .horizontalAndVertical:
            return touchLocation
        }
    }

    private func handleChange(withTouchLocation touchLocation: CGPoint, previousTouchLocation: CGPoint) {
        mapboxMap.setCamera(
            to: mapboxMap.dragCameraOptions(
                from: previousTouchLocation,
                to: touchLocation))
    }

    private func pointIsAboveHorizon(_ point: CGPoint) -> Bool {
        let topMargin = 0.04 * mapboxMap.size.height
        let reprojectErrorMargin = min(10, topMargin / 2)
        var p = point
        p.y -= topMargin
        let coordinate = mapboxMap.coordinate(for: p)
        let roundtripPoint = mapboxMap.point(for: coordinate)
        return roundtripPoint.y >= p.y + reprojectErrorMargin
    }
}
