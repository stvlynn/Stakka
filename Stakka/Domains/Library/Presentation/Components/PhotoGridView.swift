import SwiftUI

struct PhotoGridView: View {
    let images: [ImportedImage]
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Label("\(images.count)", systemImage: "photo.on.rectangle.angled")
                    .font(.stakkaHeadline)
                    .foregroundStyle(Color.starWhite)

                Spacer()

                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.galaxyPink)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: Spacing.sm)], spacing: Spacing.sm) {
                ForEach(images) { importedImage in
                    Image(uiImage: importedImage.image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .continuousCorners(CornerRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                .stroke(Color.cosmicBlue.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.spaceSurface.opacity(0.3))
        .continuousCorners(CornerRadius.lg)
    }
}
