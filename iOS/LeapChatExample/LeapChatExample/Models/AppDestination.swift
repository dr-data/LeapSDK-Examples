import Foundation

enum AppDestination: Hashable {
  case aiProviders
  case localModelsBrowser
  case modelDetail(ModelDefinition)
}
