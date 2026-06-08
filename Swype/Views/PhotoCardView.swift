import SwiftUI

enum SwipeDirection {
    case keep, delete, skip, none
}

struct PhotoCardView: View {
    let photoID: String
    let onSwipe: (SwipeDirection) -> Void
    let onTapUndo: () -> Void

    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm
    @State private var offset: CGSize = .zero
    @State private var image: UIImage?
    @State private var isDragging = false

    // Zoom state
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var zoomOffset: CGSize = .zero
    @State private var lastZoomOffset: CGSize = .zero
    private var isZoomed: Bool { scale > 1.01 }

    private var dragDirection: SwipeDirection {
        let w = offset.width, h = offset.height
        if abs(w) > abs(h) * 0.8 {
            if w > 40 { return .keep }
            if w < -40 { return .delete }
        } else if h < -40 {
            return .skip
        }
        return .none
    }

    private var rotation: Double { isZoomed ? 0 : Double(offset.width / 22) }
    private var keepOpacity: Double   { isZoomed ? 0 : max(0, min(1, Double(offset.width) / 80)) }
    private var deleteOpacity: Double { isZoomed ? 0 : max(0, min(1, Double(-offset.width) / 80)) }
    private var skipOpacity: Double   { isZoomed ? 0 : max(0, min(1, Double(-offset.height) / 80)) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                photoLayer(size: geo.size)
                keepBadge.opacity(keepOpacity)
                deleteBadge.opacity(deleteOpacity)
                skipBadge.opacity(skipOpacity)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
            .offset(isZoomed ? zoomOffset : offset)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(isZoomed ? scale : 1.0)
            .gesture(combinedDragGesture)
            .gesture(magnifyGesture)
            .onTapGesture {
                if isZoomed {
                    // Reset zoom
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        scale = 1.0; lastScale = 1.0
                        zoomOffset = .zero; lastZoomOffset = .zero
                    }
                } else if !isDragging {
                    onTapUndo()
                }
            }
        }
        .task {
            image = await vm.loadImage(for: photoID, targetSize: CGSize(width: 700, height: 900))
        }
    }

    // MARK: - Photo Layer

    private func photoLayer(size: CGSize) -> some View {
        ZStack {
            Theme.surface
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
                    .transition(.opacity.animation(.easeIn(duration: 0.25)))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.textTertiary)
                    ProgressView().tint(Theme.accent)
                }
            }
        }
    }

    // MARK: - Gestures

    // Single DragGesture that routes to pan (zoomed) or swipe (normal)
    private var combinedDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if isZoomed {
                    zoomOffset = CGSize(
                        width: lastZoomOffset.width + value.translation.width,
                        height: lastZoomOffset.height + value.translation.height
                    )
                } else {
                    isDragging = true
                    withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.8)) {
                        offset = value.translation
                    }
                }
            }
            .onEnded { value in
                if isZoomed {
                    lastZoomOffset = zoomOffset
                } else {
                    isDragging = false
                    let threshold: CGFloat = 110
                    let w = value.translation.width
                    let h = value.translation.height
                    if w > threshold || value.predictedEndTranslation.width > 300 {
                        flyOut(.keep)
                    } else if w < -threshold || value.predictedEndTranslation.width < -300 {
                        flyOut(.delete)
                    } else if h < -threshold || value.predictedEndTranslation.height < -300 {
                        flyOut(.skip)
                    } else {
                        snapBack()
                    }
                }
            }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                scale = min(max(scale * delta, 1.0), 4.0)
            }
            .onEnded { _ in
                lastScale = 1.0
                if scale < 1.05 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        scale = 1.0
                        zoomOffset = .zero
                        lastZoomOffset = .zero
                    }
                }
            }
    }

    private func flyOut(_ direction: SwipeDirection) {
        let target: CGSize
        switch direction {
        case .keep:   target = CGSize(width: 700, height: offset.height * 2)
        case .delete: target = CGSize(width: -700, height: offset.height * 2)
        case .skip:   target = CGSize(width: offset.width, height: -900)
        case .none:   return
        }
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.7)) {
            offset = target
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onSwipe(direction)
        }
    }

    private func snapBack() {
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.7)) {
            offset = .zero
        }
    }

    // MARK: - Badges

    private var keepBadge: some View {
        VStack {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark").font(.system(size: 14, weight: .black))
                    Text(lm.s.keepBadge).font(.system(size: 15, weight: .black, design: .rounded)).tracking(1.5)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(Color(.systemGreen)).shadow(color: Color(.systemGreen).opacity(0.5), radius: 8))
                .rotationEffect(.degrees(-12))
                .padding(.leading, 20).padding(.top, 32)
                Spacer()
            }
            Spacer()
        }
    }

    private var deleteBadge: some View {
        VStack {
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill").font(.system(size: 14, weight: .black))
                    Text(lm.s.deleteBadge).font(.system(size: 15, weight: .black, design: .rounded)).tracking(1.5)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(Color(.systemRed)).shadow(color: Color(.systemRed).opacity(0.5), radius: 8))
                .rotationEffect(.degrees(12))
                .padding(.trailing, 20).padding(.top, 32)
            }
            Spacer()
        }
    }

    private var skipBadge: some View {
        VStack {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill").font(.system(size: 14, weight: .black))
                Text(lm.s.laterBadge).font(.system(size: 15, weight: .black, design: .rounded)).tracking(1.5)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(Color(.systemOrange)).shadow(color: Color(.systemOrange).opacity(0.5), radius: 8))
            .padding(.top, 36)
            Spacer()
        }
    }
}
