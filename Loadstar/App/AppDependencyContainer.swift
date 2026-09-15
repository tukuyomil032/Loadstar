import LoadStarDomain
import LoadStarServices

struct AppDependencyContainer: Sendable {
    let productName = LoadStarDomain.productName
    let coordinator: ServerLifecycleCoordinator?

    init() {
        coordinator = LoadStarServices.makeLifecycleCoordinator(debug: true)
    }
}
