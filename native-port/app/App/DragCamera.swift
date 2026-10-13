import Foundation

/// Muguet-style relative dragging. Each finger has its own dead zone; the
/// camera receives movement once, without a second floating joystick.
struct DragCamera {
    private struct Finger { var start: CGPoint; var last: CGPoint; var active = false }
    private var fingers: [ObjectIdentifier: Finger] = [:]
    private var pending = CGPoint.zero

    mutating func begin(_ id: ObjectIdentifier, at point: CGPoint) {
        fingers[id] = Finger(start: point, last: point)
    }
    mutating func move(_ id: ObjectIdentifier, to point: CGPoint) {
        guard var finger = fingers[id], point.x.isFinite, point.y.isFinite else { return }
        let delta = CGPoint(x: point.x - finger.last.x, y: point.y - finger.last.y)
        finger.last = point
        if !finger.active && hypot(point.x - finger.start.x, point.y - finger.start.y) < 2.5 {
            fingers[id] = finger
            return
        }
        finger.active = true
        fingers[id] = finger
        pending.x += delta.x; pending.y += delta.y
    }
    mutating func end(_ id: ObjectIdentifier) { fingers[id] = nil }
    mutating func reset() { fingers.removeAll(); pending = .zero }

    /// Keep assisted aiming on pad 0. Relative finger motion becomes a pad
    /// velocity for this poll only; a resting finger always returns zero.
    mutating func velocity(elapsed: Double, sensitivity: Double, aimed: Bool) -> CGPoint {
        let delta = pending
        pending = .zero
        guard elapsed.isFinite, elapsed > 0, elapsed <= 0.05 else { return .zero }
        let seconds = max(elapsed, 1.0 / 240)
        let gain = min(max(sensitivity, 0.1), 4)
        let speed = hypot(delta.x, delta.y) / seconds
        // Acceleration depends on velocity, not the number of UIKit events.
        let acceleration = aimed ? 1.0 : 1 + min(speed / 600, 1.5)
        return CGPoint(x: delta.x / seconds * gain * acceleration,
                       y: -delta.y / seconds * gain * acceleration * 0.85)
    }
}
