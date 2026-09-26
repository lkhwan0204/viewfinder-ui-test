import SwiftUI
import PhotosUI
import ImageIO

/// 촬영을 마치면 "여기서 찍은 사진을 공유할까요?"
/// EXIF에서 촬영 정보를 읽고, 사진의 GPS가 포인트와 300m 안이면 "현장 인증"을 붙입니다.
struct UploadFrameSheet: View {
    let target: Frame

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var item: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var metadata: PhotoMetadata?
    @State private var caption = ""
    @State private var loading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("여기서 찍은 사진을 공유할까요?")
                        .font(VF.Typeface.title(20))
                        .foregroundStyle(VF.Palette.textPrimary)
                    Text("EXIF에서 촬영 정보를 자동으로 읽고, 위치가 포인트와 맞으면 '현장 인증'을 붙여요.")
                        .font(VF.Typeface.body(13))
                        .foregroundStyle(VF.Palette.textSecondary)

                    PhotosPicker(selection: $item, matching: .images) {
                        ZStack {
                            VF.Palette.surface
                            if let image {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 28, weight: .light))
                                    Text("사진 고르기")
                                        .font(VF.Typeface.label(14))
                                }
                                .foregroundStyle(VF.Palette.amber)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 220)
                        .viewfinderCorners(VF.Palette.amber.opacity(0.7), length: 14, lineWidth: 1.5, outset: 0)
                    }
                    .buttonStyle(.plain)

                    if loading {
                        ProgressView("사진 정보를 읽는 중…")
                    }

                    if let metadata {
                        metadataCard(metadata)
                    }

                    TextField("한 줄 설명 (예: 안개가 걷히기 직전)", text: $caption)
                        .textFieldStyle(.roundedBorder)

                    Button("공유하기") { share() }
                        .buttonStyle(.vfPrimary)
                        .disabled(image == nil)
                }
                .padding(20)
            }
            .navigationTitle(model.catalog.place(target.placeID)?.name ?? "공유")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("나중에") { dismiss() }
                }
            }
        }
        .onChange(of: item) { _, newItem in
            Task { await load(newItem) }
        }
    }

    private func metadataCard(_ meta: PhotoMetadata) -> some View {
        let verified = isVerified(meta)
        let exposure = [meta.aperture.map { apertureText($0) }, meta.shutterText, meta.iso.map { "ISO \($0)" }]
            .compactMap { $0 }
            .joined(separator: " · ")
        return VStack(alignment: .leading, spacing: 8) {
            row("렌즈", meta.focalLength35.map { "\($0)mm (35mm 환산)" } ?? "정보 없음")
            row("노출", exposure.isEmpty ? "정보 없음" : exposure)
            row("촬영 시각", meta.capturedAt.map { "\(VFFormat.dateLabel($0)) \(VFFormat.time($0))" } ?? "정보 없음")
            HStack(spacing: 8) {
                Image(systemName: verified ? "checkmark.seal.fill" : "questionmark.circle")
                Text(verificationText(meta, verified: verified))
            }
            .font(VF.Typeface.label(13, weight: .semibold))
            .foregroundStyle(verified ? VF.Palette.amber : VF.Palette.textSecondary)
            .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VF.Palette.surface, in: RoundedRectangle(cornerRadius: VF.Metric.corner))
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(VF.Typeface.label(12))
                .foregroundStyle(VF.Palette.textTertiary)
                .frame(width: 64, alignment: .leading)
            Text(verbatim: value)
                .font(VF.Typeface.mono(12))
                .foregroundStyle(VF.Palette.textPrimary)
        }
    }

    private func isVerified(_ meta: PhotoMetadata) -> Bool {
        guard let coordinate = meta.coordinate else { return false }
        return GeoMath.distance(coordinate, target.coordinate) < 300
    }

    private func verificationText(_ meta: PhotoMetadata, verified: Bool) -> String {
        guard let coordinate = meta.coordinate else { return "사진에 위치 정보가 없어 미인증으로 올라가요" }
        let distance = VFFormat.distance(GeoMath.distance(coordinate, target.coordinate))
        return verified ? "현장 인증 · 포인트에서 \(distance)" : "포인트와 \(distance) 떨어져 있어 미인증이에요"
    }

    private func apertureText(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? "f/\(Int(value))" : "f/" + String(format: "%.1f", value)
    }

    private func load(_ newItem: PhotosPickerItem?) async {
        guard let newItem else { return }
        loading = true
        defer { loading = false }
        guard let data = try? await newItem.loadTransferable(type: Data.self),
              let picked = UIImage(data: data) else { return }
        image = picked
        metadata = PhotoMetadata.read(from: data)
    }

    private func share() {
        guard let image else { return }
        let meta = metadata
        let camera = CameraSettings(
            focalLength: meta?.focalLength35 ?? target.camera.focalLength,
            aperture: meta?.aperture ?? target.camera.aperture,
            shutter: meta?.shutterText ?? target.camera.shutter,
            iso: meta?.iso ?? target.camera.iso,
            tripod: false
        )
        let frame = Frame(
            id: "user-\(UUID().uuidString.prefix(8))",
            placeID: target.placeID,
            spotID: target.spotID,
            caption: caption.trimmingCharacters(in: .whitespaces).isEmpty ? "여기서 찍은 한 장" : caption,
            photographer: "@me",
            capturedAt: meta?.capturedAt ?? Date(),
            camera: camera,
            heading: target.heading,
            coordinate: meta?.coordinate ?? target.coordinate,
            standingNote: target.standingNote,
            scenes: target.scenes,
            conditions: [],
            weather: "현장 기록",
            aspectRatio: Double(image.size.width / max(image.size.height, 1)),
            mood: target.mood,
            art: target.art,
            prominence: 0.7,
            verified: meta.map { isVerified($0) } ?? false,
            imageName: nil
        )
        model.addUserFrame(frame, image: image)
        Haptics.success()
        dismiss()
    }
}

/// ImageIO로 읽은 촬영 정보
struct PhotoMetadata {
    var focalLength35: Int?
    var aperture: Double?
    var exposure: Double?
    var iso: Int?
    var capturedAt: Date?
    var coordinate: GeoPoint?

    var shutterText: String? {
        guard let exposure, exposure > 0 else { return nil }
        return exposure >= 1 ? "\(Int(exposure))s" : "1/\(Int((1 / exposure).rounded()))"
    }

    static func read(from data: Data) -> PhotoMetadata? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }
        var meta = PhotoMetadata()
        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            meta.focalLength35 = (exif[kCGImagePropertyExifFocalLenIn35mmFilm] as? NSNumber)?.intValue
            meta.aperture = (exif[kCGImagePropertyExifFNumber] as? NSNumber)?.doubleValue
            meta.exposure = (exif[kCGImagePropertyExifExposureTime] as? NSNumber)?.doubleValue
            meta.iso = (exif[kCGImagePropertyExifISOSpeedRatings] as? [NSNumber])?.first?.intValue
            if let original = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
                meta.capturedAt = exifDate(original)
            }
        }
        if let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
           let latitude = (gps[kCGImagePropertyGPSLatitude] as? NSNumber)?.doubleValue,
           let longitude = (gps[kCGImagePropertyGPSLongitude] as? NSNumber)?.doubleValue {
            let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String ?? "N"
            let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String ?? "E"
            meta.coordinate = GeoPoint(latRef == "S" ? -latitude : latitude, lonRef == "W" ? -longitude : longitude)
        }
        return meta
    }

    private static func exifDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: string)
    }
}
