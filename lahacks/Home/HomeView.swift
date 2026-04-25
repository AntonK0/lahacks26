import SwiftUI

struct HomeView: View {
    @State private var selectedItem = SidebarItem.home

    var body: some View {
        NavigationSplitView {
            AppSidebar(selectedItem: $selectedItem)
        } detail: {
            switch selectedItem {
            case .home:
                HomeMainContent(scanAction: startScan)
            case .scan:
                ContentUnavailableView(
                    "Scan",
                    systemImage: selectedItem.systemImage,
                    description: Text("Book scanning will live here.")
                )
            case .discover:
                ContentUnavailableView(
                    "Discover",
                    systemImage: selectedItem.systemImage,
                    description: Text("Textbook discovery will live here.")
                )
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }

    private func startScan() {
        selectedItem = .scan
    }
}

#Preview {
    HomeView()
}
