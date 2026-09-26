import SwiftUI

struct RollDetailView: View {
    let rollID: UUID
    var onOpenPlace: (Frame) -> Void
    var onPlan: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var downloading = false
    @State private var progress: Double = 0
    @State private var showRename = false
    @State private var newName = ""
    @State private var confirmDelete = false

    var body: some View {
        if let roll = model.roll(rollID) {
            content(roll)
        } else {
            ContentUnavailableView("롤을 찾을 수 없어요", systemImage: "film")
        }
    }

    private func content(_ roll: Roll) -> some View {
        let frames = model.frames(in: roll)
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                FilmStrip(frames: frames, frameHeight: 140)

                HStack(spacing: 10) {
                    Button(action: onPlan) {
                        Label("촬영 계획 만들기", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    }
                    .buttonStyle(.vfPrimary)
                    .disabled(frames.isEmpty)

                    Button {
                        startDownload(roll)
                    } label: {
                        Label(roll.isOfflineReady ? "오프라인 저장됨" : "오프라인 저장",
                              systemImage: roll.isOfflineReady ? "checkmark.circle.fill" : "arrow.down.circle")
                    }
                    .buttonStyle(.vfSecondary)
                    .disabled(roll.isOfflineReady || downloading || frames.isEmpty)
                }
                .padding(.horizontal, 20)

                if downloading {
                    ProgressView(value: progress) {
                        Text("지도와 포인트 정보를 내려받는 중… (산·섬처럼 통신이 약한 곳 대비)")
                            .font(VF.Typeface.mono(11))
                            .foregroundStyle(VF.Palette.textSecondary)
                    }
                    .tint(VF.Palette.amber)
                    .padding(.horizontal, 20)
                }

                VStack(spacing: 0) {
                    ForEach(frames) { frame in
                        RollFrameRow(
                            frame: frame,
                            onOpen: { onOpenPlace(frame) },
                            onField: { model.openInField(frame.id) },
                            onRemove: { withAnimation(.snappy) { model.remove(frame.id, from: roll.id) } }
                        )
                    }
                }
                .padding(.horizontal, 20)

                if !frames.isEmpty {
                    Text("길게 누르면 필드 모드로 바로 가거나 롤에서 뺄 수 있어요")
                        .font(VF.Typeface.body(12))
                        .foregroundStyle(VF.Palette.textTertiary)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 16)
        }
        .background(VF.Palette.background)
        .navigationTitle(roll.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        newName = roll.name
                        showRename = true
                    } label: {
                        Label("이름 바꾸기", systemImage: "pencil")
                    }
                    if !roll.isDefault {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Label("롤 삭제", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("롤 이름", isPresented: $showRename) {
            TextField("이름", text: $newName)
            Button("저장") { model.renameRoll(roll.id, to: newName) }
            Button("취소", role: .cancel) {}
        }
        .confirmationDialog("이 롤을 삭제할까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                model.deleteRoll(roll.id)
                dismiss()
            }
        } message: {
            Text("다른 롤에 담긴 프레임은 그대로 남아요.")
        }
    }

    /// 프로토타입: 실제 다운로드 대신 진행 상태만 보여주고 롤을 "오프라인 준비됨"으로 표시합니다.
    private func startDownload(_ roll: Roll) {
        downloading = true
        progress = 0
        Task { @MainActor in
            for step in 1...25 {
                try? await Task.sleep(nanoseconds: 70_000_000)
                progress = Double(step) / 25
            }
            downloading = false
            model.markOfflineReady(roll.id)
            Haptics.success()
        }
    }
}

struct RollFrameRow: View {
    let frame: Frame
    var onOpen: () -> Void
    var onField: () -> Void
    var onRemove: () -> Void

    @Environment(AppModel.self) private var model

    var body: some View {
        let place = model.catalog.place(frame.placeID)
        let phase = model.catalog.phase(of: frame)
        Button(action: onOpen) {
            HStack(spacing: 12) {
                FrameThumbnail(frame: frame, size: 64, fill: false)
                VStack(alignment: .leading, spacing: 3) {
                    Text(place?.name ?? "")
                        .font(VF.Typeface.label(15, weight: .semibold))
                        .foregroundStyle(VF.Palette.textPrimary)
                    Text(frame.caption)
                        .font(VF.Typeface.body(13))
                        .foregroundStyle(VF.Palette.textSecondary)
                        .lineLimit(1)
                    Text(verbatim: "\(phase.shortTitle) · \(place?.bestMonthsText ?? "")")
                        .font(VF.Typeface.mono(10))
                        .foregroundStyle(VF.Palette.amber)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VF.Palette.textTertiary)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onField) {
                Label("필드 모드로 안내받기", systemImage: "scope")
            }
            Button(role: .destructive, action: onRemove) {
                Label("롤에서 빼기", systemImage: "minus.circle")
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(VF.Palette.hairline).frame(height: VF.Metric.hairline)
        }
    }
}
