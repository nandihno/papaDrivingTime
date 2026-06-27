extension Int {
    /// Returns a (value, unit) pair for displaying a minute duration.
    /// e.g. 95 → ("1h 35", "min"), 45 → ("45", "min"), 60 → ("1", "hr")
    var durationComponents: (String, String) {
        if self < 60 {
            return ("\(self)", "min")
        }
        let hours = self / 60
        let mins = self % 60
        if mins == 0 {
            return ("\(hours)", "hr")
        }
        return ("\(hours)h \(mins)", "min")
    }
}
