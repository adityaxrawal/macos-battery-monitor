import Foundation

extension Date {
    var relativeTimeString: String {
        let secs = Int(-self.timeIntervalSinceNow)
        if secs < 60  { return "Just now" }
        if secs < 120 { return "1 min ago" }
        return "\(secs / 60) min ago"
    }
}
