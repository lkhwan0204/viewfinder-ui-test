import SwiftUI

/// 프레임을 어느 롤에 담을지 고르는 시트
struct SaveToRollSheet: View {
    let frame: Frame

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(model.rolls) { roll in
                        let included = model.contains(frame.id, in: roll.id)
                        Button {
                            Haptics.tick()
                            model.toggle(frame.id, in: roll.id)
                        } label: {
                            HStack(spacing: 12) {
                                RollCover(roll: roll, size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(roll.name)
                                        .font(VF.Typeface.body(15))
                                        .foregroundStyle(VF.Palette.textPrimary)
                                    Text(verbatim: "\(roll.frameIDs.count) FRAMES")
                                        .font(VF.Typeface.mono(10))
                                        .foregroundStyle(VF.Palette.textTertiary)
                                }
                                Spacer()
                                Image(systemName: included ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 20))
                                    .foregroundStyle(included ? VF.Palette.amber : VF.Palette.textTertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("어느 롤에 담을까요?")
                }

                Section {
                    HStack {
                        TextField("새 롤 이름 (예: 제주 3월 롤)", text: $newName)
                        Button("만들기") {
                            model.createRoll(named: newName, frameIDs: [frame.id])
                            newName = ""
                            Haptics.success()
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("새 롤")
                }
            }
            .navigationTitle("롤에 담기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// 롤의 첫 프레임을 표지로
struct RollCover: View {
    let roll: Roll
    var size: CGFloat = 44

    @Environment(AppModel.self) private var model

    var body: some View {
        if let first = roll.frameIDs.first.flatMap({ model.catalog.frame($0) }) {
            FrameThumbnail(frame: first, size: size)
        } else {
            Image(systemName: "film")
                .font(.system(size: size * 0.4, weight: .light))
                .foregroundStyle(VF.Palette.textTertiary)
                .frame(width: size, height: size)
                .background(VF.Palette.surface)
        }
    }
}
