import SwiftUI

struct AppSidebar: View {
    @Binding var selectedItem: SidebarItem

    var body: some View {
        ZStack {
            Color.white.opacity(0.16)
                .glassEffect(
                    .regular.tint(.white.opacity(0.24)),
                    in: .rect(cornerRadius: HomeDesign.sidebarCornerRadius)
                )
                .ignoresSafeArea()

            List(SidebarItem.allCases) { item in
                Button {
                    selectedItem = item
                } label: {
                    Label(item.title, systemImage: item.systemImage)
                        .symbolVariant(selectedItem == item ? .fill : .none)
                        .foregroundStyle(selectedItem == item ? HomeDesign.accentBlue : HomeDesign.primaryLabel)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(.rect)
                        .accessibilityAddTraits(selectedItem == item ? .isSelected : [])
                }
                .buttonStyle(.plain)
                .listRowBackground(selectedItem == item ? HomeDesign.accentBlue.opacity(0.14) : Color.clear)
            }
            .scrollContentBackground(.hidden)
            .padding(.top, 24)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(
            min: 260,
            ideal: HomeDesign.sidebarWidth,
            max: 360
        )
    }
}

#Preview {
    NavigationSplitView {
        AppSidebar(selectedItem: .constant(.home))
    } detail: {
        Text("Detail")
    }
}
