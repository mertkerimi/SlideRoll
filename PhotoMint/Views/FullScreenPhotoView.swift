import SwiftUI

struct FullScreenPhotoView: View {
    let photoID: String
    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(\.dismiss) var dismiss

    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero

    private var dismissProgress: CGFloat {
        let distance = sqrt(pow(dragOffset.width, 2) + pow(dragOffset.height, 2))
        return min(distance / 180, 1.0)
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(1.0 - Double(dismissProgress) * 0.6)
                .ignoresSafeArea()

            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale * (1.0 - dismissProgress * 0.2))
                    .offset(
                        x: offset.width + dragOffset.width,
                        y: offset.height + dragOffset.height
                    )
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = max(1.0, lastScale * value)
                                }
                                .onEnded { _ in
                                    if scale < 1.0 {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            scale = 1.0; offset = .zero
                                        }
                                    }
                                    lastScale = scale
                                },
                            DragGesture()
                                .onChanged { value in
                                    if scale > 1.01 {
                                        // Zoom modunda pan
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    } else {
                                        // Normal modda dismiss drag
                                        dragOffset = value.translation
                                    }
                                }
                                .onEnded { value in
                                    if scale > 1.01 {
                                        lastOffset = offset
                                    } else {
                                        let distance = sqrt(
                                            pow(value.translation.width, 2) +
                                            pow(value.translation.height, 2)
                                        )
                                        if distance > 120 {
                                            dismiss()
                                        } else {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                dragOffset = .zero
                                            }
                                        }
                                    }
                                }
                        )
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if scale > 1.0 {
                                scale = 1.0; lastScale = 1.0
                                offset = .zero; lastOffset = .zero
                            } else {
                                scale = 2.5; lastScale = 2.5
                            }
                        }
                    }
            } else {
                ProgressView().tint(.white).scaleEffect(1.3)
            }

            // Close button — kaybolur dismiss sırasında
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Circle().fill(.black.opacity(0.5)))
                    }
                    .opacity(1.0 - Double(dismissProgress) * 2)
                    .padding(.trailing, 20)
                    .padding(.top, 56)
                }
                Spacer()
            }
        }
        .task {
            // Load full resolution
            image = await vm.loadImage(
                for: photoID,
                targetSize: PHImageManagerMaximumSize
            )
        }
    }
}

private let PHImageManagerMaximumSize = CGSize(width: 4096, height: 4096)
