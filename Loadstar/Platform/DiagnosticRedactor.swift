import Foundation
import LoadStarDomain

public struct DiagnosticRedactor: Sendable {
    public init() {}

    public func redact(_ detail: String) -> String {
        var result = detail
        result = replacingMatches(
            in: result,
            pattern: #"(?i)(authorization\s*:\s*bearer\s+|(?:token|password|secret|credential)\s*[=:]\s*)[^\s,;]+"#,
            template: "$1<redacted>"
        )
        result = replacingMatches(
            in: result,
            pattern: #"(?<![A-Za-z0-9_])/(?:private/)?(?:Users|home|tmp|var|Volumes|Library|Applications)/[^\s\"']+"#,
            template: "<redacted>"
        )
        return result
    }

    public func redact(_ issue: PersistenceIssue) -> PersistenceIssue {
        PersistenceIssue(
            code: issue.code,
            stage: issue.stage,
            documentType: issue.documentType,
            target: issue.target,
            userVisibleOutcome: redact(issue.userVisibleOutcome),
            retryability: issue.retryability,
            retainedData: issue.retainedData.map(redact),
            cleanupResult: issue.cleanupResult.map(redact),
            recoveryAction: issue.recoveryAction,
            redactedDetail: issue.redactedDetail.map(redact)
        )
    }

    private func replacingMatches(in value: String, pattern: String, template: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return value
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return expression.stringByReplacingMatches(in: value, range: range, withTemplate: template)
    }
}
