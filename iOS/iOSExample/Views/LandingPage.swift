import SwiftUI
import SwiftData
struct LandingPage<T>: View where T: XXDKP {
    @State private var moveUp: Bool = false
    @State private var showProgress: Bool = false
    @EnvironmentObject var xxdk: T
    @EnvironmentObject private var swiftDataActor: SwiftDataActor
    @State private var navigationPath = NavigationPath()
    @State private var isLoadingDone = false
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("XXNetwork").bold().font(.system(size: 22, design: .serif))
                    Text("Haven App.").multilineTextAlignment(.leading).font(.system(size: 12, design: .serif))
                }

                if showProgress && !isLoadingDone {
                    ProgressView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            Task {
                                xxdk.setModelContainer(mActor: swiftDataActor)
                                await xxdk.load()
                                await MainActor.run {
                                    isLoadingDone = true
                                    navigationPath.append(Destination.home)
                                }
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.5), value: moveUp)
            .animation(.spring(response: 0.5, dampingFraction: 0.9), value: showProgress)
            .task {
                // 1) Hide progress for 1s (your comment says 2s, code had 1s)
                try? await Task.sleep(nanoseconds: 1_000_000_000)

                // 2) Move text up
                withAnimation(.easeInOut(duration: 2)) { moveUp = true }

                // 3) Slight delay, then reveal progress with a transition
                try? await Task.sleep(nanoseconds: 300_000_000)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                    showProgress = true
                }
            }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .home:
                    HomeView<XXDK>(width: UIScreen.w(100))
                        .navigationTitle("Home").navigationBarBackButtonHidden()
                case let .chat(chatId, chatTitle):
                    ChatView<XXDK>(width: UIScreen.w(100), chatId: chatId, chatTitle: chatTitle)
                }
            }
        }
    }
}



#Preview {
    let container = try! ModelContainer(
        for: Chat.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    ["Tom", "Mayur", "Shashank"].forEach { name in
        container.mainContext.insert(Chat(pubKey: name.data, name: name, dmToken: 0))
    }
    return LandingPage<XXDKMock>().environmentObject(XXDKMock()).modelContainer(container)
}
