import SwiftUI

struct HomeView: View {
    @State private var selectedItem = SidebarItem.home
    @State private var scannedISBN: ISBN?

    var body: some View {
        NavigationSplitView {
            AppSidebar(selectedItem: $selectedItem)
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
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }

    private func startScan() {
        selectedItem = .scan
    }

    @ViewBuilder
    private var scanContent: some View {
        if let scannedISBN {
            TutorARView(isbn: scannedISBN, scanAnotherBook: scanAnotherBook)
        } else {
            ISBNBarcodeScannerView(onISBNScanned: handleScannedISBN)
        }
    }

    private func handleScannedISBN(_ isbn: ISBN) {
        scannedISBN = isbn
    }

    private func scanAnotherBook() {
        scannedISBN = nil
    }
}

#Preview {
    HomeView()
}
