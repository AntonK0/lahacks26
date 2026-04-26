import SwiftUI

struct HomeView: View {
    @State private var selectedItem = SidebarItem.home
    @State private var scannedISBN: ISBN?
    @State private var scanSessionID = UUID()
    @State private var conversation = TutorConversationModel()

    var body: some View {
        NavigationSplitView {
            AppSidebar(selectedItem: $selectedItem, conversation: conversation)
        } detail: {
            switch selectedItem {
            case .home:
                HomeMainContent(scanAction: startScan)
            case .scan:
                scanContent
            case .discover:
                ContentUnavailableView(
                    "Discover",
                    systemImage: selectedItem.systemImage,
                    description: Text("Textbook discovery will live here.")
                )
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(HomeDesign.pageBackground, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .task {
            conversation.prepareModel()
        }
    }

    private func startScan() {
        selectedItem = .scan
    }

    @ViewBuilder
    private var scanContent: some View {
        if let scannedISBN {
            TutorARView(
                isbn: scannedISBN,
                conversation: conversation,
                scanAnotherBook: scanAnotherBook
            )
        } else {
            ISBNBarcodeScannerView(onISBNScanned: handleScannedISBN)
                .id(scanSessionID)
        }
    }

    private func handleScannedISBN(_ isbn: ISBN) {
        scannedISBN = isbn
    }

    private func scanAnotherBook() {
        conversation.stopInteraction()
        scannedISBN = nil
        scanSessionID = UUID()
    }
}

#Preview {
    HomeView()
}
