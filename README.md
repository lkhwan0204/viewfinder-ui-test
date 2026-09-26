# Viewfinder — UI/UX 프로토타입 (viewfinder 테스트)

> **장소를 찾는 앱이 아니라, 찍고 싶은 한 장면을 찾아가는 앱.**
> 세상을 핀이 아니라 프레임으로 보여주고, 마음에 든 사진 한 장에서 출발해 "어디에 서서, 언제, 어느 방향으로 찍을지"까지 좁혀 갑니다.

사진가를 위한 출사지 탐색 앱 Viewfinder의 SwiftUI 프로토타입입니다. 디자인 원칙과 토큰은 [DESIGN.md](DESIGN.md)에 정리했습니다.

## 실행

- Xcode 16 이상 (Xcode 26 권장), iOS 17 이상 시뮬레이터 또는 기기
- `Viewfinder.xcodeproj`를 열고 **Viewfinder** 스킴을 실행
- 실제 기기에서 실행하려면 *Signing & Capabilities*에서 Team을 선택
- 외부 패키지 없음

## 구현된 화면

| 설계 | 구현 | 위치 |
|---|---|---|
| 온보딩: 설문 대신 사진 고르기 | 끌리는 사진 3장 이상 선택 → 첫 피드의 취향 시드 | `Features/Onboarding` |
| 메인 Frame 뷰 | 한 화면 한 장, 크롭 없음, 뷰파인더 코너, EXIF 필름 테두리, "골든아워까지 1시간 12분" | `Explore/FrameFeedView` |
| 발견의 축 | 지금 · 오늘 일몰 · 주말 · 안개 · 반영 · 은하수 · 야경 · 1시간 이내 칩 | `Explore/ExploreTopBar` |
| 지도 ↔ 피드 연속 줌 | 핀치로 Frame → 밀착 인화 → 지도. 사진이 지도 위 제자리로 흩어지는 전환 | `Explore/ExploreView`, `ContactSheetView`, `ExploreMapView` |
| Shot Cone | 지도의 사진 썸네일마다 촬영 방향·화각 부채꼴, 줌에 따른 클러스터 | `ExploreMapView`, `DesignSystem/ShotCone` |
| 프레임 드래그 (역방향 탐색) | 지도에 사각형을 그리면 그 대상을 향해 찍힌 자리만 표시 | `ExploreMapView`, `Core/Services/FrameTargeting` |
| 촬영 카드 | 어디에 서서 · 어느 방향 · 언제 · 무엇으로 + 미니맵 | `Explore/ShotCardView` |
| 비슷한 프레임 | 길게 누르면 비슷한 사진이 나오는 *다른 장소*로 이어지고, 지나온 경로가 남음 | `Explore/SimilarFramesView` |
| 장소 상세 = 촬영 계획서 | 포인트 · 빛 타임라인 · 사계절 · 초점거리 분포 · 가기 전에 · 현장 업데이트 | `Features/Place` |
| 빛 스크러빙 | 시간을 드래그하면 지도 위 해 방향선과 대표 사진이 함께 바뀌고, 역광·순광·측광을 알려줌 | `Place/LightTimelineSection` |
| 롤 (Roll) | 필름 스트립 컬렉션, 두 번 탭 → "언젠가 롤", 조건 알림, 오프라인 저장 | `Features/Rolls` |
| 촬영 계획 | 롤을 지역별 하루 일정으로 묶고 각 포인트의 빛 시각 순서로 동선 제안 | `Rolls/PlanView`, `Core/Services/PlanBuilder` |
| 필드 모드 | 나침반 가이드, 고스트 오버레이(카메라 위 참고 사진), 야간 적색 모드 | `Features/Field` |
| 검증된 기여 | 업로드한 사진의 EXIF·GPS를 읽어 포인트와 300m 안이면 "현장 인증" | `Field/UploadFrameSheet` |
| 민감 장소 보호 | 보호 구역은 정확한 포인트 대신 넓은 원, Look Around 숨김, 에티켓 안내 | `Place/SpotsSection` |

## 데모 순서

1. **온보딩**: 사진 3장 이상 고르고 *탐색 시작*
2. **Frame 뷰**
   - 사진을 탭하면 감상 모드로 바뀝니다.
   - 두 번 탭하면 언젠가 롤에 저장됩니다 (셔터 햅틱).
   - 길게 누르면 비슷한 프레임을 보여줍니다.
   - 아래 정보 영역을 위로 밀면 촬영 카드가 열립니다.
3. **두 손가락 핀치 인**을 하면 밀착 인화로 바뀌고, 한 번 더 하면 지도로 바뀝니다. 사진들이 제자리로 흩어지며 내려앉습니다.
4. **지도 오른쪽 ⌐¬ 버튼**을 누르고 대상을 사각형으로 감쌉니다.
   - **성산일출봉**을 감싸면 광치기해변·섭지코지·오조리의 5개 자리가 나옵니다.
   - **남산타워**를 감싸면 반포·응봉산·낙산의 3개 자리가 나옵니다.
5. **장소 상세**: *빛 타임라인*의 하늘 띠를 드래그해 보세요.
6. **롤 탭**
   - 위쪽에서 조건 알림을 확인할 수 있습니다.
   - 롤을 열고 *촬영 계획 만들기*를 누르면 동선이 나옵니다.
7. **필드 탭**
   - 나침반: 시뮬레이터에서는 슬라이더로 방향을 돌립니다.
   - 고스트: 카메라 화면 위에 참고 사진을 겹칩니다.
   - 🌙 버튼: 적색 모드를 켭니다.

## 사진 없이 동작하는 방식

- 25장의 프레임은 `PlaceholderArtView`가 Canvas로 그립니다. 하늘, 해, 별, 실루엣, 수면 반영, 안개, 필름 그레인 같은 요소로 이루어져 있습니다.
- **실제 사진으로 바꾸기**: `Assets.xcassets`에 프레임 id와 같은 이름의 Image Set을 추가하면 자동으로 교체됩니다. 예를 들어 `gwangchigi-01`, `dumul-01`처럼 이름을 붙이면 됩니다. 프레임 id 목록은 `Core/Data/SampleData.swift`에 있습니다.
- 필드 탭에서 업로드한 사진은 메모리에만 보관합니다.

## 실제 계산과 샘플 데이터

| 항목 | 상태 |
|---|---|
| 해 위치, 일출·일몰, 골든/블루아워, 달 밝기 | **실제 천문 계산** (SunCalc 알고리즘, 네트워크 불필요). 서울 기준 실제 시각과 1~2분 이내 |
| 역방향 탐색, 클러스터, 유사도, 촬영 계획 | 실제 로직 (좌표·방위·화각 기반) |
| 장소 14곳 · 프레임 25장 | 실제 장소 좌표와 방향을 기준으로 만든 샘플 |
| 조건 예보 (안개, 구름, 바람) | **샘플 값**. 장소와 날짜로 고정된 가짜 값이며 `ForecastProviding`을 구현하면 WeatherKit으로 교체할 수 있음 |
| 현장 업데이트, 사진가, 초점거리 통계, 오프라인 저장 | 샘플 또는 진행 표시만 |

## 폴더 구조

```
Viewfinder/
├── ViewfinderApp.swift
├── App/            AppModel(상태·저장), LocationService, RootView(탭바)
├── Core/           순수 Foundation — UI 없이 테스트 가능
│   ├── Models/     Place · Spot · Frame · Roll · 빛 구간 · 필터 · 장면 레시피
│   ├── Services/   SunCalculator · LightStatus · ConditionForecast · Similarity
│   │               FrameTargeting · ClusterEngine · PlanBuilder · DiscoveryEngine
│   ├── Data/       Catalog, SampleData
│   └── Support/    포맷터(KST), 고정 시드 난수
├── DesignSystem/   토큰 · 뷰파인더 코너 · Shot Cone · 플레이스홀더 사진 · 하늘 띠 · 공통 컴포넌트
└── Features/       Onboarding · Explore · Place · Rolls · Field · Profile
```

## 검증 상태

이 코드는 Xcode가 없는 Linux 환경에서 작성했습니다.

- **Core** (모델·서비스·샘플 데이터): Swift 컴파일러로 타입 검사를 통과했습니다. 역방향 탐색, 해 계산, 촬영 계획, 조건 알림, 필터는 실제로 실행해서 결과를 확인했습니다.
- **UI** (SwiftUI·MapKit·AVFoundation): 문법 검사와 심볼·이니셜라이저 교차 검사까지만 했고, **실제 빌드는 아직 하지 않았습니다.** 첫 빌드에서 오류가 나오면 Xcode 오류 메시지를 알려주세요.

## 다음 단계 (이번 범위 밖)

- Live Activity와 Dynamic Island("일몰까지 23분"), 홈 화면 위젯, Apple Watch: 익스텐션 타깃이 필요합니다.
- WeatherKit과 물때 API 연동
- 이미지 임베딩 기반 유사도
- 업로드와 현장 업데이트를 공유할 서버
