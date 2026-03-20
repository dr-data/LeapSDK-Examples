import Foundation

enum DownloadStatus: Equatable {
  case notDownloaded
  case downloading(progress: Double)
  case downloaded
  case failed(message: String)

  static func == (lhs: DownloadStatus, rhs: DownloadStatus) -> Bool {
    switch (lhs, rhs) {
    case (.notDownloaded, .notDownloaded): return true
    case (.downloaded, .downloaded): return true
    case (.downloading(let a), .downloading(let b)): return a == b
    case (.failed(let a), .failed(let b)): return a == b
    default: return false
    }
  }
}
