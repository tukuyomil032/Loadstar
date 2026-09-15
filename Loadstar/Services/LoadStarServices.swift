import LoadStarDomain
import LoadStarPlatform

public enum LoadStarServices: Sendable {
    public static let productName = LoadStarDomain.productName

    public static func makeLifecycleCoordinator(debug: Bool = true) -> ServerLifecycleCoordinator? {
        do {
            let namespace: StorageNamespace = debug ? .debug : .production
            let root = try ManagedRoot.applicationSupport(namespace: namespace)
            let fileSystem = try root.fileSystemClient()
            return ServerLifecycleCoordinator(
                metadataRepository: ManagedServerMetadataRepository(fileSystem: fileSystem),
                fileSystem: fileSystem,
                javaProvider: MacOSJavaRuntimeProvider(),
                processController: LocalProcessController(),
                pingClient: NetworkServerListPingClient(),
                eulaService: FileEULAService(fileSystem: fileSystem),
                checkpointStore: ManagedLifecycleCheckpointStore(fileSystem: fileSystem),
                serverDirectoryURL: { serverID in
                    (try? root.resolve(.serverDirectory(for: serverID))) ?? root.rootURL
                }
            )
        } catch {
            return nil
        }
    }
}
