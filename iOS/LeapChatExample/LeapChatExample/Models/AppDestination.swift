import Foundation

enum AppDestination: Hashable {
    case appHome
    case aiProviders
    case openRouterConfig
    case localModelsBrowser
    case customBackends
    case customBackendEdit(CustomBackend?)
    case modelDetail(ModelDefinition)
    case modelDetailPopup(ModelDefinition)
}
