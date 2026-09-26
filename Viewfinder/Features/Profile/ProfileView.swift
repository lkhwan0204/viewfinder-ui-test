import SwiftUI

/// 프로필과 설정. 자주 쓰는 기능이 아니라서 탭 대신 탐색 화면 우측 상단 아바타로 들어옵니다.
struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(LocationService.self) private var location
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("화면") {
                    Picker("테마", selection: Binding(get: { model.appearance }, set: { model.setAppearance($0) })) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("취향") {
                    LabeledContent("고른 시드 사진", value: "\(model.tasteSeedIDs.count)장")
                    Button("취향 사진 다시 고르기") {
                        dismiss()
                        model.resetOnboarding()
                    }
                }

                Section("위치") {
                    LabeledContent("기준 위치", value: location.referenceName)
                    if !location.isAuthorized {
                        Button("위치 사용 허용하기") { location.requestWhenInUse() }
                    }
                }

                Section("내 기록") {
                    LabeledContent("롤", value: "\(model.rolls.count)개")
                    LabeledContent("담은 프레임", value: "\(Set(model.rolls.flatMap(\.frameIDs)).count)장")
                    LabeledContent("공유한 사진", value: "\(model.userImages.count)장")
                }

                Section {
                    Text("예보·물때·현장 업데이트는 프로토타입용 샘플 데이터예요. 사진은 코드로 그린 장면이며, Assets에 프레임 id(예: gwangchigi-01)와 같은 이름의 이미지를 넣으면 실제 사진으로 바뀝니다.")
                        .font(VF.Typeface.body(12))
                        .foregroundStyle(VF.Palette.textSecondary)
                } header: {
                    Text("안내")
                }
            }
            .navigationTitle("Viewfinder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }
}
