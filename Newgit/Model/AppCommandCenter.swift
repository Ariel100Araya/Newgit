import Foundation
import Combine

final class AppCommandCenter: ObservableObject {
    @Published var selectedRepositoryPath: String? = nil

    var hasSelectedRepository: Bool {
        selectedRepositoryPath?.isEmpty == false
    }
}
