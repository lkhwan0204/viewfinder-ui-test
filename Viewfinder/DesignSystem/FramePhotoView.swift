import SwiftUI

/// 프레임 사진. 실제 이미지(업로드 또는 Assets)가 있으면 그것을, 없으면 플레이스홀더 장면을 그립니다.
/// 원칙: 메인 뷰에서는 절대 크롭하지 않습니다 (aspect fit).
struct FramePhotoView: View {
    let frame: Frame
    @Environment(AppModel.self) private var model

    var body: some View {
        if let image = model.image(for: frame) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            PlaceholderArtView(art: frame.art)
                .aspectRatio(CGFloat(frame.aspectRatio), contentMode: .fit)
        }
    }
}

/// 정사각 썸네일. fill = true면 정사각형을 채웁니다 (지도 마커처럼 아주 작은 썸네일 전용).
struct FrameThumbnail: View {
    let frame: Frame
    var size: CGFloat
    var fill: Bool = true
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            VF.Palette.matte
            if let image = model.image(for: frame) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: fill ? .fill : .fit)
            } else {
                PlaceholderArtView(art: frame.art)
                    .aspectRatio(CGFloat(frame.aspectRatio), contentMode: fill ? .fill : .fit)
            }
        }
        .frame(width: size, height: size)
        .clipped()
    }
}
