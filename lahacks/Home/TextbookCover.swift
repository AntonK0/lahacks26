import SwiftUI

struct TextbookCover: View {
    let textbook: HomeTextbook
    var size: CGFloat = 80

    var body: some View {
        Image(textbook.imageName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 4)
            .accessibilityLabel(textbook.title)
    }
}

#Preview {
    TextbookCover(
        textbook: HomeTextbook(
            id: "college-algebra",
            title: "College Algebra 2e",
            imageName: "CollegeAlgebraCover"
        )
    )
    .padding()
}
