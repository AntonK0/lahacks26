import SwiftUI

struct AppSidebar: View {
    @Binding var selectedItem: SidebarItem
    let conversation: TutorConversationModel

    var body: some View {
        ZStack {
            Color.white.opacity(0.78)
                .glassEffect(
                    .regular.tint(.white.opacity(0.7)),
                    in: .rect(cornerRadius: HomeDesign.sidebarCornerRadius)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: HomeDesign.sidebarCornerRadius)
                        .fill(.white.opacity(0.42))
                }
                .ignoresSafeArea()

            VStack(spacing: 0) {
                List(SidebarItem.allCases) { item in
                    Button {
                        selectedItem = item
                    } label: {
                        Label(item.title, systemImage: item.systemImage)
                            .symbolVariant(selectedItem == item ? .fill : .none)
                            .font(.body)
                            .foregroundStyle(selectedItem == item ? HomeDesign.selectedOrange : HomeDesign.primaryLabel)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(.rect)
                            .accessibilityAddTraits(selectedItem == item ? .isSelected : [])
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .padding(.top, 64)

                GemmaReadinessIndicator(
                    isReady: conversation.isGemmaReady,
                    title: conversation.isGemmaReady ? "All Systems Active" : conversation.gemmaReadinessLabel,
                    detail: conversation.isGemmaReady ? "100%" : conversation.gemmaReadinessDetail
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .navigationSplitViewColumnWidth(
            min: 220,
            ideal: HomeDesign.sidebarWidth,
            max: 260
        )
    }
}

#Preview {
    let conversation = TutorConversationModel()

    NavigationSplitView {
        AppSidebar(selectedItem: .constant(.home), conversation: conversation)
    } detail: {
        Text("Detail")
    }
}
