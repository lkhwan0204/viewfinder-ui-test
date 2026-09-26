import SwiftUI

// MARK: - Filter chip

/// 탐색 상단의 가로 칩. 사진 위에 떠 있으므로 항상 어두운 배경을 전제로 합니다.
struct FilterChip: View {
    let title: String
    let symbol: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(VF.Typeface.label(13))
            }
            .padding(.horizontal, 11)
            .frame(height: 30)
            .foregroundStyle(isOn ? VF.Palette.onAmber : Color.white.opacity(0.92))
            .background(isOn ? VF.Palette.amber : Color.black.opacity(0.38), in: RoundedRectangle(cornerRadius: VF.Metric.corner))
            .overlay(
                RoundedRectangle(cornerRadius: VF.Metric.corner)
                    .stroke(isOn ? Color.clear : Color.white.opacity(0.22), lineWidth: VF.Metric.hairline)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - EXIF strip

/// 필름 테두리처럼 들어가는 촬영 데이터 (SF Mono)
struct ExifStrip: View {
    let frame: Frame
    var color: Color = Color.white.opacity(0.62)

    var body: some View {
        HStack(spacing: 12) {
            Text(verbatim: "\(frame.camera.focalLength)mm")
            Text(verbatim: frame.camera.apertureText)
            Text(verbatim: frame.camera.shutter)
            Text(verbatim: "ISO \(frame.camera.iso)")
            Spacer(minLength: 8)
            Text(verbatim: VFFormat.time(frame.capturedAt))
        }
        .font(VF.Typeface.mono(11))
        .foregroundStyle(color)
        .lineLimit(1)
        .padding(.top, 8)
        .overlay(alignment: .top) {
            Rectangle().fill(color.opacity(0.3)).frame(height: VF.Metric.hairline)
        }
    }
}

// MARK: - Section header

/// 01 포인트 / 02 빛 타임라인 … 번호는 앰버 모노로
struct SectionHeader: View {
    let index: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: index)
                    .font(VF.Typeface.mono(11, weight: .medium))
                    .foregroundStyle(VF.Palette.amber)
                Text(title)
                    .font(VF.Typeface.title(19))
                    .foregroundStyle(VF.Palette.textPrimary)
            }
            if let subtitle {
                Text(subtitle)
                    .font(VF.Typeface.body(13))
                    .foregroundStyle(VF.Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Buttons

struct VFPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(configuration: configuration)
    }

    private struct PrimaryButtonBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(VF.Typeface.label(15, weight: .semibold))
                .foregroundStyle(isEnabled ? VF.Palette.onAmber : VF.Palette.textTertiary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    (isEnabled ? VF.Palette.amber : VF.Palette.surface).opacity(configuration.isPressed ? 0.8 : 1),
                    in: RoundedRectangle(cornerRadius: VF.Metric.corner)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
}

struct VFSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(VF.Typeface.label(15, weight: .medium))
            .foregroundStyle(VF.Palette.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(VF.Palette.textPrimary.opacity(configuration.isPressed ? 0.08 : 0), in: RoundedRectangle(cornerRadius: VF.Metric.corner))
            .overlay(RoundedRectangle(cornerRadius: VF.Metric.corner).stroke(VF.Palette.textPrimary.opacity(0.3), lineWidth: 1))
    }
}

extension ButtonStyle where Self == VFPrimaryButtonStyle {
    static var vfPrimary: VFPrimaryButtonStyle { VFPrimaryButtonStyle() }
}

extension ButtonStyle where Self == VFSecondaryButtonStyle {
    static var vfSecondary: VFSecondaryButtonStyle { VFSecondaryButtonStyle() }
}

// MARK: - Small labels

struct TagLabel: View {
    let text: String
    var symbol: String? = nil
    var tint: Color = VF.Palette.textSecondary

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(VF.Typeface.label(11))
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .frame(height: 22)
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(tint.opacity(0.45), lineWidth: VF.Metric.hairline))
    }
}

/// EXIF와 위치가 일치하는 사진에 붙는 "현장 인증"
struct VerifiedBadge: View {
    var body: some View {
        Label("현장 인증", systemImage: "checkmark.seal.fill")
            .font(VF.Typeface.label(11))
            .foregroundStyle(VF.Palette.amber)
    }
}

// MARK: - Film strip sprockets

/// 필름 스트립의 스프로킷 구멍 한 줄
struct SprocketRow: View {
    var hole: Color = VF.Palette.background

    var body: some View {
        GeometryReader { geo in
            let count = max(1, Int(geo.size.width / 14))
            HStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(hole)
                        .frame(width: 7, height: 5)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 11)
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(VF.Palette.amber)
                .frame(width: 64, height: 64)
                .viewfinderCorners(VF.Palette.amber.opacity(0.6), length: 10, lineWidth: 1, outset: 0)
            Text(title)
                .font(VF.Typeface.title(17))
                .foregroundStyle(VF.Palette.textPrimary)
            Text(message)
                .font(VF.Typeface.body(14))
                .foregroundStyle(VF.Palette.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.vfSecondary)
                    .frame(maxWidth: 220)
                    .padding(.top, 4)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Toast

/// "언젠가 롤에 담았어요" 같은 짧은 확인 메시지
struct ToastLabel: View {
    let text: String
    var symbol: String = "checkmark"

    var body: some View {
        Label(text, systemImage: symbol)
            .font(VF.Typeface.label(13))
            .foregroundStyle(VF.Palette.onAmber)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(VF.Palette.amber, in: RoundedRectangle(cornerRadius: VF.Metric.corner))
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }
}
