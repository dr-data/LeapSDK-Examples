import Foundation
import Network

struct DiscoveredTeacher: Identifiable {
    let id: String
    let name: String
    let endpoint: URL
    let classroomCode: String
}

@Observable
class BonjourDiscovery {
    var discoveredTeachers: [DiscoveredTeacher] = []
    var isSearching = false

    @ObservationIgnored private var browser: NWBrowser?
    @ObservationIgnored private var targetClassroomCode: String?

    func startDiscovery(classroomCode: String) {
        stopDiscovery()
        targetClassroomCode = classroomCode
        discoveredTeachers = []
        isSearching = true

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let browser = NWBrowser(
            for: .bonjour(type: "_leapchat._tcp", domain: nil),
            using: parameters
        )

        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                switch state {
                case .failed:
                    self?.isSearching = false
                case .cancelled:
                    self?.isSearching = false
                default:
                    break
                }
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                self?.handleBrowseResults(results)
            }
        }

        browser.start(queue: .main)
        self.browser = browser
    }

    func stopDiscovery() {
        browser?.cancel()
        browser = nil
        isSearching = false
    }

    @MainActor
    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        var teachers: [DiscoveredTeacher] = []

        for result in results {
            guard case .service(let name, let type, let domain, _) = result.endpoint else {
                continue
            }

            // Service name format: "teacherName-classroomCode"
            // e.g., "MrSmith-classroom123"
            let components = name.split(separator: "-", maxSplits: 1)
            let teacherName = components.first.map(String.init) ?? name
            let code = components.count > 1 ? String(components[1]) : ""

            // Filter by classroom code if specified
            if let target = targetClassroomCode, !target.isEmpty, code != target {
                continue
            }

            let serviceId = "\(name).\(type)\(domain)"
            let endpoint = URL(string: "http://\(name).local") ?? URL(string: "http://localhost")!

            let teacher = DiscoveredTeacher(
                id: serviceId,
                name: teacherName,
                endpoint: endpoint,
                classroomCode: code
            )
            teachers.append(teacher)
        }

        discoveredTeachers = teachers
    }
}
